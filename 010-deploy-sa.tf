# This provider instance ("seed") is used only to create a service account for deploying the cluster resources
# and to assign that service account necessary roles following the principle of least privilege.
provider "google" {
  alias   = "seed"
  project = var.project
  region  = var.region
  zone    = var.zone
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# The locked down service account for cluster management
# created using a "seed" (privileged) Google provider instance.
resource "google_service_account" "cluster_admin" {
  provider    = google.seed
  account_id  = "cluster-admin"
  description = "Cluster management account for Terraform"
}

# To grant a role to a principal, it is *not necessary* that an API corresponding to the role is enabled first.
# I could not find this information in the documentation, but I have tested this claim in Cloud Console.

locals {
  # TODO review the cluster admin roles and revoke unnecessary roles
  # The following roles are necessary for the service account to fully deploy the cluster.
  cluster_admin_roles = [
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.securityAdmin",
    "roles/compute.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/monitoring.admin",
    "roles/logging.privateLogViewer",
  ]
}

# The roles assigned to the cluster admin service account via a "seed" (privileged) Google provider instance.
resource "google_project_iam_member" "cluster_admin" {
  provider = google.seed
  project  = var.project
  for_each = toset(local.cluster_admin_roles)
  role     = each.key
  member   = "serviceAccount:${google_service_account.cluster_admin.email}"
}

# This datasource enables you to find out the email of the account you've authenticated
# the "seed" instance of Google provider with (via ADC).
data "google_client_openid_userinfo" "operator" {
  provider = google.seed
}

# Whoever runs Terraform
output "my-email" {
  value = data.google_client_openid_userinfo.operator.email
}

# Whoever runs Terraform, would need to be able to impersonate the new locked down service account.
# FIXME we assume that the "user" is a human user, but in principle it could be another service account
resource "google_service_account_iam_member" "cluster_admin" {
  provider           = google.seed
  service_account_id = google_service_account.cluster_admin.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${data.google_client_openid_userinfo.operator.email}"
}

# The access token for use by the unprivileged instance of Google provider to create the cluster resources.
# The token cannot be read until the token creator role on the service account has been given to the operator.
data "google_service_account_access_token" "cluster_admin" {
  provider               = google.seed
  target_service_account = google_service_account.cluster_admin.email
  scopes = [
    "userinfo-email",
    "cloud-platform",
  ]
  lifetime = "1200s"
  depends_on = [
    google_service_account_iam_member.cluster_admin,
  ]
}

# This provider instance is the "default" one and it is used to deploy and manage the cluster resources
# by impersonating the locked down service account created specifically for this purpose. Because
# this is the "default" provider (it does not have an alias defined), the rest of resources in this module will use it.
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone

  access_token    = data.google_service_account_access_token.cluster_admin.access_token
  request_timeout = "60s"
}
