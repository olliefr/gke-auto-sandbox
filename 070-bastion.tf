data "google_compute_zones" "available" {
  provider = google
  project  = google_compute_subnetwork.admin_net.project
  region   = google_compute_subnetwork.admin_net.region
  status   = "UP"
}

resource "google_compute_instance" "bastion" {
  provider = google
  project  = google_compute_subnetwork.admin_net.project
  zone     = data.google_compute_zones.available.names[0]

  name         = "cluster-admin-bastion"
  machine_type = "f1-micro"

  # To enable 2FA, must set *both* 'enable-oslogin' and 'enable-oslogin-2fa'.
  metadata = {
    enable-oslogin : "TRUE"
    enable-oslogin-2fa : "TRUE"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.admin_net.self_link
    # By omitting access_config {} we ensure that no public IP address is assigned to this instance.
  }

  lifecycle {
    precondition {
      condition     = length(data.google_compute_zones.available.names) > 0
      error_message = "The bastion deployment region must have at least one available zone."
    }
  }

  depends_on = [
    google_project_service.enabled["compute.googleapis.com"],
  ]
}

# Cluster administrators need this to connect to the jump box
# https://cloud.google.com/compute/docs/access#resource-policies
# https://cloud.google.com/compute/docs/oslogin/set-up-oslogin#configure_users
resource "google_compute_instance_iam_member" "bastion_os_admin_login" {
  provider      = google
  project       = google_compute_instance.bastion.project
  zone          = google_compute_instance.bastion.zone
  instance_name = google_compute_instance.bastion.name
  role          = "roles/compute.osAdminLogin"
  for_each      = local.cluster_administrators_set
  member        = each.key

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"],
  ]
}

resource "google_compute_instance_iam_member" "bastion_instance_admin_v1" {
  provider      = google
  project       = google_compute_instance.bastion.project
  zone          = google_compute_instance.bastion.zone
  instance_name = google_compute_instance.bastion.name
  role          = "roles/compute.instanceAdmin.v1"
  for_each      = local.cluster_administrators_set
  member        = each.key

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"],
  ]
}

resource "google_iap_tunnel_instance_iam_member" "bastion_iap_tunnel" {
  provider = google
  project  = google_compute_instance.bastion.project
  zone     = google_compute_instance.bastion.zone
  instance = google_compute_instance.bastion.name
  role     = "roles/iap.tunnelResourceAccessor"
  for_each = local.cluster_administrators_set
  member   = each.key

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"],
    google_project_service.enabled["iap.googleapis.com"],
  ]
}

# TODO install tinyproxy
