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
    prefix = "ollama"
  }
}

# ── Providers ─────────────────────────────────────────────────────────────────

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.main.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.main.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

data "google_client_config" "default" {}

# ── Rede ──────────────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Router + NAT para que os nós Spot consigam acessar a internet (pull de imagens)
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ── Cluster GKE Standard ──────────────────────────────────────────────────────

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.zone   # zona única → sem custo inter-zonal

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Remover o node pool default (vamos criar o nosso próprio)
  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Logging mínimo para evitar cobrança no Cloud Logging
  logging_config {
    enable_components = []
  }

  monitoring_config {
    enable_components = []
  }

  release_channel {
    channel = "REGULAR"
  }
}

# ── Node Pool — Spot + T4 GPU ─────────────────────────────────────────────────

resource "google_container_node_pool" "gpu_spot" {
  name       = "gpu-spot-pool"
  cluster    = google_container_cluster.main.id
  location   = var.zone
  node_count = 1

  node_config {
    machine_type = var.node_machine_type
    spot         = true   # Spot = até 90% de desconto; pode ser preemptado

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1

      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Taint para garantir que só workloads com toleração rodem aqui
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    labels = {
      workload = "llm"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ── Namespace ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "ollama" {
  metadata {
    name = "ollama"
  }

  depends_on = [google_container_node_pool.gpu_spot]
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
}

# ── Ollama — Deployment ───────────────────────────────────────────────────────

resource "kubernetes_deployment" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
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
        # Garante que o pod vai para o nó com GPU
        node_selector = {
          "cloud.google.com/gke-accelerator" = "nvidia-tesla-t4"
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Equal"
          value    = "present"
          effect   = "NoSchedule"
        }

        # Puxa o modelo na inicialização antes do servidor subir
        init_container {
          name  = "pull-model"
          image = "ollama/ollama:latest"

          command = ["ollama", "pull", var.ollama_model]

          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0"
          }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama"
          }

          resources {
            requests = {
              "nvidia.com/gpu" = "1"
            }
            limits = {
              "nvidia.com/gpu" = "1"
            }
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

# ── Ollama — Service (ClusterIP, interno) ─────────────────────────────────────

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
          "cloud.google.com/gke-accelerator" = "nvidia-tesla-t4"
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Equal"
          value    = "present"
          effect   = "NoSchedule"
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
              cpu    = "500m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1"
              memory = "512Mi"
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

# ── API Rust — Service (ClusterIP — exposto externamente via nginx do web pod) ─

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
