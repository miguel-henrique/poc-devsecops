# Root stack: compose modules like a cloud landing zone (network → data → compute → edge).

module "network" {
  source = "./modules/network"

  project_name = var.project_name
  network_name = var.network_name
}

module "database" {
  source = "./modules/database"

  project_name = var.project_name
  network_id   = module.network.network_id

  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  postgres_db       = var.postgres_db
  postgres_image    = var.postgres_image
}

module "backend" {
  source = "./modules/backend"

  project_name      = var.project_name
  network_id        = module.network.network_id
  replica_count     = var.backend_replica_count
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  postgres_db       = var.postgres_db
  db_host           = module.database.db_host
  db_port           = module.database.db_port
}

module "frontend" {
  source = "./modules/frontend"

  project_name       = var.project_name
  network_id         = module.network.network_id
  backend_hostnames  = module.backend.container_hostnames
  host_port          = var.host_frontend_port
}
