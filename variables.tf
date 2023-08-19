# This module deploys all its resources into a single Google Cloud project,
# and into a single region. These input variables define that project and region,
# as well as the default zone in that region. These values are also used 
# at a Google Terraform provider level as a fallback.
variable "project" {
  description = <<-EOT
    All resources deployed by this module are contained in a single project that must already exist. 
    The project must be linked to a billing account. 
    The operator must have enough permissions to:
      - enable services;
      - create service accounts;
      - set IAM policy at project level.
  EOT
  type        = string
  nullable    = false
}
variable "region" {
  description = "The Google Cloud region ID to use as a default with Google Cloud provider."
  type        = string
  nullable    = false
}

variable "flow_log_enabled" {
  type     = bool
  default  = false
  nullable = false
}
# TODO break down into three simple variables flow_log_{...}
variable "flow_log_config" {
  description = "VPC flow log configuration, as per google_compute_subnetwork resource docs."
  default = {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
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

variable "release_channel" {
  description = "Desired Kubernetes release channel. One of: {UNSPECIFIED, RAPID, REGULAR, STABLE}."
  type        = string
  default     = "REGULAR"
  nullable    = false
  validation {
    condition     = can(contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], upper(var.release_channel)))
    error_message = "Unsupported value for release channel was provided"
  }
}

variable "enable_private_endpoint" {
  description = "Enabling the private endpoint disables the public one. The public endpoint is disabled by default. Set to true to enable it."
  type        = bool
  default     = true
  nullable    = false

}
variable "master_ipv4_cidr_block" {
  description = "The CIDR range for hosted GKE master network (must be /28)."
  type        = string
  default     = "172.16.0.0/28"
  nullable    = false
}

variable "max_pods_per_node" {
  description = "The maximum number of pods per node in this cluster."
  type        = number
  default     = 32 # Default value for Autopilot clusters; borrowed the idea.
  nullable    = false
}

variable "authorized_networks" {
  description = "The CIDR blocks allowed to access the cluster control plane."
  type = list(object({
    cidr_block : string
    display_name : string
  }))
  # default = [
  #   {
  #     cidr_block   = "0.0.0.0/0"
  #     display_name = "warning-publicly-accessible-endpoint"
  #   },
  # ]
  default  = []
  nullable = false
}

variable "use_spot_vms" {
  description = "Use Spot VMs for GKE cluster nodes to substantially reduce cost. Default is true."
  type        = bool
  default     = true
  nullable    = false
}
