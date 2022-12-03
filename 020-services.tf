# Pre-requisites: "Service Usage API" must be enabled (serviceusage.googleapis.com).

locals {
  # The following services must be enabled on the project before a GKE cluster can be deployed.
  enabled_services = [
    "cloudresourcemanager.googleapis.com",
    # TODO add IAM as well
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "default" {
  for_each = toset(local.enabled_services)
  service  = each.key

  # (Optional) If true, services that are enabled and which depend on this service should also be disabled
  # when this service is destroyed. If false or unset, an error will be generated if any enabled services
  # depend on this service when destroying it.
  disable_dependent_services = false

  # (Optional) If true, disable the service when the Terraform resource is destroyed. Defaults to true.
  # May be useful in the event that a project is long-lived but the infrastructure running in that project changes frequently.
  disable_on_destroy = true
}
