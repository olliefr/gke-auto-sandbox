# Create a service account to attach to GKE cluster nodes and grant a limited set of privileges to it.
# Best practice: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa

locals {
  # FIXME why there's two different options for "minimal" GKE node service account? (see the bastion node SA comments)
  # The service account roles can be customised by the user.
  # The "Kubernetes Engine Node Service Account" role is sufficient to run a GKE node.
  # Reference: https://cloud.google.com/iam/docs/understanding-roles#container.nodeServiceAccount
  container_node_service_account_roles = distinct(compact(concat([
    "roles/container.nodeServiceAccount",
  ], var.container_node_service_account_roles)))

  # FIXME where the hell is the minimum set of roles for a user-managed service account defined? (to use with a Compute Engine VM)
  # The service account roles for the jump box are modelled after the minimal GKE node service account roles.
  # GKE cluster node reference: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  bastion_service_account_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ]
}

# A dedicated service account for GKE cluster nodes.
resource "google_service_account" "cluster_node" {
  provider     = google
  project      = data.google_project.default.project_id
  account_id   = "cluster-node"
  display_name = "GKE Cluster Node (Autopilot)"
  description  = "A locked-down identity for GKE cluster nodes."
}

# The IAM roles to grant on the project to the GKE cluster node service account.
resource "google_project_iam_member" "container_node_service_account" {
  provider = google
  project  = data.google_project.default.project_id
  for_each = toset(local.container_node_service_account_roles)
  role     = each.key
  member   = google_service_account.cluster_node.member
}

# A dedicated service account for the smol bastion host
resource "google_service_account" "bastion" {
  provider     = google
  project      = data.google_project.default.project_id
  account_id   = "cluster-admin-jump-box"
  display_name = "Smol Jump Box (GKE Admin)"
  description  = "A locked-down identity for jump boxes to manage GKE private clusters via IAP."
}

# The IAM roles to grant on the project to the jump box service account.
resource "google_project_iam_member" "bastion_service_account" {
  provider = google
  for_each = toset(local.bastion_service_account_roles)
  project  = data.google_project.default.project_id
  role     = each.key
  member   = google_service_account.bastion.member
}

# TODO what IAM roles does it need for IAP and OS Login?
# TODO at some point I must grant access to this jump box... to myself?
# https://cloud.google.com/compute/docs/access#resource-policies
# https://docs.bridgecrew.io/docs/google-cloud-policy-index
