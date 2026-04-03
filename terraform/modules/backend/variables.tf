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
