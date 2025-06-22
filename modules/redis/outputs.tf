output "primary_endpoint" {
  description = "Primary endpoint of the Redis replication group"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}
