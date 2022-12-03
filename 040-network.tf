variable "flow_log_enabled" {
  type     = bool
  default  = true
  nullable = false
}
# TODO break down into three simple variables flow_log_{...}
variable "flow_log_config" {
  description = "VPC flow log configuration, as per google_compute_subnetwork resource docs."
  default = {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  nullable = false
}

# TODO move this documentation to README
# IP address range planning
# https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips
#
# Subnet primary IP address range (used for cluster nodes)
# Once created, it
#   + can expland at any time
#   - cannot shrink
#   - cannot change IP address scheme
# Thus, it makes sense to start small. Let's say 16 nodes (which is 2^4).
# Adresses for 16 nodes require (4+1) bits to represent (+1 is to accomodate for 4 reserved addresses),
# thus the mask /(32-5) = /27. It's a bit more than what's needed, but losing
# a bit would reduce the number of allowed nodes to 12. So, /27 it is.
# So, the CIDR block for the primary IP adderess range (cluster nodes IP addresses) is /27.
#
# Next, the pod address range. There's a limit on the number of pods each node can host,
# we change it from the default value of 110 to 32 (which is the default value for Autopilot clusters),
# and it's more reasonable, in my opinion. Now that we know that each node can host no more than 32 = 2^5
# pods, and we know that we can have at most 16 = 2^4 nodes, the total address space size is 2^5 * 2^4 = 2^9,
# or 512. But this does not take into account the x2 rule for pod IP addresses (pods starting up and shutting
# down). Thus, the true smallest value our pod IP address range can have is 2 * 512 = 1024, or 2^10.
# This dictates the CIDR mask of /(32 - 10) = /22. What are the implications for the future scalability?
#   + it is possible to replace a subnet's secondary IP address range
#   - doing so is not supported because it has the potential to put the cluster in an unstable state
#   + however, you can create additional Pod IP address ranges using discontiguous multi-Pod CIDR
# So, if we were really short of IP addresses, we could stop at /22 and use the discontiguous multi-Pod CIDR
# feature as and when needed. But we are not short of addresses, so I am going to upgrade /22 to /19, increasing
# the Pod IP range eightfold (giving up three bits on the network part of the address).
#
# Finally, the Services secondary range. This range cannot be changed as long as a cluster uses it for Services (cluster IP addresses).
# Unlike node and Pod IP address ranges, each cluster must have a unique subnet secondary IP address range for Services and cannot be sourced from a shared primary or secondary IP range.
# On the other hand, we are not short of IP address space, and we don't anticipate having thousands and thousands of services.
# Thus, the default (as if the secondary IP range assignment method was managed by GKE) size of /20, giving 4096 services, is good enough.

# TODO rename cidr variables to be in the format cidr_range_{nodes|pods|services}
variable "node_cidr_range" {
  description = "Subnet primary IP range for cluster nodes."
  type        = string
  default     = "10.128.0.0/27"
  nullable    = false
}
variable "pod_cidr_range" {
  description = "Subnet secondary IP range for GKE pods."
  type        = string
  default     = "10.1.0.0/19"
  nullable    = false
}
variable "service_cidr_range" {
  description = "Subnet secondary IP range for GKE services."
  type        = string
  default     = "10.2.0.0/20"
  nullable    = false
}

resource "google_compute_network" "custom" {
  name                    = "cluster-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "prod" {
  network                  = google_compute_network.custom.id
  name                     = "prod"
  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.flow_log_enabled ? [true] : []
    content {
      aggregation_interval = var.flow_log_config.aggregation_interval
      flow_sampling        = var.flow_log_config.flow_sampling
      metadata             = var.flow_log_config.metadata
    }
  }

  ip_cidr_range = var.node_cidr_range
  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = var.pod_cidr_range
  }
  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = var.service_cidr_range
  }
}

output "cluster_max_nodes" {
  description = "Maximum number of nodes in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.node_cidr_range)[1]))) - 4
}
output "cluster_max_pods" {
  description = "Maximum number of GKE Pods in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.pod_cidr_range)[1])))
}
output "cluster_max_services" {
  description = "Maximum number of GKE Services in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.service_cidr_range)[1])))
}