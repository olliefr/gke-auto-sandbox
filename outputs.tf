# From network stage:
output "cluster_max_nodes" {
  description = "Maximum number of nodes in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.cluster_subnetwork_ipv4_cidr)[1]))) - 4
}
output "cluster_max_pods" {
  description = "Maximum number of GKE Pods in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.pods_ipv4_cidr)[1])))
}
output "cluster_max_services" {
  description = "Maximum number of GKE Services in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.services_ipv4_cidr)[1])))
}
