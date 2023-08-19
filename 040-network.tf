# Create a custom VPC network for the cluster.
# TODO should be able to accept existing VPC network as well. Even a Shared VPC.

resource "google_compute_network" "cluster_vpc" {
  provider                = google
  project                 = data.google_project.default.project_id
  name                    = "cluster-vpc-0"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster_net" {
  provider                 = google
  project                  = data.google_project.default.project_id
  network                  = google_compute_network.cluster_vpc.id
  name                     = "cluster-net-0"
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
    range_name    = "k8s-pods"
    ip_cidr_range = var.pod_cidr_range
  }
  secondary_ip_range {
    range_name    = "k8s-services"
    ip_cidr_range = var.service_cidr_range
  }
}
