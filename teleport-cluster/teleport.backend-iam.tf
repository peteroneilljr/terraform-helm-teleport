resource "aws_iam_role" "irsa_role" {
  name = "${local.teleport_cluster_name}-eks-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com",
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}:${local.teleport_cluster_name}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_attach_dynamodb" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.teleport_cluster_dynamodb.arn
}

resource "aws_iam_policy" "teleport_cluster_dynamodb" {
  name = "${local.teleport_cluster_name}-dynamodb-backend"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllActionsOnTeleportBackendDB",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:DescribeStream",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:DescribeTable",
                "dynamodb:GetShardIterator",
                "dynamodb:GetItem",
                "dynamodb:ConditionCheckItem",
                "dynamodb:UpdateTable",
                "dynamodb:GetRecords",
                "dynamodb:UpdateContinuousBackups"
            ],
            "Resource": [
                "${aws_dynamodb_table.teleport_backend.arn}",
                "${aws_dynamodb_table.teleport_backend.arn}/*"
            ]
        },
        {
            "Sid": "AllActionsOnTeleportEventsDB",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:UpdateTable",
                "dynamodb:UpdateContinuousBackups"
            ],
            "Resource": [
              "${aws_dynamodb_table.teleport_events.arn}",
              "${aws_dynamodb_table.teleport_events.arn}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "irsa_attach_s3" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.teleport_cluster_s3.arn
}
resource "aws_iam_policy" "teleport_cluster_s3" {
  name = "${local.teleport_cluster_name}-s3-sessions"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": [
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketVersioning"
      ],
       "Resource": ["${aws_s3_bucket.teleport_sessions.arn}"]
     },
     {
       "Effect": "Allow",
       "Action": [
          "s3:GetObjectVersion",
          "s3:GetObjectRetention",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
       ],
       "Resource": ["${aws_s3_bucket.teleport_sessions.arn}/*"]
     }
   ]
 }

EOF

}


# ---------------------------------------------------------------------------- #
# route53
# ---------------------------------------------------------------------------- #
data "aws_route53_zone" "main" {
  name = var.aws_domain_name
}

resource "aws_iam_role_policy_attachment" "irsa_attach_route53" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.teleport_auth_route53.arn
}
resource "aws_iam_policy" "teleport_auth_route53" {
  name = "${local.teleport_cluster_name}-route53"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Id": "certbot-dns-route53 policy",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetChange"
            ],
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect" : "Allow",
            "Action" : [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource" : [
                "arn:aws:route53:::hostedzone/${data.aws_route53_zone.main.zone_id}"
            ]
        }
    ]
}
EOF

}
