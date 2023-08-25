# From network stage:
output "nodes_per_cluster_limit" {
  description = "The limit on the number of nodes in this cluster. Immutable."
  value       = pow(2, (32 - tonumber(split("/", var.cluster_subnetwork_ipv4_cidr)[1]))) - 4
}
output "pods_per_cluster_limit" {
  description = "The limit on the number of Pods in this cluster. Additional secondary IPv4 ranges can be added to increase."
  value       = pow(2, (32 - tonumber(split("/", var.pods_ipv4_cidr)[1])))
}
output "services_per_cluster_limit" {
  description = "The limit on the number of Services in this cluster. Immutable."
  value       = pow(2, (32 - tonumber((var.services_ipv4_cidr != null) ? split("/", var.services_ipv4_cidr)[1] : 20)))
}
