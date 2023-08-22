# Configure Cloud NAT on the GKE cluster subnet to perform NAT for nodes and Pods.
# The interaction between Cloud NAT and GKE is not trivial, see the docs.
# Basic example: https://cloud.google.com/nat/docs/overview#example-gke
# Full reference: https://cloud.google.com/nat/docs/nat-product-interactions#NATwithGKE

resource "google_compute_router" "default" {
  provider = google
  project  = data.google_project.default.project_id
  region   = var.google_region
  name     = "${google_compute_subnetwork.cluster_net.region}-router"
  network  = google_compute_network.custom_vpc.name
}
resource "google_compute_router_nat" "nat" {
  provider = google
  project  = data.google_project.default.project_id
  region   = google_compute_router.default.region
  router   = google_compute_router.default.name
  name     = "k8s-private-cluster-nat"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # As described in the 'full reference' documentation page, this Cloud NAT gateway
  # is configured to apply to the nodes, Pods, and Services IP address ranges.
  # FIXME why would a Kubernetes Service require NAT?
  subnetwork {
    name                    = google_compute_subnetwork.cluster_net.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # Cloud NAT logging configuration.
  # https://cloud.google.com/nat/docs/monitoring
  log_config {
    enable = var.nat_logs_enabled
    filter = var.nat_logs_filter
  }
}

# TODO add admin net to NAT?
