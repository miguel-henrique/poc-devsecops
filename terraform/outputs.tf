output "network_id" {
  description = "Docker network ID (simulated VPC attachment)."
  value       = module.network.network_id
}

output "database_host" {
  description = "Internal hostname for PostgreSQL on the app network."
  value       = module.database.db_host
}

output "backend_container_names" {
  description = "Names of running backend replicas."
  value       = module.backend.container_names
}

output "frontend_url" {
  description = "URL to open the UI in a browser."
  value       = "http://localhost:${var.host_frontend_port}"
}

output "api_proxy_path" {
  description = "Frontend proxies /api to the backend pool; use same origin to avoid CORS."
  value       = "http://localhost:${var.host_frontend_port}/api/"
}
