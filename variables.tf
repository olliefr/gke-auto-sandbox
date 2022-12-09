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

variable "use_spot_vms" {
  description = "Use Spot VMs for GKE cluster nodes to substantially reduce cost. Default is true."
  type        = bool
  default     = true
  nullable    = false
}
