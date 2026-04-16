output "container_name" {
  description = "Name of the ELB-NGINX container."
  value       = docker_container.web.name
}

output "url" {
  value = "http://localhost:${var.host_port}"
}
