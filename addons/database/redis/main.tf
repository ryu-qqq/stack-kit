# Redis ElastiCache Addon v1.0.0
# Composable Redis ElastiCache module for stackkit

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data sources for shared infrastructure
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

# Local values for shared infrastructure references
locals {
  vpc_id              = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids  = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cache_subnet_ids    = try(data.terraform_remote_state.shared.outputs.cache_subnet_ids, local.private_subnet_ids)
  shared_security_group = try(data.terraform_remote_state.shared.outputs.cache_security_group_id, null)
  
  # Environment-specific configurations
  is_production = var.environment == "prod"
  
  # Redis configurations based on environment
  instance_config = {
    dev = {
      node_type               = "cache.t3.micro"
      num_cache_nodes         = 1
      num_cache_clusters      = null
      replicas_per_node_group = null
      automatic_failover      = false
      multi_az                = false
      cluster_mode           = false
    }
    staging = {
      node_type               = "cache.t3.small"
      num_cache_nodes         = 2
      num_cache_clusters      = 2
      replicas_per_node_group = 1
      automatic_failover      = true
      multi_az                = true
      cluster_mode           = true
    }
    prod = {
      node_type               = "cache.r6g.large"
      num_cache_nodes         = null
      num_cache_clusters      = 3
      replicas_per_node_group = 2
      automatic_failover      = true
      multi_az                = true
      cluster_mode           = true
    }
  }
  
  config = local.instance_config[var.environment]
  
  # Determine if cluster mode should be enabled
  cluster_mode_enabled = var.cluster_mode_enabled != null ? var.cluster_mode_enabled : local.config.cluster_mode
  
  # Tags
  common_tags = merge(var.common_tags, {
    Component   = "cache"
    Type        = "redis"
    Environment = var.environment
    Version     = "v1.0.0"
  })
}

# Cache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = local.cache_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-subnet-group"
  })
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  count = local.shared_security_group == null ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  vpc_id      = local.vpc_id
  
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Redis access from allowed networks"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  })
}

# Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.project_name}-${var.environment}-redis-params"

  dynamic "parameter" {
    for_each = var.custom_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  # Default production-ready parameters
  dynamic "parameter" {
    for_each = var.parameter_group_family == "redis7.x" ? [1] : []
    content {
      name  = "maxmemory-policy"
      value = var.maxmemory_policy
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-params"
  })
}

# KMS Key for encryption
resource "aws_kms_key" "redis" {
  count = var.create_kms_key ? 1 : 0
  
  description             = "KMS key for Redis encryption - ${var.project_name}-${var.environment}"
  deletion_window_in_days = var.kms_deletion_window
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-kms"
  })
}

resource "aws_kms_alias" "redis" {
  count = var.create_kms_key ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-redis"
  target_key_id = aws_kms_key.redis[0].key_id
}

# Random auth token
resource "random_password" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0
  
  length  = 32
  special = false
}

# Secrets Manager for auth token
resource "aws_secretsmanager_secret" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0
  
  name                    = "${var.project_name}-${var.environment}-redis-auth-token"
  description             = "Redis auth token for ${var.project_name}-${var.environment}"
  recovery_window_in_days = var.secret_recovery_window

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-auth-token"
  })
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0
  
  secret_id     = aws_secretsmanager_secret.auth_token[0].id
  secret_string = jsonencode({
    auth_token = random_password.auth_token[0].result
    endpoint   = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].configuration_endpoint_address : aws_elasticache_replication_group.main[0].primary_endpoint_address
    port       = 6379
  })
}

# Redis Replication Group (Standard Mode)
resource "aws_elasticache_replication_group" "main" {
  count = !local.cluster_mode_enabled ? 1 : 0
  
  replication_group_id         = "${var.project_name}-${var.environment}-redis"
  description                  = "Redis replication group for ${var.project_name}-${var.environment}"
  
  # Node configuration
  node_type = var.node_type != "" ? var.node_type : local.config.node_type
  port      = 6379
  
  # Replication configuration
  num_cache_clusters         = var.num_cache_nodes != null ? var.num_cache_nodes : local.config.num_cache_nodes
  automatic_failover_enabled = var.automatic_failover_enabled != null ? var.automatic_failover_enabled : local.config.automatic_failover
  multi_az_enabled          = var.multi_az_enabled != null ? var.multi_az_enabled : local.config.multi_az
  
  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [local.shared_security_group != null ? local.shared_security_group : aws_security_group.redis[0].id]
  
  # Engine configuration
  engine               = "redis"
  engine_version       = var.engine_version
  parameter_group_name = aws_elasticache_parameter_group.main.name
  
  # Security
  at_rest_encryption_enabled = var.encryption_at_rest_enabled
  transit_encryption_enabled = var.encryption_in_transit_enabled
  auth_token                 = var.auth_token_enabled ? random_password.auth_token[0].result : null
  kms_key_id                = var.encryption_at_rest_enabled && var.create_kms_key ? aws_kms_key.redis[0].arn : var.kms_key_id
  
  # Backup configuration
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window         = var.snapshot_window
  
  # Maintenance
  maintenance_window = var.maintenance_window
  
  # Notifications
  notification_topic_arn = var.notification_topic_arn
  
  # Log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
  
  depends_on = [aws_elasticache_subnet_group.main]
}

# Redis Replication Group (Cluster Mode)
resource "aws_elasticache_replication_group" "cluster" {
  count = local.cluster_mode_enabled ? 1 : 0
  
  replication_group_id         = "${var.project_name}-${var.environment}-redis-cluster"
  description                  = "Redis cluster for ${var.project_name}-${var.environment}"
  
  # Node configuration
  node_type = var.node_type != "" ? var.node_type : local.config.node_type
  port      = 6379
  
  # Cluster configuration
  num_node_groups         = var.num_node_groups != null ? var.num_node_groups : local.config.num_cache_clusters
  replicas_per_node_group = var.replicas_per_node_group != null ? var.replicas_per_node_group : local.config.replicas_per_node_group
  
  # High availability
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [local.shared_security_group != null ? local.shared_security_group : aws_security_group.redis[0].id]
  
  # Engine configuration
  engine               = "redis"
  engine_version       = var.engine_version
  parameter_group_name = aws_elasticache_parameter_group.main.name
  
  # Security
  at_rest_encryption_enabled = var.encryption_at_rest_enabled
  transit_encryption_enabled = var.encryption_in_transit_enabled
  auth_token                 = var.auth_token_enabled ? random_password.auth_token[0].result : null
  kms_key_id                = var.encryption_at_rest_enabled && var.create_kms_key ? aws_kms_key.redis[0].arn : var.kms_key_id
  
  # Backup configuration
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window         = var.snapshot_window
  
  # Maintenance
  maintenance_window = var.maintenance_window
  
  # Notifications
  notification_topic_arn = var.notification_topic_arn
  
  # Log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-cluster"
  })
  
  depends_on = [aws_elasticache_subnet_group.main]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = local.cluster_mode_enabled ? "${aws_elasticache_replication_group.cluster[0].replication_group_id}-001" : "${aws_elasticache_replication_group.main[0].replication_group_id}-001"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = local.cluster_mode_enabled ? "${aws_elasticache_replication_group.cluster[0].replication_group_id}-001" : "${aws_elasticache_replication_group.main[0].replication_group_id}-001"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "connection_count" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-redis-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connection_alarm_threshold
  alarm_description   = "This metric monitors Redis connection count"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = local.cluster_mode_enabled ? "${aws_elasticache_replication_group.cluster[0].replication_group_id}-001" : "${aws_elasticache_replication_group.main[0].replication_group_id}-001"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "evictions" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.eviction_alarm_threshold
  alarm_description   = "This metric monitors Redis evictions"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = local.cluster_mode_enabled ? "${aws_elasticache_replication_group.cluster[0].replication_group_id}-001" : "${aws_elasticache_replication_group.main[0].replication_group_id}-001"
  }

  tags = local.common_tags
}