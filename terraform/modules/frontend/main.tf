resource "local_file" "nginx_conf" {
  content = templatefile("${path.module}/templates/default.conf.tftpl", {
    backend_hosts = var.backend_hostnames
  })
  # Under app/frontend so Docker build COPY sees a normal host path (bind mounts from
  # Terraform-in-Docker used /project/... which the daemon could not map to a file).
  filename = abspath("${path.root}/../app/frontend/generated/default.conf")
}

resource "docker_image" "frontend" {
  name = "${var.project_name}-frontend:latest"
  build {
    context    = abspath("${path.root}/../app/frontend")
    dockerfile = "Dockerfile"
  }

  depends_on = [local_file.nginx_conf]

  triggers = {
    dockerfile = filemd5(abspath("${path.root}/../app/frontend/Dockerfile"))
    index      = filemd5(abspath("${path.root}/../app/frontend/static/index.html"))
    nginx      = local_file.nginx_conf.content_md5
  }
}

resource "docker_container" "web" {
  name  = "ELB-NGINX"
  image = docker_image.frontend.image_id

  restart = "unless-stopped"

  ports {
    internal = 8080
    external = var.host_port
  }

  networks_advanced {
    name = var.network_id
  }

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
