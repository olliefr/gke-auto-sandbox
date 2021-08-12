# See README.md for more information on the input variables.

variable "project" {
  description = "GCP project ID to deploy resources into. Set at Google provider level."
  type        = string
}

variable "region" {
  description = "GCP region to deploy resources into. Set at Google provider level."
  type        = string
}

variable "zone" {
  description = "GCP zone to deploy resources into. Set at Google provider level."
  type        = string
}

variable "authorized_networks" {
  description = "Access to the GKE public endpoint is restricted to the IP address ranges from this list."
  type        = list(object({
    cidr_block:   string
    display_name: string
  }))
  default     = []
}

variable "preemptible" {
  description = "Whether to use preemptible VM instances for the GKE cluster node pool. True by default."
  type        = bool
  default     = true
}
