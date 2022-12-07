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
