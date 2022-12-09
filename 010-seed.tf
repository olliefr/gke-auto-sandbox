# The resources described in this file use a "seed" Google provider and are deployed
# with operator's credentials. The purpose of these resources is to provide a foundation
# to deploy the cluster using a locked-down user-managed service account configured here.

# Pre-requisite: "Cloud Resource Manager API" (cloudresourcemanager.googleapis.com) must be enabled
# for Terraform to be able to manage IAM policies at project level.

# Pre-requisite: "Service Usage API" (serviceusage.googleapis.com) must be enabled 
# for Terraform to be able to manage services in a Google Cloud project.

# This module deploys all its resources into a single Google Cloud project,
# and into a single region. These input variables define that project and region,
# as well as the default zone in that region. These values are also used 
# at a Google Terraform provider level as a fallback.
variable "project" {
  description = <<-EOT
    All resources deployed by this module are contained in a single project that must already exist. 
    The project must be linked to a billing account. 
    The operator must have enough permissions to:
      - enable services;
      - create service accounts;
      - set IAM policy at project level.
  EOT
  type        = string
  nullable    = false
}
variable "region" {
  description = "The Google Cloud region ID to use as a default with Google Cloud provider."
  type        = string
  default     = "europe-west2"
  nullable    = false
}
locals {
  zone = "${var.region}-a"
}
# variable "zone" {
#   description = "The Google Cloud zone ID to use as a default with Google Cloud provider."
#   type        = string
#   default     = "europe-west2-a"
#   nullable    = false
#   validation {
#     condition = startswith(var.zone, var.region)
#     error_message = "The 'zone' value must be a Google Cloud zone ID located in the region defined by the 'region' value."
#   }
# }

provider "google" {
  alias   = "seed"
  project = var.project
  region  = var.region
  zone    = local.zone
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# ADR: I sometimes have to repurpose existing Google Cloud projects. 
# In such use cases, it's not wise to disable the core services, 
# even when the current infrastructure is being taken down. Thus, 
# I enable all required services when deploying this module, but
# on destroy only some services are taken down.

locals {
  enabled_services = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "container.googleapis.com",
  ]
}

# ADR: After extensive research and deliberations, I have made a decision
# not to disable services on 'destroy'. This is for two reasons.
# First, when you enable a service, Google Cloud may (and does) enable
# other services that your service depends on. The list of service dependencies
# is not public though. This is weird, but we have what we have. 
# Second, in my opinion the whole process of enabling and disabling services
# does not add value from the application developer's perspective.
# The services required by the application must be enabled, but once they are
# there is no value in disabling them when the application infrastructure 
# is deprovisioned.
resource "google_project_service" "enabled" {
  provider = google.seed
  for_each = toset(local.enabled_services)
  service  = each.key

  # (Optional) If true, services that are enabled and which depend on this service should also be disabled
  # when this service is destroyed. If false or unset, an error will be generated if any enabled services
  # depend on this service when destroying it.
  disable_dependent_services = false

  # (Optional) If true, disable the service when the Terraform resource is destroyed. Defaults to true.
  # May be useful in the event that a project is long-lived but the infrastructure running in that project changes frequently.
  disable_on_destroy = false
}

# In production environments, resources usually are deployed by 
# a locked-down "master" service account and use of "Owner" and 
# "Editor" basic roles is discouraged. 
#
# In this module, 'admin-robot' is the name we give to that service account.
#
# The service account will manage the cluster infrastructure, but not Kubernetes objects. 
# The "Kubernetes Engine Cluster Admin" role contains enough permissions for this use case.
# A more general "Kubernetes Engine Admin" role would have been excessive.
# Predefined GKE Roles: https://cloud.google.com/kubernetes-engine/docs/how-to/iam#predefined
#
# The service account will also create and manage the service accounts for the cluster nodes.
# For this, "Service Account Admin" role is required.
# Reference: https://cloud.google.com/iam/docs/understanding-roles#service-accounts-roles
#
# The admin robot will be managing the permissions for the service accounts that it creates for GKE nodes. 
# This is why it needs "Project IAM Admin" role: 
# Reference: https://cloud.google.com/resource-manager/docs/access-control-proj#resourcemanager.projectIamAdmin
locals {
  admin_robot_roles = [
    "roles/container.clusterAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
  ]
}
resource "google_service_account" "admin_robot" {
  provider    = google.seed
  account_id  = "admin-robot"
  description = "Managing GKE clusters, node service accounts, and their permissions"

  # This module sometimes is deployed in repurposed (long-life) projects, so it has to be
  # mindful of order of operations when destroying resources. Without declaring an explicit
  # dependency, Terraform will not know that services must not be disabled until the resources
  # that rely on them are destroyed. Logically, the 'admin-robot' service account is 
  # the first resource that is deployed after all required services are enabled, so it makes
  # to declare all services as its dependencies. In the absence of the following declaration,
  # creating resources would work as expected, but destroying resources may not because 
  # without knowing that the service account depends on these services, Terraform will 
  # start parallel operations and may disable the services before other resources are destroyed.
  depends_on = [
    google_project_service.enabled,
  ]
}
resource "google_project_iam_member" "admin_robot" {
  provider = google.seed
  project  = var.project
  for_each = toset(local.admin_robot_roles)
  role     = each.key
  member   = google_service_account.admin_robot.member
}

# To allow the operator (human user) to impersonate 'admin-robot' service account, the operator 
# must be granted 'Service Account Token Creator' role on the service account.
# Reference: https://cloud.google.com/iam/docs/impersonating-service-accounts#allow-impersonation
# Note, that the operator is assumed to be a human user and not a service account.
# This is fine for my use case.

# The operator identity will be read from this data source.
data "google_client_openid_userinfo" "operator" {
  provider = google.seed
}
resource "google_service_account_iam_member" "operator_as_admin_robot" {
  provider           = google.seed
  service_account_id = google_service_account.admin_robot.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${data.google_client_openid_userinfo.operator.email}"
}

# The operator identity is read from ADC so it may turn out to be not what the operator expects.
# To follow the principle of least surprise, output (assumed) operator identity.
output "my-email" {
  value = data.google_client_openid_userinfo.operator.email
}

# Google Cloud IAM is eventually consistent and I don't like having to deal with transient permission errors.  
# A well-known workaround is to wait some reasonable amount of time for IAM to propagate changes.
# This approach is not infallible because IAM changes may take hours to propagate in the worst case scenario.
# But it's better than nothing and, empirically, the following delay is enough.
# FIXME: at some point in the future Terraform should learn to handle eventual consistency gracefully...
resource "time_sleep" "iam_sync_admin_robot" {
  create_duration = "120s"
  depends_on = [
    google_project_iam_member.admin_robot,
    google_service_account_iam_member.operator_as_admin_robot,
  ]
}

# An access token is required to impersonate a service account.
# Now that the operator has 'Service Account Token Creator' role on the service account,
# the token can be requested via the following data source. 
data "google_service_account_access_token" "operator_as_admin_robot" {
  provider               = google.seed
  target_service_account = google_service_account.admin_robot.email
  scopes = [
    "userinfo-email",
    "cloud-platform",
  ]
  lifetime = "1200s"

  # The operator was granted a permission to create a token to impersonate 
  # the 'admin-robot' service account but that IAM change may not have
  # propagated by the time this data resource is read. To reduce this risk,
  # introduce a pause between IAM policy change and data source read.
  depends_on = [
    time_sleep.iam_sync_admin_robot,
  ]
}

# With an access token in hand, the 'admin-robot' service account can be used
# to deploy the cluster infrastructure. From this point onwards, the 'admin-robot'
# identity is used for managing the cluster's infrastructure.
# To ensure this, I create a new instance of Google Cloud Terraform provider.
# There is no alias set for this instance and thus it becomes the "default" instance.
provider "google" {
  project      = var.project
  region       = var.region
  zone         = local.zone
  access_token = data.google_service_account_access_token.operator_as_admin_robot.access_token
}

# This concludes the "seed" stage.
