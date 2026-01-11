# Step 1: Create a custom Certificate Authority (CA)
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "Custom PostgreSQL CA"
    organization = "Terraform CA"
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Step 2: Generate a server private key and CSR
resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server_csr" {
  private_key_pem = tls_private_key.server_key.private_key_pem

  subject {
    common_name  = "developer"
    organization = "Terraform Server"
  }

  dns_names = [
    "${var.resource_prefix}postgres-postgresql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}",
    "${var.resource_prefix}postgres-postgresql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}.svc.cluster.local"
  ]
}

# Step 3: Sign the server certificate with the CA
resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem   = tls_cert_request.server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "client_auth",
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Step 4: Download Teleport DB CA cert
data "http" "teleport_db_ca_cert" {
  url = "https://${aws_route53_record.cluster_endpoint.fqdn}/webapi/auth/export?type=db-client"

  retry {
    attempts     = 30
    min_delay_ms = 10000
  }

  depends_on = [
    aws_iam_role_policy_attachment.irsa_attach_dynamodb,
    helm_release.teleport_cluster
  ]
}

# Step 5: Create Kubernetes TLS secret with certs
resource "kubernetes_secret" "postgres_tls" {
  metadata {
    name      = "${var.resource_prefix}postgresql-tls"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  }

  data = {
    "ca.crt"  = <<EOF
${tls_self_signed_cert.ca_cert.cert_pem}
${data.http.teleport_db_ca_cert.response_body}
    EOF
    "tls.crt" = tls_locally_signed_cert.server_cert.cert_pem
    "tls.key" = tls_private_key.server_key.private_key_pem
  }

  type = "Opaque"
}

# Step 6: Helm deploy PostgreSQL with TLS
resource "helm_release" "postgresql" {
  name       = "${var.resource_prefix}postgres"
  namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  # version    = "latest"

  wait = false

  values = [
    <<EOF
image:
  registry: docker.io
  repository: bitnamilegacy/postgresql
  tag: latest
volumePermissions:
  image:
    registry: docker.io
    repository: bitnamilegacy/os-shell
    tag: latest
tls:
  enabled: true
  preferServerCiphers: true
  certificatesSecret: ${kubernetes_secret.postgres_tls.metadata[0].name}
  certFilename: tls.crt
  certKeyFilename: tls.key
  certCAFilename: ca.crt

auth:
  username: developer
  password: changeme
  database: teleport_db

primary:
  persistence:
      enabled: false
  shmVolume:
    enabled: true
  extraFlags:
    - "-c ssl=on"
    - "-c ssl_ca_file=/opt/bitnami/postgresql/certs/ca.crt"
    - "-c ssl_cert_file=/opt/bitnami/postgresql/certs/tls.crt"
    - "-c ssl_key_file=/opt/bitnami/postgresql/certs/tls.key"

  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenDeleted: Delete
    whenScaled: Retain

EOF
  ]
}

# ---------------------------------------------------------------------------- #
# Teleport Role
# ---------------------------------------------------------------------------- #
resource "kubectl_manifest" "teleport_role_postgresql" {
  yaml_body = <<EOF
apiVersion: resources.teleport.dev/v1
kind: TeleportRoleV7
metadata:
  annotations:
    teleport.dev/keep: "true"
  finalizers:
    - resources.teleport.dev/deletion
  name: "${var.resource_prefix}postgresql"
  namespace: ${helm_release.teleport_cluster.namespace}
spec:
  allow:
    db_labels:
      db: postgres
    db_names:
      - "teleport_db"
    db_users:
      - "developer"
    EOF
}
