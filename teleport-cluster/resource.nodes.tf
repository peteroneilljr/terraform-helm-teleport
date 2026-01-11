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
  teleport_apt_managed_updates_entrypoint_sh = <<-EOT
    apt-get update && \
    apt-get install -y curl && \
    ${local.teleport_managed_updates_entrypoint_sh}
  EOT
  teleport_managed_updates_entrypoint_sh = <<-EOT
    curl -o teleport-update.tgz https://cdn.teleport.dev/teleport-update-v${var.teleport_version}-linux-amd64-bin.tar.gz && \
    tar xf teleport-update.tgz && cd ./teleport && \
    ./teleport-update enable --proxy ${local.teleport_cluster_fqdn} && \
    /usr/local/bin/teleport start --roles=node --auth-server=${local.teleport_cluster_fqdn}:443 --token=${random_string.teleport_node_token.result}
  EOT
}


module "teleport_nodes" {
  source = "./module/teleport_node"

  nodes = {
    rocky9 = {
      name      = "rocky9"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "rockylinux:9"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_managed_updates_entrypoint_sh]
    }

    rocky8 = {
      name      = "rocky8"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "rockylinux:8"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_managed_updates_entrypoint_sh]
    }

    ubuntu2404 = {
      name      = "ubuntu2404"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "ubuntu:24.04"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_apt_managed_updates_entrypoint_sh]
    }

    ubuntu2204 = {
      name      = "ubuntu2204"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "ubuntu:22.04"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_apt_managed_updates_entrypoint_sh]
    }

    ubuntu1604 = {
      name      = "ubuntu1604"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "ubuntu:16.04"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_apt_managed_updates_entrypoint_sh]
    }

    centos7 = {
      name      = "centos7"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "centos:7"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_managed_updates_entrypoint_sh]
    }

    centos8 = {
      name      = "centos8"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "centos:8"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_managed_updates_entrypoint_sh]
    }

    debian11 = {
      name      = "debian11"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "debian:11"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_apt_managed_updates_entrypoint_sh]
    }

    debian13 = {
      name      = "debian13"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      image     = "debian:13"
      command   = ["/bin/bash", "-c"]
      args      = [local.teleport_apt_managed_updates_entrypoint_sh]
    }
  }

  depends_on = [
    helm_release.teleport_cluster
  ]
}