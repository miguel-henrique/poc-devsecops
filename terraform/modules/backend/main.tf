resource "docker_image" "backend" {
  name = "${var.project_name}-backend:latest"
  build {
    context    = abspath("${path.root}/../app/backend")
    dockerfile = "Dockerfile"
  }

  triggers = {
    dockerfile = filemd5(abspath("${path.root}/../app/backend/Dockerfile"))
    main_py    = filemd5(abspath("${path.root}/../app/backend/main.py"))
  }
}

resource "docker_container" "api" {
  count = var.replica_count

  name  = "${var.project_name}-api-${count.index}"
  image = docker_image.backend.image_id

  restart = "unless-stopped"

  env = [
    "PGHOST=${var.db_host}",
    "PGPORT=${tostring(var.db_port)}",
    "PGUSER=${var.postgres_user}",
    "PGPASSWORD=${var.postgres_password}",
    "PGDATABASE=${var.postgres_db}",
    "REPLICA_INDEX=${count.index}",
  ]

  networks_advanced {
    name = var.network_id
  }

  # Explicitly avoid privileged mode (see README: Checkov flags privileged = true).
  privileged = false

  healthcheck {
    test     = ["CMD-SHELL", "curl -fsS http://127.0.0.1:8000/health || exit 1"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }

  labels {
    label = "role"
    value = "backend"
  }

  labels {
    label = "replica"
    value = tostring(count.index)
  }
}
