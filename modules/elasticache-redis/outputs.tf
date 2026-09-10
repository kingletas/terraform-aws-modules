output "id" {
  description = "Identifier of the replication group."
  value       = aws_elasticache_replication_group.this.id
}

output "arn" {
  description = "ARN of the replication group."
  value       = aws_elasticache_replication_group.this.arn
}

output "primary_endpoint_address" {
  description = "Write endpoint. Null in cluster mode, where the configuration endpoint is used instead."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Read endpoint, load balanced across replicas. Null in cluster mode."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Cluster-mode configuration endpoint, which a cluster-aware client discovers shards through."
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "port" {
  description = "Port the cache listens on."
  value       = aws_elasticache_replication_group.this.port
}

output "member_clusters" {
  description = "Cache cluster IDs making up this replication group."
  value       = aws_elasticache_replication_group.this.member_clusters
}
