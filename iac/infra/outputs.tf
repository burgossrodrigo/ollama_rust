output "cluster_name" {
  value = google_container_cluster.main.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.main.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "zone" {
  value = var.zone
}

output "region" {
  value = var.region
}

output "project_id" {
  value = var.project_id
}

output "dns_zone_name" {
  value = google_dns_managed_zone.web.name
}

output "dns_nameservers" {
  description = "Nameservers da zona Cloud DNS — adicione como NS no Porkbun para chat.rodrigoburgos.tech"
  value       = google_dns_managed_zone.web.name_servers
}

output "kubeconfig_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone} --project ${var.project_id}"
}
