variable "project" {
  description = "The project ID to deploy the cluster into. Must be linked to a billing account."
  type        = string
  nullable    = false
}

variable "region" {
  description = "GCP region to deploy the resources into."
  type        = string
  default     = "europe-west2"
  nullable    = false
}

variable "zone" {
  description = "GCP zone to deploy the resources into."
  type        = string
  default     = "europe-west2-a"
  nullable    = false
}

variable "authorized_networks" {
  description = "The CIDR blocks allowed to access the cluster control plane."
  type = list(object({
    cidr_block : string
    display_name : string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "warning-publicly-accessible-endpoint"
    },
  ]
  nullable = false
}

variable "preemptible" {
  description = "Should GKE cluster nodes be preemptible VM instances? Default is true."
  type        = bool
  default     = true
  nullable    = false
}
