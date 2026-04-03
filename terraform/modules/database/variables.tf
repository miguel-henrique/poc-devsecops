variable "project_name" {
  type = string
}

variable "network_id" {
  type = string
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

variable "postgres_image" {
  type = string
}
