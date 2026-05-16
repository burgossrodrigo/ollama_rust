output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone} --project ${var.project_id}"
}

output "ingress_ip_command" {
  description = "Command to get the Ingress external IP after apply"
  value       = "kubectl get ingress ollama-web-ingress -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
