# For now, assume the target project already exists.
# TODO document the bootstrap: create a project, add a service account, run Terraform with impersonation.
# TODO reimplement project creation (using two provider configurations) later

# The seed stage verifies that the project exists and enables required services.

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

locals {
  # Pre-requisite services:
  #
  # Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
  # For: to manage IAM policy for the project
  #
  # Service Usage API (serviceusage.googleapis.com)
  # For: to enable necessary Google Cloud services for the project (?)
  #
  # IAM and Service Account Credentials APIs (iam.googleapis.com, iamcredentials.googleapis.com)
  # For: service account impersonation (?)
  #
  # ...
  # TODO sort alphabetically
  enabled_services = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

data "google_project" "default" {
  provider   = google
  project_id = var.project
}

# In long-lived projects I can leave the services on between experiments. In short-lived projects
# it would not matter because the project will be destroyed. So 'false' is safe.
resource "google_project_service" "enabled" {
  provider                   = google
  project                    = data.google_project.default.project_id
  for_each                   = toset(local.enabled_services)
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# This concludes the "seed" stage.
