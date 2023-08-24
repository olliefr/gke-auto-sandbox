# Create a custom VPC network for the GKE cluster and configure VPC Flow Logs.

resource "google_compute_network" "custom_vpc" {
  provider                = google
  project                 = data.google_project.default.project_id
  name                    = "cluster-vpc-0"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster_net" {
  provider = google
  project  = google_compute_network.custom_vpc.project
  network  = google_compute_network.custom_vpc.id
  name     = "cluster-net-0"
  region   = var.google_region

  ip_cidr_range            = var.cluster_subnetwork_ipv4_cidr
  private_ip_google_access = true

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
  provider = google
  project  = google_compute_network.custom_vpc.project
  network  = google_compute_network.custom_vpc.id
  name     = "cluster-admin-net-0"
  region   = var.google_region

  ip_cidr_range            = var.cluster_admin_subnetwork_ipv4_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = var.flow_logs_aggregation_interval
    flow_sampling        = var.flow_logs_sampling_rate
    metadata             = var.flow_logs_metadata
  }
}

# TODO maybe firewall should go into its own stage?
# TODO firewall rules between admin and cluster networks? between IAP and the admin network?

# No manually created VPC has automatically created firewall rules except for a default "allow" rule
# for outgoing traffic and a default "deny" for incoming traffic.

# Ingress into the control plane IP range from the admin subnet (by the service account)
resource "google_compute_firewall" "internal_admin_net_to_cluster_net" {
  provider = google
  project  = google_compute_network.custom_vpc.project
  network  = google_compute_network.custom_vpc.name
  name     = "bastion-private-cluster-0-admin"
  # TODO the cluster name should come from a variable

  source_service_accounts = [google_service_account.bastion.email]
  destination_ranges      = [var.master_ipv4_cidr_block]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Ingress into the admin subnet from IAP using TCP forwarding
# https://cloud.google.com/iap/docs/using-tcp-forwarding
data "google_netblock_ip_ranges" "iap_forwarders" {
  range_type = "iap-forwarders"
}

resource "google_compute_firewall" "external_iap_to_admin_net" {
  provider = google
  project  = google_compute_network.custom_vpc.project
  network  = google_compute_network.custom_vpc.name
  name     = "iap-tunnel-to-bastion"

  source_ranges      = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
  destination_ranges = [google_compute_subnetwork.admin_net.ip_cidr_range]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
