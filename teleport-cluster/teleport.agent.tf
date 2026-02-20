resource "random_string" "teleport_agent" {
  length  = 32
  special = false
  upper   = false
  lower   = true
}

resource "kubectl_manifest" "teleport_agent" {
  yaml_body = yamlencode(
    {
      apiVersion = "resources.teleport.dev/v2"
      kind       = "TeleportProvisionToken"

      metadata = {
        name      = random_string.teleport_agent.result
        namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
      }

      spec = {
        roles       = ["App", "Db"]
        join_method = "token"

      }
    }
  )

  depends_on = [
    helm_release.teleport_cluster
  ]
}

locals {
  teleport_agent_name = "${var.resource_prefix}teleport-agent"
}


resource "helm_release" "teleport_agent" {
  name       = local.teleport_agent_name
  namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-kube-agent"
  version    = var.teleport_version

  set = [
    {
      name  = "authToken"
      value = random_string.teleport_agent.result
    }
  ]

  wait = false

  values = [<<EOF
roles: app,db
proxyAddr: ${local.teleport_cluster_fqdn}:443
enterprise: true
annotations:
  serviceAccount:
    "eks.amazonaws.com/role-arn": "${aws_iam_role.irsa_aws_console.arn}"
highAvailability:
    replicaCount: 2
    podDisruptionBudget:
        enabled: true
        minAvailable: 1 
extraVolumes:
- name: postgres-ca
  secret:
    secretName: ${kubernetes_secret.postgres_tls.metadata[0].name}
- name: mysql-ca
  secret:
    secretName: ${kubernetes_secret.mysql_tls.metadata[0].name}
extraVolumeMounts:
- name: postgres-ca
  mountPath: /var/lib/postgresql/tls
- name: mysql-ca
  mountPath: /var/lib/mysql/tls
apps:
  - name: grafana
    public_addr: "grafana.${local.teleport_cluster_fqdn}"
    uri: http://${helm_release.grafana.name}.${helm_release.grafana.namespace}.svc.cluster.local
    labels:
      env: dev
      host: k8s
  - name: argocd
    uri: https://argocd-server.argocd.svc.cluster.local
    insecure_skip_verify: true
    labels:
      env: dev
      host: k8s
      app: argocd
  - name: awsconsole
    uri: "https://console.aws.amazon.com/"
    labels:
      env: dev
      host: k8s
      app: aws
  - name: awsconsole-bedrock
    uri: "https://console.aws.amazon.com/bedrock"
    labels:
      app: bedrock

databases:
  - name: postgres
    uri: ${helm_release.postgresql.name}-postgresql.${helm_release.postgresql.namespace}.svc.cluster.local:5432
    protocol: postgres
    admin_user:
      name: teleport-admin
    static_labels:
      env: dev
      host: k8s
      db: postgres
    tls:
      ca_cert_file: /var/lib/postgresql/tls/ca.crt
  - name: mysql
    uri: ${helm_release.mysql.name}.${helm_release.mysql.namespace}.svc.cluster.local:3306
    protocol: mysql
    static_labels:
      env: dev
      host: k8s
      db: mysql
    tls:
      ca_cert_file: /var/lib/mysql/tls/ca.crt
EOF
  ]
}
