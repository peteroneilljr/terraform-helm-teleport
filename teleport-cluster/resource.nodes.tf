resource "random_string" "teleport_node_token" {
  length  = 32
  special = false
  upper   = false
  lower   = true
}


resource "kubectl_manifest" "teleport_node_token" {
  yaml_body = yamlencode(
    {
      apiVersion = "resources.teleport.dev/v2"
      kind       = "TeleportProvisionToken"

      metadata = {
        name      = random_string.teleport_node_token.result
        namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      }

      spec = {
        roles       = ["Node"]
        join_method = "token"

      }
    }
  )

  depends_on = [
    helm_release.teleport_cluster
  ]
}

locals { 
  teleport_apt_entrypoint_sh = <<-EOT
    apt-get update && \
    apt-get install -y curl && \
    URL="https://${local.teleport_cluster_fqdn}/scripts/install.sh"; \
    for i in {1..60}; do curl "$URL" >/dev/null && break || \
    sleep 5; done && curl "$URL" | bash && \
    /usr/local/bin/teleport start --roles=node --auth-server=${local.teleport_cluster_fqdn}:443 --token=${random_string.teleport_node_token.result} --nodename=ubuntu
  EOT
  
  teleport_yum_entrypoint_sh = <<-EOT
    yum update -y && \
    curl https://cdn.teleport.dev/teleport-update-v${var.teleport_version}-linux-amd64-bin.tar.gz --output teleport-update-${var.teleport_version}.tgz && \
    tar xf teleport-update-${var.teleport_version}.tgz && \
    cd ./teleport && \
    ./teleport-update enable --proxy ${local.teleport_cluster_fqdn} && \
    /usr/local/bin/teleport start --roles=node --auth-server=${local.teleport_cluster_fqdn}:443 --token=${random_string.teleport_node_token.result} --nodename=rockylinux
  EOT
}

resource "kubernetes_deployment" "teleport_node_ubuntu" {
  metadata {
    name = "${var.resource_prefix}ubuntu"
    namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
    labels = {
      app = "ubuntu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ubuntu"
      }
    }

    template {
      metadata {
        labels = {
          app = "ubuntu"
        }
      }

      spec {
        container {
          name  = "ubuntu"
          image = "ubuntu:latest"

          command = ["/bin/bash", "-c"]
          args = [local.teleport_apt_entrypoint_sh]

        }
      }
    }
  }
}

resource "kubernetes_deployment" "teleport_node_rocky" {
  metadata {
    name = "${var.resource_prefix}rocky"
    namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
    labels = {
      app = "rocky"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rocky"
      }
    }

    template {
      metadata {
        labels = {
          app = "rocky"
        }
      }

      spec {
        container {
          name  = "rocky"
          image = "rockylinux:9"

          command = ["/bin/bash", "-c"]
          args = [local.teleport_yum_entrypoint_sh]

        }
      }
    }
  }
}