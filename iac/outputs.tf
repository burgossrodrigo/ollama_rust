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

output "dns_nameservers" {
  description = "Nameservers da zona Cloud DNS — adicione como registros NS no Porkbun para chat.rodrigoburgos.tech"
  value       = google_dns_managed_zone.web.name_servers
}
