# # https://goteleport.com/docs/reference/terraform-provider/resources/saml_connector/
# # https://github.com/gravitational/teleport/discussions/20630

resource "kubectl_manifest" "google_saml" {
  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v2"
    kind       = "TeleportSAMLConnector"
    metadata = {
      name      = "googlesaml"
      namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
    }
    spec = {
      display             = "Google SAML"
      allow_idp_initiated = true
      attributes_to_roles = [
        {
          name  = "groups"
          roles = ["access"]
          value = "pon-access"
        },
        {
          name  = "groups"
          roles = ["editor"]
          value = "pon-editor"
        },
      ]
      acs               = var.google_acs
      entity_descriptor = var.google_entity_descriptor
    }
  })
}
