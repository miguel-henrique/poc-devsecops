output "container_names" {
  description = "Names of running EKS-FASTAPI containers."
  value       = [for c in docker_container.api : c.name]
}

output "container_hostnames" {
  description = "Hostnames resolvable on the Docker network for nginx upstream (EKS-FASTAPI)."
  value       = [for c in docker_container.api : c.name]
}
