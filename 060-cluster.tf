
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

variable "location" {
  description = <<-EOF
    The location (region or zone) in which the cluster master will be created, as well as the default node location.
    If you specify a zone (such as us-central1-a), the cluster will be a zonal cluster with a single cluster master.
    If you specify a region (such as us-west1), the cluster will be a regional cluster with multiple masters spread
    across zones in the region, and with default node locations in those zones as well.
  EOF
  type        = string
  nullable    = false
}
#variable "availability_type" {
#  description = "The cluster availability type defines the control plane location as well as the default location for nodes. Values: 'regional' or 'zonal'. Default is 'zonal'."
#  type        = string
#  default     = "zonal"
#  nullable    = false
#  validation {
#    condition     = can(contains(["regional", "zonal"], lower(var.availability_type)))
#    error_message = "The location can be either 'regional' or 'zonal'."
#  }
#}

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

resource "google_container_cluster" "prod" {
  name                      = "prod"
  initial_node_count        = 1
  remove_default_node_pool  = true
  enable_shielded_nodes     = true
  default_max_pods_per_node = var.max_pods_per_node

  # The default node pool will use the default Compute Engine service account, unless instructed otherwise.
  node_config {
    service_account = google_service_account.gke_node_service_account.email
  }

  # TODO make k8s version optional variable
  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  # Cluster availability type is chosen to be regional or zonal, depending on the value (region ID or zone ID).
  location = var.location

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
    spot  = var.use_spot_vms
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
    service_account = google_service_account.gke_node_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
