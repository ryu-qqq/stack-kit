# Prometheus Enhanced Monitoring Addon

Version: **v1.0.0**

## Overview

The Prometheus Enhanced Monitoring Addon provides a complete Prometheus-based monitoring solution deployed on AWS ECS with Grafana dashboards and AlertManager integration. This addon offers enterprise-grade monitoring with service discovery, high availability, persistent storage, and comprehensive AWS integration.

## Features

### 🚀 Container-Native Deployment
- **ECS Fargate deployment** with auto-scaling and service discovery
- **Container Insights** integration for comprehensive container monitoring
- **Service Connect** for seamless service-to-service communication
- **Load balancer integration** with health checks and SSL termination
- **Multi-AZ deployment** for high availability

### 📊 Comprehensive Monitoring Stack
- **Prometheus server** with advanced configuration and service discovery
- **Grafana dashboards** with pre-built visualizations and custom dashboards
- **AlertManager** with multi-channel notifications and routing
- **Node Exporter** for host-level metrics collection
- **cAdvisor** for container metrics and resource monitoring

### 🔍 Service Discovery & Auto-Configuration
- **ECS service discovery** for automatic target detection
- **EC2 service discovery** for instance-based applications
- **Static configuration** for external services and endpoints
- **Dynamic reconfiguration** without service restarts
- **Custom scrape configurations** for specialized monitoring needs

### 💾 Persistent & Remote Storage
- **EFS persistent storage** for Prometheus data durability
- **S3 remote storage** for long-term metrics retention
- **Configurable retention policies** based on environment
- **Automatic backup** and disaster recovery capabilities
- **Cost-optimized storage** with intelligent tiering

### 🔐 Security & Authentication
- **VPC-based deployment** with security group isolation
- **IAM integration** with least-privilege access policies
- **KMS encryption** for data at rest and in transit
- **OAuth integration** for dashboard authentication
- **Network-level access controls** and traffic filtering

## Quick Start

### Basic Prometheus Setup

```hcl
module "prometheus_monitoring" {
  source = "./addons/monitoring/prometheus"

  project_name = "myapp"
  environment  = "prod"
  vpc_id       = "vpc-12345678"

  # Enable core components
  enable_grafana      = true
  enable_alertmanager = true
  enable_alb         = true

  # Basic configuration
  prometheus_cpu    = 1024
  prometheus_memory = 2048
  grafana_cpu      = 512
  grafana_memory   = 1024

  # Storage configuration
  enable_persistent_storage = true
  prometheus_retention     = "30d"
  efs_provisioned_throughput = 100

  # Monitoring targets
  monitoring_targets = {
    web_servers = {
      targets = ["10.0.1.10:9100", "10.0.1.11:9100"]
      labels = {
        job = "web-servers"
        env = "prod"
      }
    }
  }

  common_tags = {
    Project = "MyApp"
    Team    = "Platform"
  }
}
```

### Advanced Monitoring with Service Discovery

```hcl
module "enterprise_prometheus" {
  source = "./addons/monitoring/prometheus"

  project_name = "enterprise-app"
  environment  = "prod"
  vpc_id       = "vpc-12345678"

  # High availability configuration
  enable_ha        = true
  ha_replica_count = 3
  ha_external_labels = {
    cluster = "prod-east"
    region  = "us-east-1"
  }

  # Enhanced security
  kms_key_id           = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  enable_authentication = true
  prometheus_public_access = false
  grafana_public_access   = true

  # Service discovery configuration
  enable_ecs_service_discovery = true
  enable_ec2_service_discovery = true
  
  custom_scrape_configs = [
    {
      job_name = "kubernetes-pods"
      ecs_sd_configs = [
        {
          cluster = "enterprise-app-cluster"
          region  = "us-east-1"
        }
      ]
      relabel_configs = [
        {
          source_labels = ["__meta_ecs_task_definition_family"]
          target_label  = "job"
        },
        {
          source_labels = ["__meta_ecs_container_name"]
          target_label  = "container"
        }
      ]
    },
    {
      job_name = "blackbox-monitoring"
      static_configs = [
        {
          targets = [
            "https://api.enterprise.com/health",
            "https://web.enterprise.com/health"
          ]
        }
      ]
      metrics_path = "/probe"
      relabel_configs = [
        {
          source_labels = ["__address__"]
          target_label  = "__param_target"
        },
        {
          source_labels = ["__param_target"]
          target_label  = "instance"
        }
      ]
    }
  ]

  # Storage and retention
  enable_persistent_storage = true
  enable_remote_storage    = true
  prometheus_retention     = "90d"
  prometheus_storage_size  = "100Gi"

  # AlertManager configuration
  alertmanager_config = {
    global = {
      smtp_smarthost = "smtp.enterprise.com:587"
      smtp_from      = "alerts@enterprise.com"
    }
    route = {
      group_by        = ["alertname", "cluster", "service"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "12h"
      receiver        = "default"
    }
    receivers = [
      {
        name = "default"
        email_configs = [
          {
            to      = "oncall@enterprise.com"
            subject = "{{ .GroupLabels.alertname }} - {{ .Status }}"
          }
        ]
        slack_configs = [
          {
            api_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
            channel = "#alerts"
            title   = "{{ .GroupLabels.alertname }}"
          }
        ]
      },
      {
        name = "critical"
        email_configs = [
          {
            to      = "critical@enterprise.com"
            subject = "CRITICAL: {{ .GroupLabels.alertname }}"
          }
        ]
      }
    ]
  }

  # Alert rules
  alert_rules = [
    {
      name = "application.rules"
      rules = [
        {
          alert = "HighErrorRate"
          expr  = "rate(http_requests_total{status=~\"5..\"}[5m]) > 0.1"
          for   = "10m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "High error rate detected"
            description = "Error rate is {{ $value }} errors per second"
          }
        },
        {
          alert = "ServiceDown"
          expr  = "up == 0"
          for   = "5m"
          labels = {
            severity = "critical"
          }
          annotations = {
            summary     = "Service is down"
            description = "{{ $labels.instance }} has been down for more than 5 minutes"
          }
        }
      ]
    }
  ]

  # Grafana configuration
  grafana_config = {
    admin_user     = "admin"
    admin_password = "secure_password_here"
    datasources = [
      {
        name      = "Prometheus"
        type      = "prometheus"
        url       = "http://prometheus:9090"
        isDefault = true
      },
      {
        name = "CloudWatch"
        type = "cloudwatch"
        url  = "cloudwatch"
      }
    ]
    plugins = [
      "grafana-piechart-panel",
      "grafana-worldmap-panel",
      "grafana-clock-panel"
    ]
  }

  # Cost optimization
  enable_cost_optimization = true
  spot_instances          = false  # Use reserved instances for prod

  common_tags = {
    Project     = "EnterpriseApp"
    Environment = "Production"
    CostCenter  = "Platform"
    Compliance  = "SOX"
  }
}
```

### Development Environment Setup

```hcl
module "dev_prometheus" {
  source = "./addons/monitoring/prometheus"

  project_name = "myapp"
  environment  = "dev"
  vpc_id       = "vpc-dev12345"

  # Lightweight configuration for development
  prometheus_cpu    = 512
  prometheus_memory = 1024
  grafana_cpu      = 256
  grafana_memory   = 512

  # Cost optimization for dev
  enable_persistent_storage = false
  prometheus_retention     = "7d"
  log_retention_days      = 7
  spot_instances         = true

  # Public access for easy development
  prometheus_public_access = true
  grafana_public_access   = true

  # Basic monitoring
  enable_alertmanager = false
  enable_ha          = false

  common_tags = {
    Project     = "MyApp"
    Environment = "Development"
  }
}
```

## Environment-Specific Configurations

The addon automatically applies environment-specific defaults:

### Development
- Lightweight resource allocation
- Short retention periods
- Public access enabled
- Spot instances for cost savings
- No high availability

### Staging
- Moderate resource allocation
- Medium retention periods
- Production-like configuration
- Basic high availability

### Production
- Full resource allocation
- Extended retention periods
- High availability enabled
- Enhanced security
- Compliance features

## Integration Examples

### ECS Service Monitoring
```hcl
# Monitor ECS services automatically
custom_scrape_configs = [
  {
    job_name = "ecs-services"
    ecs_sd_configs = [
      {
        cluster = "my-ecs-cluster"
        region  = "us-east-1"
      }
    ]
    relabel_configs = [
      {
        source_labels = ["__meta_ecs_task_definition_family"]
        target_label  = "service"
      }
    ]
  }
]
```

### Application Load Balancer Monitoring
```hcl
# Monitor ALB metrics via CloudWatch
cloudwatch_metrics = [
  {
    namespace = "AWS/ApplicationELB"
    metric    = "TargetResponseTime"
    dimensions = {
      LoadBalancer = "app/my-alb/1234567890123456"
    }
  }
]
```

### Database Monitoring
```hcl
# Monitor RDS instances
monitoring_targets = {
  databases = {
    targets = ["rds-exporter:9042"]
    labels = {
      job = "rds"
      env = "prod"
    }
  }
}
```

## Dashboard Examples

### System Overview Dashboard
```json
{
  "dashboard": {
    "title": "System Overview",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"
          }
        ]
      }
    ]
  }
}
```

## Alert Rule Examples

### Application Health Alerts
```yaml
groups:
  - name: application.rules
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | yes |
| `environment` | Environment name | `string` | - | yes |
| `vpc_id` | VPC ID for deployment | `string` | - | yes |
| `enable_grafana` | Enable Grafana deployment | `bool` | `true` | no |
| `enable_alertmanager` | Enable AlertManager | `bool` | `true` | no |
| `prometheus_retention` | Data retention period | `string` | `"30d"` | no |

[See variables.tf for complete list]

## Outputs

| Name | Description |
|------|-------------|
| `prometheus_endpoint` | Prometheus server endpoint |
| `grafana_endpoint` | Grafana dashboard endpoint |
| `alb_dns_name` | Load balancer DNS name |
| `ecs_cluster_name` | ECS cluster name |

[See outputs.tf for complete list]

## Best Practices

### 🔐 Security
1. **Use VPC deployment** with private subnets
2. **Enable KMS encryption** for data at rest
3. **Implement authentication** for production environments
4. **Use least-privilege IAM** policies
5. **Regular security audits** and updates

### 💰 Cost Optimization
1. **Right-size resources** based on workload
2. **Use appropriate retention** policies
3. **Enable spot instances** for non-production
4. **Monitor storage costs** regularly
5. **Implement data lifecycle** policies

### 📊 Monitoring Strategy
1. **Start with basic metrics** and expand gradually
2. **Use service discovery** for automatic target detection
3. **Implement proper alerting** thresholds
4. **Create meaningful dashboards** for different audiences
5. **Regular review and optimization**

### 🚀 Performance
1. **Monitor Prometheus performance** itself
2. **Use recording rules** for expensive queries
3. **Implement proper retention** policies
4. **Scale horizontally** with federation
5. **Optimize query patterns**

## Troubleshooting

### Common Issues

**High Memory Usage**
- Review retention policies and storage configuration
- Check for high cardinality metrics
- Optimize query patterns and recording rules

**Service Discovery Not Working**
- Verify IAM permissions for service discovery
- Check security group configurations
- Validate target health and connectivity

**Dashboard Loading Issues**
- Check Grafana logs for errors
- Verify data source configurations
- Validate query syntax and performance

## Version History

### v1.0.0
- Initial release with ECS-based deployment
- Grafana integration with pre-built dashboards
- AlertManager with multi-channel notifications
- Service discovery for ECS and EC2
- High availability and persistent storage options
- Cost optimization features

## Support

For issues, feature requests, or questions:
1. Check existing documentation and examples
2. Review Prometheus and Grafana documentation
3. Consult AWS ECS best practices
4. Create issues in the project repository

## License

This addon is part of the StackKit Terraform framework and follows the same licensing terms.