variable "docker_host" {
  description = "Docker daemon address (local socket or remote TCP)."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "project_name" {
  description = "Prefix for named resources (simulates cloud resource naming)."
  type        = string
  default     = "poc-devsecops"
}

variable "network_name" {
  description = "Logical name for the Docker network (simulates a VPC identifier)."
  type        = string
  default     = "app-vpc"
}

variable "postgres_user" {
  description = "Database user (prefer setting via TF_VAR_postgres_user or terraform.tfvars)."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Database password (set via environment or terraform.tfvars — never commit secrets)."
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "Application database name."
  type        = string
  default     = "appdb"
}

variable "backend_replica_count" {
  description = "Number of backend API containers (local scaling simulation)."
  type        = number
  default     = 2

  validation {
    condition     = var.backend_replica_count >= 1 && var.backend_replica_count <= 5
    error_message = "backend_replica_count must be between 1 and 5 for this PoC."
  }
}

variable "host_frontend_port" {
  description = "Published host port for the web UI (nginx)."
  type        = number
  default     = 3000
}

variable "postgres_image" {
  description = "PostgreSQL image reference."
  type        = string
  default     = "postgres:16-alpine"
}
