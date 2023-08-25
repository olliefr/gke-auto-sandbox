# Configure Cloud NAT on the GKE cluster subnet to perform NAT for nodes and Pods.
# The interaction between Cloud NAT and GKE is not trivial, see the docs.
# Basic example: https://cloud.google.com/nat/docs/overview#example-gke
# Full reference: https://cloud.google.com/nat/docs/nat-product-interactions#NATwithGKE

resource "google_compute_router" "default" {
  provider = google
  project  = google_compute_subnetwork.cluster_net.project
  region   = google_compute_subnetwork.cluster_net.region
  network  = google_compute_subnetwork.cluster_net.network
  name     = "${google_compute_subnetwork.cluster_net.region}-router"
}

resource "google_compute_router_nat" "nat" {
  provider = google
  project  = google_compute_router.default.project
  region   = google_compute_router.default.region
  router   = google_compute_router.default.name
  name     = "k8s-private-cluster-nat"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # To avoid drift, set this to 64.
  min_ports_per_vm = 64

  # As described in the 'full reference' documentation page, this Cloud NAT gateway
  # is configured to apply to the nodes, Pods, and Services IP address ranges.
  # FIXME why would a Kubernetes Service require NAT? it's in the docs though...
  subnetwork {
    name                    = google_compute_subnetwork.cluster_net.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # Piggyback the admin network onto the same NAT gateway.
  subnetwork {
    name                    = google_compute_subnetwork.admin_net.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }

  # Cloud NAT logging configuration.
  # https://cloud.google.com/nat/docs/monitoring
  log_config {
    enable = var.nat_logs_enabled
    filter = var.nat_logs_filter
  }
}
