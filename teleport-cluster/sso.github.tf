resource "kubernetes_secret" "sso_github" {
  metadata {
    name      = "${var.resource_prefix}github-oauth"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
    annotations = {
      "resources.teleport.dev/allow-lookup-from-cr" = "*"
    }
  }

  data = {
    "client_secret" = var.github_client_secret
  }

  type = "Opaque"
}

resource "kubectl_manifest" "sso_github" {
  yaml_body = yamlencode(
    {
      apiVersion = "resources.teleport.dev/v3"
      kind       = "TeleportGithubConnector"

      metadata = {
        name      = "github"
        namespace = helm_release.teleport_cluster.namespace
      }

      spec = {
        api_endpoint_url = "https://api.github.com"
        client_id        = var.github_client_id
        client_secret    = "secret://${kubernetes_secret.sso_github.metadata[0].name}/client_secret"
        display          = "GitHub"
        endpoint_url     = "https://github.com"
        redirect_url     = "https://${local.teleport_cluster_fqdn}:443/v1/webapi/github/callback"
        client_redirect_settings = {
          allowed_https_hostnames = [
            "${local.teleport_cluster_fqdn}:443"
          ]
        }
        teams_to_roles = [
          {
            organization = "peteroneilljr-org"
            team         = "operators"
            roles = [
              "${var.resource_prefix}aws-ro",
              "${var.resource_prefix}postgresql",
              "${var.resource_prefix}k8s",
              "${var.resource_prefix}vnet",
              "reviewer",
              "access",
              "editor"
            ]
          }
        ]
      }
    }
  )
}