variable "web_image" {
  description = "Docker image para o frontend React (ex: gcr.io/PROJECT/ollama-web:latest)"
  type        = string
}

variable "web_domain" {
  description = "Domínio para o frontend (ex: chat.example.com) — usado no ManagedCertificate"
  type        = string
}

# ── Cloud DNS — zona e registro A apontando para o IP dinâmico do Ingress ────
# O Terraform aguarda o LB ser provisionado antes de criar o registro,
# portanto o IP estará disponível quando o record set for criado.

resource "google_dns_managed_zone" "web" {
  name        = "chat-rodrigoburgos-tech"
  dns_name    = "chat.rodrigoburgos.tech."
  description = "Zona delegada para o subdominio chat.rodrigoburgos.tech"
  project     = var.project_id
}

resource "google_dns_record_set" "chat" {
  name         = "chat.rodrigoburgos.tech."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.web.name
  project      = var.project_id
  rrdatas      = [kubernetes_ingress_v1.web.status[0].load_balancer[0].ingress[0].ip]
}

# ── GKE ManagedCertificate (TLS provisionado automaticamente pelo GCP) ─────────

resource "kubernetes_manifest" "web_cert" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "web-managed-cert"
      namespace = kubernetes_namespace.ollama.metadata[0].name
    }
    spec = {
      domains = [var.web_domain]
    }
  }

  depends_on = [kubernetes_namespace.ollama]
}

# ── Web — Deployment ──────────────────────────────────────────────────────────

resource "kubernetes_deployment" "web" {
  metadata {
    name      = "ollama-web"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "ollama-web" }
    }

    template {
      metadata {
        labels = { app = "ollama-web" }
      }

      spec {
        # Coexiste no mesmo nó GPU para não gerar custo de nó adicional.
        node_selector = {
          "cloud.google.com/gke-accelerator" = "nvidia-tesla-t4"
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Equal"
          value    = "present"
          effect   = "NoSchedule"
        }

        container {
          name  = "web"
          image = var.web_image

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.api]
}

# ── Web — Service NodePort (GKE Ingress/GCLB exige NodePort no backend) ───────

resource "kubernetes_service" "web" {
  metadata {
    name      = "ollama-web"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    selector = { app = "ollama-web" }
    type     = "NodePort"

    port {
      port        = 80
      target_port = 80
    }
  }
}

# ── GKE Ingress (GCLB) ────────────────────────────────────────────────────────

resource "kubernetes_ingress_v1" "web" {
  metadata {
    name      = "ollama-web-ingress"
    namespace = kubernetes_namespace.ollama.metadata[0].name

    annotations = {
      "networking.gke.io/managed-certificates" = "web-managed-cert"
      "kubernetes.io/ingress.class"             = "gce"
    }
  }

  spec {
    rule {
      host = var.web_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.web.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.web_cert,
    kubernetes_deployment.web,
  ]
}
