# Create a custom VPC network for the GKE cluster and configure VPC Flow Logs.

resource "google_compute_network" "custom_vpc" {
  provider                = google
  project                 = data.google_project.default.project_id
  name                    = "cluster-vpc-0"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster_net" {
  provider                 = google
  project                  = data.google_project.default.project_id
  region                   = var.google_region
  network                  = google_compute_network.custom_vpc.id
  name                     = "cluster-net-0"
  private_ip_google_access = true

  ip_cidr_range = var.cluster_subnetwork_ipv4_cidr
  secondary_ip_range {
    range_name    = "k8s-pods"
    ip_cidr_range = var.pods_ipv4_cidr
  }
  secondary_ip_range {
    range_name    = "k8s-services"
    ip_cidr_range = var.services_ipv4_cidr
  }

  # VPC Flow Logs configuration
  # https://cloud.google.com/vpc/docs/flow-logs
  # Same VPC Flow Logs configuration is applied to all subnetworks deployed by this module.
  log_config {
    aggregation_interval = var.flow_logs_aggregation_interval
    flow_sampling        = var.flow_logs_sampling_rate
    metadata             = var.flow_logs_metadata
  }
}

resource "google_compute_subnetwork" "admin_net" {
  provider                 = google
  project                  = data.google_project.default.project_id
  region                   = var.google_region
  network                  = google_compute_network.custom_vpc.id
  name                     = "cluster-admin-net-0"
  private_ip_google_access = true
  ip_cidr_range            = var.cluster_admin_subnetwork_ipv4_cidr

  log_config {
    aggregation_interval = var.flow_logs_aggregation_interval
    flow_sampling        = var.flow_logs_sampling_rate
    metadata             = var.flow_logs_metadata
  }
}

# TODO firewall rules between admin and cluster networks? between IAP and the admin network?
