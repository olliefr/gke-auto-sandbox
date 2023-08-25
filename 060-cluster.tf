locals {
  # Master authorised networks must include the admin subnet. The rest comes from the user.
  master_authorized_networks = merge({
    (google_compute_subnetwork.admin_net.name) : google_compute_subnetwork.admin_net.ip_cidr_range
  }, var.master_authorized_networks)
}

resource "google_container_cluster" "private" {
  provider         = google-beta
  project          = google_compute_subnetwork.cluster_net.project
  location         = google_compute_subnetwork.cluster_net.region
  name             = "private-cluster-0"
  enable_autopilot = true

  network    = google_compute_subnetwork.cluster_net.network
  subnetwork = google_compute_subnetwork.cluster_net.id

  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    auto_provisioning_defaults {
      service_account = google_service_account.cluster_node.email
    }
  }
  vertical_pod_autoscaling {
    enabled = true
  }

  # cluster_telemetry {} is obsolete
  # https://github.com/hashicorp/terraform-provider-google/issues/10820#issuecomment-1693782669

  # https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters#loggingcomponentconfig
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
    ]
  }

  # https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters#monitoringconfig
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
#      TODO the rest requires Prometheus
#      "STORAGE",
#      "POD",
#      "DEPLOYMENT",
#      "STATEFULSET",
#      "DAEMONSET",
#      "HPA",
    ]
    # TODO add Google Cloud Managed Service for Prometheus (will need extra configuration via PodMonitoring resources as well)
    # https://cloud.google.com/stackdriver/docs/managed-prometheus
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

  # For documentation purposes. The networking mode is pre-configured in Autopilot but the provider doesn't complain here.
  networking_mode = "VPC_NATIVE"

  # The CIDR ranges for Pods and Services can be given back to GKE to manage, but I don't want that.
  # By providing the names of the existing secondary ranges in the cluster's subnetwork, 
  # we define what CIDRs should be used so GKE is not going to create any ranges automatically.
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.cluster_net.secondary_ip_range[0].range_name
    services_secondary_range_name = var.services_ipv4_cidr != null ? google_compute_subnetwork.cluster_net.secondary_ip_range[1].range_name : null
  }

  # Access to cluster endpoints docs: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept#overview
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr

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
      for_each = local.master_authorized_networks
      content {
        display_name = cidr_blocks.key
        cidr_block   = cidr_blocks.value
      }
    }
  }

  # FIXME this should be "pre-configured" in Autopilot. usually the provider complains about unnecessary field, but not here?
  # GKE Dataplane V2: eBPF + Kubernetes Network Policy logging and enforcement
  # Reference: https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2
  datapath_provider = "ADVANCED_DATAPATH"

  depends_on = [
    google_project_service.enabled["artifactregistry.googleapis.com"],
    google_project_service.enabled["compute.googleapis.com"],
    google_project_service.enabled["container.googleapis.com"],
    google_project_service.enabled["dns.googleapis.com"],
    google_project_service.enabled["logging.googleapis.com"],
    google_project_service.enabled["monitoring.googleapis.com"],
  ]
}
