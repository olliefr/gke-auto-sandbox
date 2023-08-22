# The seed configuration sets up the provider and enables services on the existing target project.
# TODO document the bootstrap process: create a project, add a service account, run Terraform with impersonation.
# TODO add an option to create a new project (using two provider configurations)

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
  enable_services = distinct(compact(concat([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
  ], var.enable_services)))
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
  for_each = toset(local.enable_services)
  project  = data.google_project.default.project_id
  service  = each.key

  # In long-lived projects: ok to leave the services on between the deployments.
  # In short-lived projects: does not matter what these settings are.
  # Thus, 'false' for both is the safest option.
  disable_dependent_services = false
  disable_on_destroy         = false
}
