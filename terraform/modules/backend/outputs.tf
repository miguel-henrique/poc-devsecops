output "container_names" {
  value = [for c in docker_container.api : c.name]
}

output "container_hostnames" {
  description = "Hostnames resolvable on the Docker network for nginx upstream."
  value       = [for c in docker_container.api : c.name]
}
