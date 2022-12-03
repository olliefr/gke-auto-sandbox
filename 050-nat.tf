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
