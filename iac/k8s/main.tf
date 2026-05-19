terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }

  backend "gcs" {
    bucket = "ollama-rust-tfstate"
    prefix = "ollama/k8s"
  }
}

data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "ollama-rust-tfstate"
    prefix = "ollama/infra"
  }
}

data "google_client_config" "default" {}

provider "google" {
  project = data.terraform_remote_state.infra.outputs.project_id
  region  = data.terraform_remote_state.infra.outputs.region
  zone    = data.terraform_remote_state.infra.outputs.zone
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

# ── Namespace ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "ollama" {
  metadata {
    name = "ollama"
  }
}

# ── Ollama — PVC ──────────────────────────────────────────────────────────────

resource "kubernetes_persistent_volume_claim" "ollama_models" {
  metadata {
    name      = "ollama-models"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard-rwo"

    resources {
      requests = {
        storage = "30Gi"
      }
    }
  }

  wait_until_bound = false
}

# ── Ollama — Deployment ───────────────────────────────────────────────────────

resource "kubernetes_deployment" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "ollama" }
    }

    template {
      metadata {
        labels = { app = "ollama" }
      }

      spec {
        node_selector = {
          "cloud.google.com/gke-accelerator" = "nvidia-tesla-t4"
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Equal"
          value    = "present"
          effect   = "NoSchedule"
        }

        init_container {
          name  = "pull-model"
          image = "ollama/ollama:latest"

          command = ["/bin/sh", "-c", "ollama serve & SERVER_PID=$! && until ollama list > /dev/null 2>&1; do sleep 2; done && ollama pull ${var.ollama_model} && kill $SERVER_PID"]

          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0"
          }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama"
          }

          resources {
            requests = { "nvidia.com/gpu" = "1" }
            limits   = { "nvidia.com/gpu" = "1" }
          }
        }

        container {
          name  = "ollama"
          image = "ollama/ollama:latest"

          env {
            name  = "OLLAMA_DEBUG"
            value = "false"
          }
          env {
            name  = "OLLAMA_KEEP_ALIVE"
            value = "24h"
          }
          env {
            name  = "OLLAMA_NUM_PARALLEL"
            value = tostring(var.semaphore_limit)
          }

          port {
            container_port = 11434
          }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama"
          }

          resources {
            requests = {
              cpu              = "2"
              memory           = "8Gi"
              "nvidia.com/gpu" = "1"
            }
            limits = {
              cpu              = "4"
              memory           = "14Gi"
              "nvidia.com/gpu" = "1"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/tags"
              port = 11434
            }
            initial_delay_seconds = 30
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/api/tags"
              port = 11434
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }

        volume {
          name = "models"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.ollama_models.metadata[0].name
          }
        }
      }
    }
  }
}

# ── Ollama — Service ──────────────────────────────────────────────────────────

resource "kubernetes_service" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    selector = { app = "ollama" }
    type     = "ClusterIP"

    port {
      port        = 11434
      target_port = 11434
    }
  }
}

# ── API Rust — Deployment ─────────────────────────────────────────────────────

resource "kubernetes_deployment" "api" {
  metadata {
    name      = "ollama-api"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "ollama-api" }
    }

    template {
      metadata {
        labels = { app = "ollama-api" }
      }

      spec {
        node_selector = {
          "workload" = "system"
        }

        container {
          name  = "api"
          image = var.api_image

          env {
            name  = "RUST_LOG"
            value = "error"
          }
          env {
            name  = "OLLAMA_URL"
            value = "http://ollama.ollama.svc.cluster.local:11434"
          }
          env {
            name  = "SEMAPHORE_LIMIT"
            value = tostring(var.semaphore_limit)
          }
          env {
            name  = "OLLAMA_MODEL"
            value = var.ollama_model
          }
          env {
            name  = "PORT"
            value = "8080"
          }

          port {
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.ollama]
}

# ── API Rust — Service ────────────────────────────────────────────────────────

resource "kubernetes_service" "api" {
  metadata {
    name      = "ollama-api"
    namespace = kubernetes_namespace.ollama.metadata[0].name
  }

  spec {
    selector = { app = "ollama-api" }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = 8080
    }
  }
}

# ── Web — ManagedCertificate ──────────────────────────────────────────────────

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
        node_selector = {
          "workload" = "system"
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

# ── Web — Service ─────────────────────────────────────────────────────────────

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

# ── Web — Ingress ─────────────────────────────────────────────────────────────

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

# ── DNS — registro A ──────────────────────────────────────────────────────────

resource "google_dns_record_set" "chat" {
  name         = "chat.rodrigoburgos.tech."
  type         = "A"
  ttl          = 300
  managed_zone = data.terraform_remote_state.infra.outputs.dns_zone_name
  project      = data.terraform_remote_state.infra.outputs.project_id
  rrdatas      = [kubernetes_ingress_v1.web.status[0].load_balancer[0].ingress[0].ip]
}
