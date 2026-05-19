terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "ollama-rust-tfstate"
    prefix = "ollama/infra"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

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
  location = var.zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

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

# ── Node Pool — GPU T4 ────────────────────────────────────────────────────────

resource "google_container_node_pool" "gpu_spot" {
  name       = "gpu-spot-pool"
  cluster    = google_container_cluster.main.id
  location   = var.zone
  node_count = 1

  node_config {
    machine_type = var.node_machine_type
    spot         = false

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

# ── Cloud DNS ─────────────────────────────────────────────────────────────────

resource "google_dns_managed_zone" "web" {
  name        = "chat-rodrigoburgos-tech"
  dns_name    = "chat.rodrigoburgos.tech."
  description = "Zona delegada para o subdominio chat.rodrigoburgos.tech"
  project     = var.project_id
}
