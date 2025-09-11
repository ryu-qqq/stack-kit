# Prometheus Enhanced Monitoring Addon Outputs
# Version: v1.0.0

# ECS Cluster Outputs
output "ecs_cluster_id" {
  description = "ID of the Prometheus ECS cluster"
  value       = aws_ecs_cluster.prometheus.id
}

output "ecs_cluster_arn" {
  description = "ARN of the Prometheus ECS cluster"
  value       = aws_ecs_cluster.prometheus.arn
}

output "ecs_cluster_name" {
  description = "Name of the Prometheus ECS cluster"
  value       = aws_ecs_cluster.prometheus.name
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.enable_alb ? aws_lb.prometheus[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = var.enable_alb ? aws_lb.prometheus[0].zone_id : null
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = var.enable_alb ? aws_lb.prometheus[0].arn : null
}

# Service Endpoints
output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value = var.enable_alb ? {
    internal_url = "http://${aws_lb.prometheus[0].dns_name}:9090"
    alb_url     = "http://${aws_lb.prometheus[0].dns_name}"
  } : {
    internal_url = "http://prometheus.${var.project_name}-${var.environment}-prometheus.local:9090"
    alb_url     = null
  }
}

output "grafana_endpoint" {
  description = "Grafana dashboard endpoint"
  value = var.enable_grafana ? (var.enable_alb ? {
    internal_url = "http://${aws_lb.prometheus[0].dns_name}:3000"
    alb_url     = "http://${aws_lb.prometheus[0].dns_name}:3000"
  } : {
    internal_url = "http://grafana.${var.project_name}-${var.environment}-prometheus.local:3000"
    alb_url     = null
  }) : null
}

output "alertmanager_endpoint" {
  description = "AlertManager endpoint"
  value = var.enable_alertmanager ? (var.enable_alb ? {
    internal_url = "http://${aws_lb.prometheus[0].dns_name}:9093"
    alb_url     = "http://${aws_lb.prometheus[0].dns_name}:9093"
  } : {
    internal_url = "http://alertmanager.${var.project_name}-${var.environment}-prometheus.local:9093"
    alb_url     = null
  }) : null
}

# Security Groups
output "prometheus_security_group_id" {
  description = "Security group ID for Prometheus services"
  value       = aws_security_group.prometheus.id
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = var.enable_alb ? aws_security_group.prometheus_alb[0].id : null
}

output "efs_security_group_id" {
  description = "Security group ID for EFS"
  value       = var.enable_persistent_storage ? aws_security_group.efs[0].id : null
}

# Storage Outputs
output "efs_file_system_id" {
  description = "EFS file system ID for persistent storage"
  value       = var.enable_persistent_storage ? aws_efs_file_system.prometheus[0].id : null
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = var.enable_persistent_storage ? aws_efs_file_system.prometheus[0].dns_name : null
}

output "s3_storage_bucket" {
  description = "S3 bucket for remote storage"
  value = var.enable_remote_storage ? {
    bucket = aws_s3_bucket.prometheus_storage[0].bucket
    arn    = aws_s3_bucket.prometheus_storage[0].arn
  } : null
}

# IAM Roles
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "prometheus_task_role_arn" {
  description = "ARN of the Prometheus task role"
  value       = aws_iam_role.prometheus_task.arn
}

# Log Groups
output "log_groups" {
  description = "CloudWatch log groups for monitoring services"
  value = {
    prometheus_cluster = aws_cloudwatch_log_group.prometheus_cluster.name
    prometheus        = aws_cloudwatch_log_group.prometheus.name
    grafana          = var.enable_grafana ? aws_cloudwatch_log_group.grafana[0].name : null
    alertmanager     = var.enable_alertmanager ? aws_cloudwatch_log_group.alertmanager[0].name : null
  }
}

# Service Discovery
output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value = var.enable_service_connect ? {
    id   = aws_service_discovery_private_dns_namespace.prometheus[0].id
    arn  = aws_service_discovery_private_dns_namespace.prometheus[0].arn
    name = aws_service_discovery_private_dns_namespace.prometheus[0].name
  } : null
}

# Target Groups
output "target_groups" {
  description = "ALB target groups for services"
  value = var.enable_alb ? {
    prometheus = {
      arn  = aws_lb_target_group.prometheus[0].arn
      name = aws_lb_target_group.prometheus[0].name
    }
    grafana = var.enable_grafana ? {
      arn  = aws_lb_target_group.grafana[0].arn
      name = aws_lb_target_group.grafana[0].name
    } : null
  } : null
}

# Configuration Parameters
output "configuration_parameters" {
  description = "SSM parameters storing service configurations"
  value = {
    prometheus_config   = aws_ssm_parameter.prometheus_config.name
    grafana_config     = var.enable_grafana ? aws_ssm_parameter.grafana_config[0].name : null
    alertmanager_config = var.enable_alertmanager ? aws_ssm_parameter.alertmanager_config[0].name : null
  }
}

# Environment Information
output "environment" {
  description = "Environment this monitoring stack is deployed in"
  value       = var.environment
}

output "region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Monitoring Summary
output "monitoring_summary" {
  description = "Summary of deployed monitoring components"
  value = {
    prometheus_enabled   = true
    grafana_enabled     = var.enable_grafana
    alertmanager_enabled = var.enable_alertmanager
    node_exporter_enabled = var.enable_node_exporter
    cadvisor_enabled    = var.enable_cadvisor
    persistent_storage  = var.enable_persistent_storage
    remote_storage     = var.enable_remote_storage
    high_availability  = var.enable_ha
    service_discovery  = var.enable_service_connect
    container_insights = var.enable_container_insights
    alb_enabled       = var.enable_alb
  }
}

# Capacity and Performance
output "capacity_configuration" {
  description = "Capacity and performance configuration"
  value = {
    prometheus = {
      cpu_units     = var.prometheus_cpu
      memory_mb     = var.prometheus_memory
      storage_size  = var.prometheus_storage_size
      retention     = var.prometheus_retention
    }
    grafana = var.enable_grafana ? {
      cpu_units = var.grafana_cpu
      memory_mb = var.grafana_memory
    } : null
    alertmanager = var.enable_alertmanager ? {
      cpu_units = var.alertmanager_cpu
      memory_mb = var.alertmanager_memory
    } : null
    efs_throughput = var.enable_persistent_storage ? var.efs_provisioned_throughput : null
  }
}

# Integration Information
output "integration_endpoints" {
  description = "Key endpoints and identifiers for integration with other modules"
  value = {
    prometheus_url      = var.enable_alb ? "http://${aws_lb.prometheus[0].dns_name}" : "http://prometheus.${var.project_name}-${var.environment}-prometheus.local:9090"
    grafana_url        = var.enable_grafana ? (var.enable_alb ? "http://${aws_lb.prometheus[0].dns_name}:3000" : "http://grafana.${var.project_name}-${var.environment}-prometheus.local:3000") : null
    alertmanager_url   = var.enable_alertmanager ? (var.enable_alb ? "http://${aws_lb.prometheus[0].dns_name}:9093" : "http://alertmanager.${var.project_name}-${var.environment}-prometheus.local:9093") : null
    cluster_name       = aws_ecs_cluster.prometheus.name
    service_namespace  = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.prometheus[0].name : null
    vpc_id            = var.vpc_id
    security_group_id = aws_security_group.prometheus.id
  }
}

# Security Configuration
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    encryption_enabled    = var.kms_key_id != null
    kms_key_id           = var.kms_key_id
    prometheus_public    = var.prometheus_public_access
    grafana_public       = var.grafana_public_access
    authentication_enabled = var.enable_authentication
    vpc_id               = var.vpc_id
    security_groups = {
      prometheus = aws_security_group.prometheus.id
      alb       = var.enable_alb ? aws_security_group.prometheus_alb[0].id : null
      efs       = var.enable_persistent_storage ? aws_security_group.efs[0].id : null
    }
  }
}

# Cost Optimization Features
output "cost_optimization_features" {
  description = "Cost optimization features enabled"
  value = {
    cost_optimization_enabled = var.enable_cost_optimization
    spot_instances           = var.spot_instances
    log_retention_days       = var.log_retention_days
    prometheus_retention     = var.prometheus_retention
    efs_provisioned         = var.enable_persistent_storage
    remote_storage          = var.enable_remote_storage
    environment_optimized   = lookup(var.environment_configs, var.environment, {}) != {}
  }
}

# Service Discovery Configuration
output "service_discovery_configuration" {
  description = "Service discovery configuration details"
  value = {
    ecs_service_discovery = var.enable_ecs_service_discovery
    ec2_service_discovery = var.enable_ec2_service_discovery
    custom_configs_count  = length(var.service_discovery_configs)
    monitoring_targets_count = length(var.monitoring_targets)
    custom_scrape_configs_count = length(var.custom_scrape_configs)
  }
}

# High Availability Configuration
output "ha_configuration" {
  description = "High availability configuration"
  value = var.enable_ha ? {
    enabled        = true
    replica_count  = var.ha_replica_count
    external_labels = var.ha_external_labels
  } : {
    enabled = false
  }
}

# Grafana Dashboard URLs
output "grafana_dashboards" {
  description = "Grafana dashboard access information"
  value = var.enable_grafana ? {
    base_url = var.enable_alb ? "http://${aws_lb.prometheus[0].dns_name}:3000" : "http://grafana.${var.project_name}-${var.environment}-prometheus.local:3000"
    dashboards = [
      {
        name = "Prometheus Stats"
        path = "/d/prometheus-stats/prometheus-stats"
      },
      {
        name = "Node Exporter"
        path = "/d/node-exporter/node-exporter"
      },
      {
        name = "Container Overview"
        path = "/d/container-overview/container-overview"
      }
    ]
  } : null
}

# Addon Metadata
output "addon_metadata" {
  description = "Metadata about this addon module"
  value = {
    name        = "prometheus-enhanced-monitoring"
    version     = "v1.0.0"
    provider    = "aws"
    category    = "monitoring"
    features    = [
      "prometheus-server",
      var.enable_grafana ? "grafana-dashboards" : null,
      var.enable_alertmanager ? "alertmanager" : null,
      "ecs-service-discovery",
      "auto-scaling-integration",
      var.enable_persistent_storage ? "persistent-storage" : null,
      var.enable_remote_storage ? "remote-storage" : null,
      var.enable_ha ? "high-availability" : null,
      "cost-optimization"
    ]
  }
}