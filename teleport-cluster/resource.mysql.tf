module "mysql_tls" {
  source             = "./module/db_tls"
  name               = "${var.resource_prefix}mysql-tls"
  namespace          = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  ca_common_name     = "Custom MySQL CA"
  dns_names = [
    "${var.resource_prefix}mysql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}",
    "${var.resource_prefix}mysql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}.svc.cluster.local"
  ]
  teleport_db_ca_pem = data.http.teleport_db_ca.response_body
}

moved {
  from = tls_private_key.mysql_ca_key
  to   = module.mysql_tls.tls_private_key.ca
}

moved {
  from = tls_self_signed_cert.mysql_ca_cert
  to   = module.mysql_tls.tls_self_signed_cert.ca
}

moved {
  from = tls_private_key.mysql_server_key
  to   = module.mysql_tls.tls_private_key.server
}

moved {
  from = tls_cert_request.mysql_server_csr
  to   = module.mysql_tls.tls_cert_request.server
}

moved {
  from = tls_locally_signed_cert.mysql_server_cert
  to   = module.mysql_tls.tls_locally_signed_cert.server
}

moved {
  from = kubernetes_secret.mysql_tls
  to   = module.mysql_tls.kubernetes_secret.this
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
  existingSecret: ${module.mysql_tls.secret_name}
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
