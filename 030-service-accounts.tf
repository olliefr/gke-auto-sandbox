# Create a service account to attach to GKE cluster nodes and grant a limited set of privileges to it.
# Best practice: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa

locals {
  # The service account roles can be customised by the user.
  # FIXME why there's two different options for "minimal" GKE node service account?
  # Option A: https://cloud.google.com/iam/docs/understanding-roles#container.nodeServiceAccount
  # Option B: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  # Until further research, I choose... both!
  cluster_node_service_account_roles_set = setunion([
    "roles/container.nodeServiceAccount",
    "roles/logging.logWriter",
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ], var.cluster_node_service_account_roles)

  # TODO make the set of roles customisable with a variable like for the cluster node service account
  # FIXME where the hell is the minimum set of roles for a user-managed service account defined? (to use with a Compute Engine VM)
  # The service account roles for the jump box are modelled after the minimal GKE node service account roles.
  # GKE cluster node reference: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  bastion_service_account_roles_set = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ])

  # The cluster administrators. Groups can come unprefixed so need to add a prefix.
  users                      = [for i in var.cluster_administrators : i if startswith(i, "user:")]
  groups                     = [for i in var.cluster_administrators : i if startswith(i, "group:")]
  implied_groups             = setsubtract(var.cluster_administrators, setunion(local.users, local.groups))
  cluster_administrators_set = setunion(local.users, local.groups, [for v in local.implied_groups : "group:${v}"])
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
resource "google_project_iam_member" "cluster_node_service_account" {
  provider = google
  project  = google_service_account.cluster_node.project
  member   = google_service_account.cluster_node.member
  for_each = local.cluster_node_service_account_roles_set
  role     = each.key
}

# A dedicated service account for the smol bastion host
resource "google_service_account" "bastion" {
  provider     = google
  project      = data.google_project.default.project_id
  account_id   = "cluster-admin-jump-box"
  display_name = "Smol Jump Box (GKE Admin)"
  description  = "A locked-down identity for jump boxes to manage GKE private clusters via IAP."
}

# Cluster administrators need this to connect to the jump box.
# https://cloud.google.com/compute/docs/access#resource-policies
# https://cloud.google.com/compute/docs/oslogin/set-up-oslogin#configure_users
resource "google_service_account_iam_member" "bastion_user" {
  provider           = google
  service_account_id = google_service_account.bastion.name
  role               = "roles/iam.serviceAccountUser"
  for_each           = local.cluster_administrators_set
  member             = each.key
}

# The IAM roles to grant on the project to the jump box service account.
resource "google_project_iam_member" "bastion_service_account" {
  provider = google
  project  = google_service_account.bastion.project
  member   = google_service_account.bastion.member
  for_each = local.bastion_service_account_roles_set
  role     = each.key
}
