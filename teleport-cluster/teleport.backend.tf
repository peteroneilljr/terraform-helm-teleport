// DynamoDB table for storing cluster state
resource "aws_dynamodb_table" "teleport_backend" {
  name           = "${local.teleport_cluster_name}-backend"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "HashKey"
  range_key      = "FullPath"

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "HashKey"
    type = "S"
  }

  attribute {
    name = "FullPath"
    type = "S"
  }

  stream_enabled   = "true"
  stream_view_type = "NEW_IMAGE"

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = {
    TeleportCluster = local.teleport_cluster_name
  }

  # Prevents Terraform from destroying backend on name change
  lifecycle {
    ignore_changes = all
  }
}

// DynamoDB table for storing cluster events
resource "aws_dynamodb_table" "teleport_events" {
  name           = "${local.teleport_cluster_name}-events"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "SessionID"
  range_key      = "EventIndex"

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  global_secondary_index {
    name            = "timesearchV2"
    hash_key        = "CreatedAtDate"
    range_key       = "CreatedAt"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  attribute {
    name = "SessionID"
    type = "S"
  }

  attribute {
    name = "EventIndex"
    type = "N"
  }

  attribute {
    name = "CreatedAtDate"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = {
    TeleportCluster = local.teleport_cluster_name
  }

  # Prevents Terraform from destroying backend on name change
  lifecycle {
    ignore_changes = all
  }
}

resource "aws_s3_bucket" "teleport_sessions" {
  bucket        = "${local.teleport_cluster_name}-sessions"
  force_destroy = true

  # Prevents Terraform from destroying backend on name change
  lifecycle {
    ignore_changes = all
  }
}

resource "aws_s3_bucket_acl" "teleport_sessions" {
  depends_on = [aws_s3_bucket_ownership_controls.teleport_sessions]
  bucket     = aws_s3_bucket.teleport_sessions.bucket
  acl        = "private"
}

resource "aws_s3_bucket_ownership_controls" "teleport_sessions" {
  bucket = aws_s3_bucket.teleport_sessions.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "teleport_sessions" {
  bucket = aws_s3_bucket.teleport_sessions.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "teleport_sessions" {
  bucket = aws_s3_bucket.teleport_sessions.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "teleport_sessions" {
  bucket = aws_s3_bucket.teleport_sessions.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}