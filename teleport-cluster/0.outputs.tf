output "teleport_cluster_fqdn" {
  value       = local.teleport_cluster_fqdn
  description = "FQDN of the teleport cluster"
  sensitive   = false
}

output "teleport_db_backend_name" {
  value = aws_dynamodb_table.teleport_backend.name
}
output "teleport_db_events_name" {
  value = aws_dynamodb_table.teleport_events.name
}
output "teleport_s3_sessions_name" {
  value = aws_s3_bucket.teleport_sessions.bucket
}
