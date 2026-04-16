output "network_id" {
  value = docker_network.this.id
}

output "network_name" {
  description = "Name of the VPC container network."
  value       = docker_network.this.name
}
