# ElastiCache Redis/Memcached Module
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-cache-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cache-subnet-group"
  })
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  count = var.create_parameter_group ? 1 : 0

  family = var.parameter_group_family
  name   = "${var.project_name}-${var.environment}-cache-params"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cache-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ElastiCache
resource "aws_security_group" "elasticache" {
  name_prefix = "${var.project_name}-${var.environment}-cache-"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_groups
    content {
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Cache access from security group ${ingress.value}"
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Cache access from CIDR ${ingress.value}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ElastiCache SG needs outbound access
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cache-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Replication Group (Redis Cluster)
resource "aws_elasticache_replication_group" "redis" {
  count = var.engine == "redis" ? 1 : 0

  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  description                = "${var.project_name} ${var.environment} Redis cluster"
  
  # Engine Configuration
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  
  # Cluster Configuration
  num_cache_clusters = var.num_cache_nodes
  
  # Parameter Group
  parameter_group_name = var.create_parameter_group ? aws_elasticache_parameter_group.main[0].name : var.parameter_group_name
  
  # Network & Security
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]
  
  # Backup Configuration
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window         = var.snapshot_window
  maintenance_window      = var.maintenance_window
  
  # Advanced Settings
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token_enabled ? var.auth_token : null
  
  # Monitoring
  notification_topic_arn = var.notification_topic_arn
  
  # Automatic Failover (Multi-AZ)
  automatic_failover_enabled = var.num_cache_nodes > 1 ? var.automatic_failover_enabled : false
  multi_az_enabled          = var.num_cache_nodes > 1 ? var.multi_az_enabled : false

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })

  depends_on = [aws_elasticache_subnet_group.main]
}

# ElastiCache Cluster (Memcached)
resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id           = "${var.project_name}-${var.environment}-memcached"
  engine               = "memcached"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  port                 = var.port
  
  # Parameter Group
  parameter_group_name = var.create_parameter_group ? aws_elasticache_parameter_group.main[0].name : var.parameter_group_name
  
  # Network & Security
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]
  
  # Maintenance
  maintenance_window = var.maintenance_window
  
  # Monitoring
  notification_topic_arn = var.notification_topic_arn
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-memcached"
  })

  depends_on = [aws_elasticache_subnet_group.main]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-cache-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors elasticache cpu utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = var.engine == "redis" ? 
      aws_elasticache_replication_group.redis[0].id : 
      aws_elasticache_cluster.memcached[0].cluster_id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  count = var.create_cloudwatch_alarms && var.engine == "redis" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-cache-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "This metric monitors elasticache memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.redis[0].id
  }

  tags = var.common_tags
}