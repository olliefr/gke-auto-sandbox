# From network stage:
output "cluster_max_nodes" {
  description = "Maximum number of nodes in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.node_cidr_range)[1]))) - 4
}
output "cluster_max_pods" {
  description = "Maximum number of GKE Pods in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.pod_cidr_range)[1])))
}
output "cluster_max_services" {
  description = "Maximum number of GKE Services in this cluster."
  value       = pow(2, (32 - tonumber(split("/", var.service_cidr_range)[1])))
}
