terraform {
  required_version = "~> 1.1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.4"
    }
    null = {
      source  = "hashicorp/time"
      version = "~> 0.7"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# TODO split into different .tf files: versions, iam, services, network, cluster
# TODO GCP resource names could be better
# TODO review features https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview

# Service Usage API (serviceusage.googleapis.com) must be enabled
# on the project to enable the services.

# Cloud Resource Manager API
resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

# Compute Engine API
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

# Kubernetes Engine API
resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

# Cloud Logging API
resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
}

# Stackdriver Monitoring API
resource "google_project_service" "monitoring" {
  service = "monitoring.googleapis.com"
}

# TODO enable audit log entries for selected APIs
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_audit_config

# Least privilege service account for GKE nodes
resource "google_service_account" "gke_node" {
  account_id  = "sa-gke-node"
  description = "GKE nodes"
}

# Creation of service accounts is eventually consistent,
# and that can lead to errors when you try to apply ACLs
# to service accounts immediately after creation.
resource "time_sleep" "delay" {
  create_duration = "10s"
  depends_on      = [google_service_account.gke_node]
}

# Role assignment for the least privilege GKE node service account
# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa

resource "google_project_iam_member" "monitoring_viewer--sa_gke_node" {
  project    = var.project
  role       = "roles/monitoring.viewer"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
  depends_on = [time_sleep.delay]
}
resource "google_project_iam_member" "monitoring_metric_writer--sa_gke_node" {
  project    = var.project
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
  depends_on = [time_sleep.delay]
}
resource "google_project_iam_member" "log_writer--sa_gke_node" {
  project    = var.project
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
  depends_on = [time_sleep.delay]
}
resource "google_project_iam_member" "stackdriver_resource_metadata_writer--sa_gke_node" {
  project    = var.project
  role       = "roles/stackdriver.resourceMetadata.writer"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
  depends_on = [time_sleep.delay]
}

resource "google_compute_network" "custom" {
  name                    = "cluster-net"
  auto_create_subnetworks = false
}

variable "enable_flow_log" {
  type     = bool
  default  = true
  nullable = false
}
variable "flow_log_config" {
  description = "VPC flow log configuration, as per google_compute_subnetwork resource docs."
  default = {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  nullable = false
}

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

output "max_nodes" {
  description = "Maximum number of nodes in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.node_cidr_range)[1]))) - 4
}
output "max_pods" {
  description = "Maximum number of GKE Pods in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.pod_cidr_range)[1])))
}
output "max_services" {
  description = "Maximum number of GKE Services in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.service_cidr_range)[1])))
}

resource "google_compute_subnetwork" "prod" {
  network                  = google_compute_network.custom.id
  name                     = "prod"
  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.enable_flow_log ? [true] : []
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

variable "release_channel" {
  description = "Selected Kubernetes release channel. One of: {UNSPECIFIED, RAPID, REGULAR, STABLE}."
  type        = string
  default     = "RAPID"
  nullable    = false
  validation {
    condition     = can(contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], upper(var.release_channel)))
    error_message = "The release_channel must be one of: UNSPECIFIED, RAPID, REGULAR, STABLE."
  }
}

resource "google_container_cluster" "prod" {
  name                      = "prod"
  initial_node_count        = 1
  remove_default_node_pool  = true
  enable_shielded_nodes     = true
  default_max_pods_per_node = var.max_pods_per_node

  # TODO make k8s version optional variable
  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  # The location argument determines cluster availability type (regional/zonal)
  location = var.region

  network    = google_compute_network.custom.id
  subnetwork = google_compute_subnetwork.prod.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "service-range"
  }

  private_cluster_config {
    enable_private_nodes = true

    master_ipv4_cidr_block = var.master_ipv4_cidr_block

    # TODO variable for private endpoint (would disable public endpoint)
    enable_private_endpoint = false

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Dataplane V2
  # https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine
  # https://cilium.io/blog/2020/08/19/google-chooses-cilium-for-gke-networking
  # https://github.com/hashicorp/terraform-provider-google/issues/7207
  datapath_provider = "ADVANCED_DATAPATH"

  # Network policy enforcement is built into Dataplane V2. 
  # You do not need to enable network policy enforcement in clusters that use Dataplane V2.
  # https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy#enabling_network_policy_enforcement
}

resource "google_container_node_pool" "e2_standard_pool" {
  cluster  = google_container_cluster.prod.name
  location = google_container_cluster.prod.location
  name     = "e2-standard-pool"

  # In regional or multi-zonal clusters, number of nodes per zone
  node_count = 1

  node_config {
    preemptible  = var.preemptible
    machine_type = "e2-standard-2"
    image_type   = "COS_CONTAINERD"
    disk_size_gb = "12"

    # TODO disk too small, IOPS affected, increase

    shielded_instance_config {
      # Third-party unsigned kernel modules cannot be loaded when secure boot is enabled.
      # Since we aren't using third-party unsigned kernel modules, we enable secure boot.
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Google recommends custom service accounts that have
    # cloud-platform scope and permissions granted via IAM roles.
    service_account = google_service_account.gke_node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# NAT configuration for GKE node egress
resource "google_compute_router" "router" {
  name        = "prod-subnet-router"
  network     = google_compute_network.custom.name
  description = "Provides outbound Internet access to GKE private nodes"
}
resource "google_compute_router_nat" "nat" {
  name   = "k8s-nodes-nat"
  router = google_compute_router.router.name
  region = google_compute_router.router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.prod.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }

  # TODO investigate nat_ips = [] and drain_nat_ips = []
}
