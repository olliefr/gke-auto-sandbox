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
  depends_on = [google_service_account.gke_node]
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

# TODO make node, pod, services IP ranges variables
# TODO add outputs to display max node, max pods, max services (computed)

resource "google_compute_subnetwork" "prod" {
  network                  = google_compute_network.custom.id
  name                     = "prod"
  private_ip_google_access = true

  ip_cidr_range = "10.0.0.0/16"

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = "10.2.0.0/16"
  }
}

resource "google_container_cluster" "prod" {
  name                     = "prod"
  initial_node_count       = 1
  remove_default_node_pool = true
  enable_shielded_nodes    = true

  # TODO make k8s version optional variable
  # TODO make release channel optional variable
  release_channel {
    # channel is one of {UNSPECIFIED, RAPID, REGULAR, STABLE}
    channel = "RAPID"
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

    # TODO variable for master_ipv4_cidr_block
    master_ipv4_cidr_block = "172.16.0.0/28"

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
