output "db_host" {
  description = "Stable DNS name on the Docker network (RDS-POSTGRES)."
  value       = docker_container.postgres.name
}

output "db_port" {
  value = 5432
}

output "container_id" {
  value = docker_container.postgres.id
}
