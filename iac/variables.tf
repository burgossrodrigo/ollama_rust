variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "GCP zone (single-zone to avoid inter-zone traffic costs)"
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "ollama-cluster"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "ollama-vpc"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "ollama-subnet"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.10.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for services"
  type        = string
  default     = "10.30.0.0/16"
}

variable "node_machine_type" {
  description = "Machine type for the GPU node pool"
  type        = string
  default     = "n1-standard-4"
}

variable "ollama_model" {
  description = "Ollama model to serve"
  type        = string
  default     = "qwen3:8b"
}

variable "api_image" {
  description = "Docker image for the Rust API (e.g. gcr.io/PROJECT/ollama-api:latest)"
  type        = string
}

variable "semaphore_limit" {
  description = "Max concurrent GPU requests in the Rust API"
  type        = number
  default     = 3
}
