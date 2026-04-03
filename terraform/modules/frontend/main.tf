resource "local_file" "nginx_conf" {
  content = templatefile("${path.module}/templates/default.conf.tftpl", {
    backend_hosts = var.backend_hostnames
  })
  filename = "${path.module}/.generated/default.conf"
}

resource "docker_image" "frontend" {
  name = "${var.project_name}-frontend:latest"
  build {
    context    = abspath("${path.root}/../app/frontend")
    dockerfile = "Dockerfile"
  }

  triggers = {
    dockerfile = filemd5(abspath("${path.root}/../app/frontend/Dockerfile"))
    index      = filemd5(abspath("${path.root}/../app/frontend/static/index.html"))
  }
}

resource "docker_container" "web" {
  name  = "${var.project_name}-web"
  image = docker_image.frontend.image_id

  restart = "unless-stopped"

  ports {
    internal = 8080
    external = var.host_port
  }

  networks_advanced {
    name = var.network_id
  }

  volumes {
    host_path      = abspath(local_file.nginx_conf.filename)
    container_path = "/etc/nginx/conf.d/default.conf"
    read_only      = true
  }

  depends_on = [local_file.nginx_conf]

  privileged = false

  healthcheck {
    test     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/ || exit 1"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }

  labels {
    label = "role"
    value = "frontend"
  }
}
