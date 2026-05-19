variable "api_image" {
  description = "Docker image for the Rust API"
  type        = string
}

variable "web_image" {
  description = "Docker image for the React frontend"
  type        = string
}

variable "web_domain" {
  description = "Domain for the web frontend (used in ManagedCertificate and Ingress)"
  type        = string
}

variable "ollama_model" {
  description = "Ollama model to serve"
  type        = string
  default     = "qwen3:8b"
}

variable "semaphore_limit" {
  description = "Max concurrent GPU requests in the Rust API"
  type        = number
  default     = 3
}
