# The service account for GKE cluster nodes
resource "google_service_account" "gke_node" {
  account_id  = "gke-node"
  description = "Locked down account for GKE cluster nodes"
}

# FIXME not sure if this is necessary in the modern age?
# Creation of service accounts is eventually consistent,
# and that can lead to errors when you try to apply ACLs
# to service accounts immediately after creation.
resource "time_sleep" "delay" {
  create_duration = "10s"
  depends_on      = [google_service_account.gke_node]
}

locals {
  # Role assignment for the least privileged GKE node service account
  # https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  gke_node_roles = [
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ]
}

resource "google_project_iam_member" "gke_node" {
  project    = var.project
  for_each   = toset(local.gke_node_roles)
  role       = each.key
  member     = "serviceAccount:${google_service_account.gke_node.email}"
  depends_on = [time_sleep.delay]
}

# To deploy the GKE cluster resource, the deployment service account requires access to the cluster node service account.
resource "google_service_account_iam_member" "gke_node" {
  provider           = google.seed
  service_account_id = google_service_account.gke_node.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cluster_admin.email}"
}
