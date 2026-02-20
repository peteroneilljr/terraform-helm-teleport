# Step 1: Create a custom Certificate Authority (CA)
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = var.ca_common_name
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
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "developer"
    organization = "Terraform Server"
  }

  dns_names = var.dns_names
}

# Step 3: Sign the server certificate with the CA
resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "client_auth",
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Step 4: Create Kubernetes TLS secret with certs
resource "kubernetes_secret" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  data = {
    "ca.crt"  = <<EOF
${tls_self_signed_cert.ca.cert_pem}
${var.teleport_db_ca_pem}
    EOF
    "tls.crt" = tls_locally_signed_cert.server.cert_pem
    "tls.key" = tls_private_key.server.private_key_pem
  }

  type = "Opaque"
}
