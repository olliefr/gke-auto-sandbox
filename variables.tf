# Definitions of all input variables, sorted in ascending order by the (conceptual) deployment "stage".

# 010-seed

variable "google_project" {
  description = "The Google Cloud project ID defines the existing parent project for all resources in this module."
  type        = string
  nullable    = false
}
variable "google_region" {
  description = "The Google Cloud region ID defines the deployment region for all regional resources in this module."
  type        = string
  nullable    = false
}

variable "enable_services" {
  description = "The list of Google Cloud APIs to enable on the project in addition to APIs required by this module."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "cluster_administrators" {
  description = <<-EOT
    The list of IAM principals who are granted administrative access to the bastion host and the GKE cluster.
    A principal can be either a Google account or a Google Groups. By default, a group is assumed so the user IDs
    must have a "user:" prefix. The group IDs may have a "group:" prefix but it is not mandatory.
  EOT
  type        = list(string)
  nullable    = false
}

# 030-cluster-node-sa

variable "cluster_node_service_account_roles" {
  description = <<-EOT
    The list of IAM roles to grant on the project to the service account attached to GKE cluster nodes
    in addition to the minimal set of roles granted by this module.
  EOT
  type        = list(string)
  default     = []
  nullable    = false
}

# 040-network

variable "cluster_admin_subnetwork_ipv4_cidr" {
  description = <<-EOT
    The primary IP range for the VPC subnetwork which will be used for GKE private cluster
    administration via the cluster's private endpoint. This network is on the master authorised networks list.
  EOT
  type        = string
  default     = "192.168.100.0/28"
  nullable    = false
  validation {
    condition     = can(cidrnetmask(var.cluster_admin_subnetwork_ipv4_cidr))
    error_message = "Must be a valid IPv4 CIDR, as defined in RFC 4632 section 3.1."
  }
}

variable "cluster_subnetwork_ipv4_cidr" {
  description = "The primary IP range for the VPC subnetwork to which the GKE cluster will be connected."
  type        = string
  default     = "10.128.0.0/27"
  nullable    = false
  validation {
    condition     = can(cidrnetmask(var.cluster_subnetwork_ipv4_cidr))
    error_message = "Must be a valid IPv4 CIDR, as defined in RFC 4632 section 3.1."
  }
}

variable "pods_ipv4_cidr" {
  description = <<-EOT
    A secondary IP range for the VPC subnetwork to which the GKE cluster will be connected.
    To be used for Kubernetes Pods.
  EOT
  type        = string
  default     = "10.1.0.0/19"
  nullable    = false
  validation {
    condition     = can(cidrnetmask(var.pods_ipv4_cidr))
    error_message = "Must be a valid IPv4 CIDR, as defined in RFC 4632 section 3.1."
  }
}

variable "services_ipv4_cidr" {
  description = <<-EOT
    A secondary IP range for the VPC subnetwork to which the GKE cluster will be connected.
    To be used for Kubernetes Services.
  EOT
  type        = string
  default     = "10.2.0.0/20"
  nullable    = false
  validation {
    condition     = can(cidrnetmask(var.services_ipv4_cidr))
    error_message = "Must be a valid IPv4 CIDR, as defined in RFC 4632 section 3.1."
  }
}

variable "flow_logs_aggregation_interval" {
  description = "VPC Flow Logs aggregation interval"
  type        = string
  default     = "INTERVAL_5_SEC"
  nullable    = false
  validation {
    condition = contains([
      "INTERVAL_5_SEC", "INTERVAL_30_SEC", "INTERVAL_1_MIN",
      "INTERVAL_5_MIN", "INTERVAL_10_MIN", "INTERVAL_15_MIN"
    ], var.flow_logs_aggregation_interval)
    error_message = "Must be one of: ..."
  }
}

variable "flow_logs_sampling_rate" {
  description = "VPC Flow Logs flow sampling rate. Set to 0.0 to disable."
  type        = number
  default     = 1.0
  nullable    = false
  validation {
    condition     = var.flow_logs_sampling_rate >= 0.0 && var.flow_logs_sampling_rate <= 1.0
    error_message = "Must be from 0.0 to 1.0 inclusive, which means from 0 to 100 percent."
  }
}

variable "flow_logs_metadata" {
  description = "Defines which VPC Flow Logs metadata annotations to save in the flow logs."
  type        = string
  default     = "INCLUDE_ALL_METADATA"
  nullable    = false
  validation {
    condition     = contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA"], var.flow_logs_metadata)
    error_message = "Must be one of: INCLUDE_ALL_METADATA, EXCLUDE_ALL_METADATA."
  }
}

# 050-nat

variable "nat_logs_enabled" {
  description = "Whether Cloud NAT logging should be enabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "nat_logs_filter" {
  description = "Cloud NAT logs filtering - errors, translations, or both."
  type        = string
  default     = "ERRORS_ONLY"
  nullable    = false
  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat_logs_filter)
    error_message = "Must be one of: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL."
  }
}

# 060-cluster

variable "release_channel" {
  description = "Release channel the cluster is subscribed to."
  type        = string
  default     = "RAPID"
  nullable    = false
  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Must be one of: UNSPECIFIED, RAPID, REGULAR, STABLE."
  }
}

variable "enable_private_endpoint" {
  description = <<-EOT
    If set to true, the cluster will be private and can only be managed using the private IP address
    of the master API endpoint. Even if access to the public endpoint is disabled, Google can use the control plane's
    public endpoint for cluster management purposes, such as scheduled maintenance and automatic upgrades.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "private_cluster_master_global_access" {
  description = <<-EOT
    If set to true, the control plane's private endpoint global access is enabled and internal clients can access
    the control plane's private endpoint from any region. If set to false, these clients must be located
    in the same region as the cluster. This setting has no effect on public access to the control plane.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "master_ipv4_cidr_block" {
  description = "The CIDR range for hosted GKE master network (must be /28)."
  type        = string
  default     = "172.16.0.0/28"
  nullable    = false
  validation {
    condition     = can(cidrnetmask(var.master_ipv4_cidr_block))
    error_message = "Requires a valid IPv4 CIDR, as defined in RFC 4632 section 3.1."
  }
}

variable "master_authorized_networks" {
  description = "The map {name to CIDR} for IP ranges allowed to access the cluster control plane."
  type        = map(string)
  # Example:
  # {
  #   warning-publicly-accessible-endpoint : "0.0.0.0/0"
  #   my-home-ip : "1.1.1.1/32"
  # }
  default  = {}
  nullable = false
  # TODO validate the map keys and values: keys must be legit IDs, and values are CIDRs
}
