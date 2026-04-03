resource "docker_network" "this" {
  name = "${var.project_name}-${var.network_name}"

  driver = "bridge"

  ipam_config {
    subnet = "172.28.0.0/16"
  }

  labels {
    label = "environment"
    value = "local-poc"
  }

  labels {
    label = "simulates"
    value = "aws-vpc"
  }
}
