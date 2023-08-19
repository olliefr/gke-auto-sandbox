# NAT is required to enable Internet access from private GKE nodes.
resource "google_compute_router" "router" {
  provider = google
  project  = data.google_project.default.project_id
  name     = "${google_compute_subnetwork.cluster_net.region}-router"
  network  = google_compute_network.cluster_vpc.name
}
resource "google_compute_router_nat" "nat" {
  provider = google
  project  = data.google_project.default.project_id
  name     = "k8s-nodes-nat"
  router   = google_compute_router.router.name
  region   = google_compute_router.router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # Give Internet access to nodes, pods, and services.
  subnetwork {
    name                    = google_compute_subnetwork.cluster_net.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
