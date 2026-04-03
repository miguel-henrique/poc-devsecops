output "container_name" {
  value = docker_container.web.name
}

output "url" {
  value = "http://localhost:${var.host_port}"
}
