# Step 1: Create a custom Certificate Authority (CA) for MySQL
resource "tls_private_key" "mysql_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "mysql_ca_cert" {
  private_key_pem = tls_private_key.mysql_ca_key.private_key_pem

  subject {
    common_name  = "Custom MySQL CA"
    organization = "Terraform CA"
  }

  is_ca_certificate     = true
  validity_period_hours = 87600
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Step 2: Generate a server private key and CSR for MySQL
resource "tls_private_key" "mysql_server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "mysql_server_csr" {
  private_key_pem = tls_private_key.mysql_server_key.private_key_pem

  subject {
    common_name  = "developer"
    organization = "Terraform Server"
  }

  dns_names = [
    "${var.resource_prefix}mysql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}",
    "${var.resource_prefix}mysql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}.svc.cluster.local"
  ]
}

# Step 3: Sign the MySQL server certificate
resource "tls_locally_signed_cert" "mysql_server_cert" {
  cert_request_pem   = tls_cert_request.mysql_server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.mysql_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.mysql_ca_cert.cert_pem

  validity_period_hours = 8760
  allowed_uses = [
    "client_auth",
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Step 4: Shared Teleport DB CA cert 
# (Note: You only need ONE of these in your entire project)
data "http" "shared_teleport_db_ca" {
  url = "https://${aws_route53_record.cluster_endpoint.fqdn}/webapi/auth/export?type=db-client"

  retry {
    attempts     = 30
    min_delay_ms = 10000
  }
}

# Step 5: Create Kubernetes TLS secret for MySQL
resource "kubernetes_secret" "mysql_tls" {
  metadata {
    name      = "${var.resource_prefix}mysql-tls"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  }

  data = {
    "ca.crt"  = <<EOF
${tls_self_signed_cert.mysql_ca_cert.cert_pem}
${data.http.shared_teleport_db_ca.response_body}
    EOF
    "tls.crt" = tls_locally_signed_cert.mysql_server_cert.cert_pem
    "tls.key" = tls_private_key.mysql_server_key.private_key_pem
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "mysql_custom_init" {
  metadata {
    name      = "${var.resource_prefix}mysql-custom-init"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  }

  data = {
    "setup.sh" = <<-EOF
      #!/bin/bash
      mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<SQL
      CREATE USER 'developer'@'%' REQUIRE SUBJECT '/CN=developer';
      GRANT ALL PRIVILEGES ON *.* TO 'developer'@'%';
      SQL
    EOF
  }
}

# Step 6: Helm deploy MySQL
resource "helm_release" "mysql" {
  name       = "${var.resource_prefix}mysql"
  namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mysql"

  wait = false
  
  values = [
    <<-EOF
image:
  registry: docker.io
  repository: bitnamilegacy/mysql
  tag: 9.4.0-debian-12-r1
primary:
  extraVolumes:
    - name: custom-init
      configMap:
        name: ${kubernetes_config_map.mysql_custom_init.metadata[0].name}
        defaultMode: 0755
  extraVolumeMounts:
    - name: custom-init
      mountPath: /docker-entrypoint-initdb.d
  persistence:
    enabled: false
  extraFlags: "--require-secure-transport=ON --ssl-ca=/opt/bitnami/mysql/certs/ca.crt --ssl-cert=/opt/bitnami/mysql/certs/tls.crt --ssl-key=/opt/bitnami/mysql/certs/tls.key"
auth:
  database: teleport_db
  username: admin
  password: changeme
tls:
  enabled: true
  existingSecret: ${kubernetes_secret.mysql_tls.metadata[0].name}
  certFilename: tls.crt
  certKeyFilename: tls.key
  certCAFilename: ca.crt
EOF
  ]
}

# ---------------------------------------------------------------------------- #
# Teleport Role for MySQL
# ---------------------------------------------------------------------------- #
resource "kubectl_manifest" "teleport_role_mysql" {
  yaml_body = <<EOF
apiVersion: resources.teleport.dev/v1
kind: TeleportRoleV7
metadata:
  name: "${var.resource_prefix}mysql"
  namespace: ${helm_release.teleport_cluster.namespace}
spec:
  allow:
    db_labels:
      db: mysql
    db_names:
      - "teleport_db"
    db_users:
      - "developer"
EOF
}