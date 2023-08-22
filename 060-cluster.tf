locals {
  authorized_networks = []
}


resource "google_container_cluster" "private" {
  provider         = google-beta
  project          = data.google_project.default.project_id
  location         = var.google_region
  name             = "private-cluster-0"
  enable_autopilot = true

  network    = google_compute_network.custom_vpc.id
  subnetwork = google_compute_subnetwork.cluster_net.id

  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    auto_provisioning_defaults {
      service_account = google_service_account.container_node.email
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
      condition = try(alltrue([
        length(google_compute_subnetwork.cluster_net.secondary_ip_range) == 2,
        strcontains(google_compute_subnetwork.cluster_net.secondary_ip_range[0].range_name, "pod"),
        strcontains(google_compute_subnetwork.cluster_net.secondary_ip_range[1].range_name, "service")
      ]), false)
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

  # Access to cluster endpoints docs: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept#overview
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    # Use with private clusters to allow access to the master's private endpoint from any Google Cloud region
    # or on-premises environment. This is the `--enable-master-global-access` argument in gcloud CLI.
    # Technical details: https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#cp-global-access
    master_global_access_config {
      enabled = var.private_cluster_master_global_access
    }
  }

  # - If the public endpoint is disabled (by setting private_cluster_config/enable_private_endpoint to true),
  # the authorised networks list cannot contain any public IPs. The internal IP addresses other than nodes and Pods
  # need to be on the list to access the control plane's private endpoint. Addresses in the primary IP address range
  # of the cluster's subnet (nodes' addresses) are always authorized to communicate with the private endpoint.
  # - If the public endpoint was not disabled, the authorised networks list can be used to grant access
  # to the control plane from external IP addresses, and from internal IP addresses other than nodes and Pods.
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
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
