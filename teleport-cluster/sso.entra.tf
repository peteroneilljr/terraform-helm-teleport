# resource "teleport_saml_connector" "entra_id" {
#   version = "v2"

#   metadata = {
#     name = "entra-id"
#   }

#   spec = {
#     display             = "Microsoft"
#     allow_idp_initiated = true

#     attributes_to_roles = [{
#       name = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
#       roles = [
#         teleport_role.device_trust.metadata.name,
#         teleport_role.windows_auto_user_developer.metadata.name,
#       ]
#       value = "*"
#     }]

#     entity_descriptor_url   = var.entra_entity_descriptor_url
#     issuer                  = var.entra_issuer
#     acs                     = var.entra_service_provider_issuer
#     service_provider_issuer = var.entra_service_provider_issuer
#     sso                     = var.entra_sso
#   }
# }
