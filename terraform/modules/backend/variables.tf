variable "project_name" {
  type = string
}

variable "network_id" {
  type = string
}

variable "replica_count" {
  type = number
}

variable "postgres_user" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_db" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "pip_trusted_host_build" {
  description = "If true, pip uses --trusted-host for PyPI during image build (corporate SSL/proxy)."
  type        = bool
  default     = false
}
