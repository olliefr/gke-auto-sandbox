# The seed configuration sets up the provider and enables services on the existing target project.
# TODO document the bootstrap process: create a project, add a service account, run Terraform with impersonation.
# TODO add an option to create a new project (using two provider configurations)
# FIXME technically, we should check if the region is UP (available) before deploying regional (and zonal) resources
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_regions

provider "google" {
  project = var.google_project
  region  = var.google_region
}

provider "google-beta" {
  project = var.google_project
  region  = var.google_region
}

locals {
  # The services (APIs) to enable on the project, including those provided by the user.
  enable_services_set = setunion([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ], var.enable_services)
}

# Used by other resources to reference the target project by its ID.
# The existence of the project is checked at 'plan' stage.
data "google_project" "default" {
  provider   = google
  project_id = var.google_project
}

# Enable necessary services (Google Cloud APIs)
resource "google_project_service" "enabled" {
  provider = google
  project  = data.google_project.default.project_id

  # In long-lived projects: ok to leave the services on between the deployments.
  # In short-lived projects: does not matter what these settings are.
  # Thus, 'false' for both is the safest option.
  disable_dependent_services = false
  disable_on_destroy         = false

  for_each = local.enable_services_set
  service  = each.key
}
