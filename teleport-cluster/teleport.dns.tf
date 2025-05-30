# used for creating subdomain on existing zone. zone is defined by the variable domain_name
data "aws_route53_zone" "teleport_dns" {
  name = var.aws_domain_name
}

data "kubernetes_service" "teleport_cluster" {
  metadata {
    name      = helm_release.teleport_cluster.name
    namespace = helm_release.teleport_cluster.namespace
  }
}

# creates DNS record for teleport cluster on eks
resource "aws_route53_record" "cluster_endpoint" {
  zone_id = data.aws_route53_zone.teleport_dns.zone_id
  name    = var.teleport_subdomain
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

# creates wildcard record for teleport cluster on eks 
resource "aws_route53_record" "wild_cluster_endpoint" {
  zone_id = data.aws_route53_zone.teleport_dns.zone_id
  name    = "*.${var.teleport_subdomain}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

# resource "null_resource" "wait_for_cluster_endpoint" {
#   depends_on = [aws_route53_record.cluster_endpoint]

#   provisioner "local-exec" {
#     command = <<EOT
#     for i in {1..30}; do
#       nslookup ${aws_route53_record.cluster_endpoint.fqdn} && exit 0
#       echo "Waiting for DNS to propagate..."
#       sleep 5
#     done
#     echo "DNS did not propagate in time." >&2
#     exit 1
#     EOT
#   }
# }
