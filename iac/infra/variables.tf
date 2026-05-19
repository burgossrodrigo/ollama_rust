variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-c"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "ollama-qwen-cluster"
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
  default     = "10.11.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for pods"
  type        = string
  default     = "10.21.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for services"
  type        = string
  default     = "10.31.0.0/16"
}

variable "node_locations" {
  description = "Zones within the region where GPU nodes run (change to avoid stockout)"
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "node_machine_type" {
  description = "Machine type for the GPU node pool"
  type        = string
  default     = "n1-standard-4"
}
