data "aws_eks_cluster" "cluster" {
  name = var.aws_eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.aws_eks_cluster_name
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_region" "current" {}
