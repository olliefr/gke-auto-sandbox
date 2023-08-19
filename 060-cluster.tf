resource "google_container_cluster" "prod" {
  provider         = google-beta
  project          = data.google_project.default.project_id
  name             = "private-cluster-0"
  enable_autopilot = true

  # This is the way to instruct Autopilot not to use the default Compute Engine service account.
  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    auto_provisioning_defaults {
      service_account = google_service_account.gke_node_service_account.email
    }
  }
  vertical_pod_autoscaling {
    enabled = true
  }

  cluster_telemetry {
    type = "ENABLED"
  }

  release_channel {
    channel = var.release_channel
  }

  # Cluster availability type is regional because Autopilot
  location = var.region

  network    = google_compute_network.cluster_vpc.id
  subnetwork = google_compute_subnetwork.cluster_net.id

  # FIXME the following DNS configuration was enforced by Autopilot. I created this block after having deployed the cluster.
  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "CLUSTER_SCOPE"
    cluster_dns_domain = "cluster.local"
  }

  # It's bloody hard to extract the name from google_compute_subnetwork.cluster_net.secondary_ip_range data structure,
  # if you don't know what exactly that name is! I chose to validate like this, instead. Judge me!
  lifecycle {
    precondition {
      condition = (
        length(google_compute_subnetwork.cluster_net.secondary_ip_range) == 2 &&
        strcontains(google_compute_subnetwork.cluster_net.secondary_ip_range[0].range_name, "pod") &&
        strcontains(google_compute_subnetwork.cluster_net.secondary_ip_range[1].range_name, "service")
      )
      error_message = "Secondary ranges for cluster subnetwork appear to be defined in a format this resource did not expect"
    }
  }

  # The CIDR ranges for Pods and Services can be given back to GKE to manage, but I don't want that.
  # By providing the names of the existing secondary ranges in the cluster's subnetwork, 
  # we define what CIDRs should be used so GKE is not going to create any ranges automatically.
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.cluster_net.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.cluster_net.secondary_ip_range[1].range_name
  }

  # TODO maybe add a small "admin" subnet? or smth else?
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

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
