# Create a service account to attach to GKE cluster nodes and grant a limited set of privileges to it.
# Best practice: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa

locals {
  # The service account roles can be customised by the user.
  # The "Kubernetes Engine Node Service Account" role is sufficient to run a GKE node.
  # Reference: https://cloud.google.com/iam/docs/understanding-roles#container.nodeServiceAccount
  container_node_service_account_roles = distinct(compact(concat([
    "roles/container.nodeServiceAccount",
  ], var.container_node_service_account_roles)))
}

# A dedicated service account for GKE cluster nodes.
resource "google_service_account" "container_node" {
  provider    = google
  project     = data.google_project.default.project_id
  account_id  = "container-node-minimal"
  description = "Locked down account for GKE cluster nodes"
}

# The IAM roles to grant on the project to the GKE cluster node service account.
resource "google_project_iam_member" "container_node_service_account" {
  provider = google
  project  = data.google_project.default.project_id
  for_each = toset(local.container_node_service_account_roles)
  role     = each.key
  member   = google_service_account.container_node.member
}

# TODO by itself this does not help. there must be another resource depending on this one later on!
# Pause to give Google Cloud IAM a chance to sync. The IAM is only 'eventually' consistent.
# Reference: https://cloud.google.com/iam/docs/access-change-propagation
resource "time_sleep" "iam_nap" {
  create_duration = "2m"
  depends_on = [
    google_project_iam_member.container_node_service_account,
  ]
}
