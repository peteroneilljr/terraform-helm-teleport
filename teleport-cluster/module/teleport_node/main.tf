resource "kubernetes_deployment" "this" {
  for_each = var.nodes

  metadata {
    name      = each.value.name
    namespace = each.value.namespace
    labels = {
      app = each.value.name
    }
  }

  wait_for_rollout = lookup(each.value, "wait_for_rollout", false)

  spec {
    replicas = lookup(each.value, "replicas", 1)

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }

      spec {
        hostname = each.value.name
        container {
          name  = each.value.name
          image = each.value.image

          command = lookup(each.value, "command", ["/bin/sh", "-c"])
          args    = lookup(each.value, "args", [])

        }
      }
    }
  }
}
