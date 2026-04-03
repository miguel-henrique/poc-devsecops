variable "project_name" {
  type = string
}

variable "network_id" {
  type = string
}

variable "backend_hostnames" {
  description = "Backend container hostnames for nginx upstream (load balancing)."
  type        = list(string)
}

variable "host_port" {
  type = number
}
