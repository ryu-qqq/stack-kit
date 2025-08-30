output "redis_replication_group_id" {
  description = "Redis Replication Group ID"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].id : null
}

output "redis_primary_endpoint" {
  description = "Redis Primary Endpoint"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
}

output "redis_reader_endpoint" {
  description = "Redis Reader Endpoint"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
}

output "redis_configuration_endpoint" {
  description = "Redis Configuration Endpoint"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].configuration_endpoint_address : null
}

output "memcached_cluster_id" {
  description = "Memcached Cluster ID"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_id : null
}

output "memcached_configuration_endpoint" {
  description = "Memcached Configuration Endpoint"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].configuration_endpoint : null
}

output "memcached_cluster_address" {
  description = "Memcached Cluster Address"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_address : null
}

output "cache_nodes" {
  description = "캐시 노드 정보"
  value = var.engine == "redis" ? 
    aws_elasticache_replication_group.redis[0].cache_nodes : 
    aws_elasticache_cluster.memcached[0].cache_nodes
}

output "port" {
  description = "캐시 포트"
  value       = var.port
}

output "engine" {
  description = "캐시 엔진"
  value       = var.engine
}

output "engine_version" {
  description = "엔진 버전"
  value       = var.engine_version
}

output "subnet_group_name" {
  description = "서브넷 그룹 이름"
  value       = aws_elasticache_subnet_group.main.name
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.elasticache.id
}

output "security_group_arn" {
  description = "Security Group ARN"
  value       = aws_security_group.elasticache.arn
}

output "parameter_group_id" {
  description = "Parameter Group ID"
  value       = var.create_parameter_group ? aws_elasticache_parameter_group.main[0].id : null
}

output "redis_auth_token_enabled" {
  description = "Redis AUTH 토큰 활성화 여부"
  value       = var.engine == "redis" ? var.auth_token_enabled : null
}

output "encryption_at_rest_enabled" {
  description = "저장 시 암호화 활성화 여부"
  value       = var.engine == "redis" ? var.at_rest_encryption_enabled : null
}

output "encryption_in_transit_enabled" {
  description = "전송 시 암호화 활성화 여부"
  value       = var.engine == "redis" ? var.transit_encryption_enabled : null
}