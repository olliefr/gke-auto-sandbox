# This file defines an IAM service account for GKE nodes.
#
# Each GKE node has an IAM service account associated with it.
# By default, nodes are given the Compute Engine default service account,
# which has broad access by default, making it useful to wide variety of applications, 
# but it has more permissions than are required to run your Kubernetes Engine nodes.
# 
# The best practice is to disable the Compute Engine default service account, and
# to create and use a minimally privileged service account for your nodes.
#
# Reference: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa

locals {
  # The "Kubernetes Engine Node Service Account" role is sufficient to run a GKE node.
  # Reference: https://cloud.google.com/iam/docs/understanding-roles#container.nodeServiceAccount
  gke_node_service_account_roles = [
    "roles/container.nodeServiceAccount",
  ]
}
# A new Google service account for cluster nodes.
resource "google_service_account" "gke_node_service_account" {
  provider    = google
  project     = data.google_project.default.project_id
  account_id  = "cluster-node-minimal"
  description = "Locked down account for GKE nodes"
}

# The roles to grant to the node service account at the project level.
resource "google_project_iam_member" "gke_node_service_account" {
  provider = google
  project  = data.google_project.default.project_id
  for_each = toset(local.gke_node_service_account_roles)
  role     = each.key
  member   = google_service_account.gke_node_service_account.member
}

# FIXME how do I go about this? Set a project-ide 'Service Account User' instead?
# # To spin up nodes associated with the 'gke-node-default' service account, 
# # the 'admin-robot' service account must be assigned a 'Service Account User' role 
# # on that service account for cluster nodes. 
# resource "google_service_account_iam_member" "admin_robot_as_gke_node_service_account" {
#     provider = google
#   project  = data.google_project.default.project_id
#   service_account_id = google_service_account.gke_node_service_account.name
#   role               = "roles/iam.serviceAccountUser"
#   member             = google_service_account.admin_robot.member
# }

# Google Cloud IAM is eventually consistent and I don't like having to deal with transient permission errors.  
# A well-known workaround is to wait some reasonable amount of time for IAM to propagate changes.
# This approach is not infallible because IAM changes may take hours to propagate in the worst case scenario.
# But it's better than nothing and, empirically, the following delay is enough.
# FIXME: at some point in the future Terraform should learn to handle eventual consistency gracefully...
resource "time_sleep" "iam_sync_gke_node_service_account" {
  create_duration = "120s"
  depends_on = [
    google_project_iam_member.gke_node_service_account,
    # google_service_account_iam_member.admin_robot_as_gke_node_service_account,
  ]
}
