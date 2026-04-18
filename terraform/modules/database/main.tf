resource "docker_image" "postgres" {
  name         = var.postgres_image
  keep_locally = false
}

resource "docker_volume" "data" {
  name = "${var.project_name}-postgres-data"
}

resource "docker_container" "postgres" {
  name  = "RDS-POSTGRES"
  image = docker_image.postgres.image_id

  restart = "unless-stopped"

  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}",
  ]

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = var.network_id
    aliases = [
      "${var.project_name}-db",
      "db",
    ]
  }

  # Security posture: do not grant elevated privileges (Checkov flags privileged=true).
  privileged = false

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.postgres_user} -d ${var.postgres_db}"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }

  labels {
    label = "role"
    value = "database"
  }
}
