# CloudWatch Enhanced Monitoring Addon

Version: **v1.0.0**

## Overview

The CloudWatch Enhanced Monitoring Addon provides comprehensive observability and monitoring capabilities for AWS environments. This addon extends basic CloudWatch functionality with advanced features including intelligent alerting, anomaly detection, custom dashboards, synthetics monitoring, and distributed tracing integration.

## Features

### 📊 Comprehensive Monitoring
- **Enhanced log management** with encrypted storage and intelligent retention
- **Advanced metric alarms** with composite conditions and anomaly detection
- **Custom dashboards** with rich visualizations and real-time insights
- **Synthetics monitoring** for endpoint availability and performance
- **Container Insights** for ECS/EKS workload monitoring

### 🔔 Intelligent Alerting
- **Multi-channel notifications** with SNS integration and filtering
- **Severity-based alerting** with environment-specific thresholds
- **Composite alarms** for complex condition monitoring
- **Anomaly detection** with machine learning-based alerting
- **Event-driven monitoring** with EventBridge integration

### 🎯 Application Performance Monitoring
- **Custom application metrics** from log patterns
- **Distributed tracing** with X-Ray integration
- **Auto-scaling integration** with CloudWatch metrics
- **Database and cache monitoring** integration ready
- **Cost optimization** through intelligent data retention

### 🏗️ DevOps Integration
- **CI/CD pipeline monitoring** with build and deployment metrics
- **Infrastructure monitoring** with AWS service integration
- **Log aggregation** and analysis with CloudWatch Insights
- **Performance baselines** and trend analysis
- **Compliance reporting** and audit trail monitoring

## Quick Start

### Basic Application Monitoring

```hcl
module "app_monitoring" {
  source = "./addons/monitoring/cloudwatch"

  project_name = "myapp"
  environment  = "prod"
  monitoring_level = "enhanced"

  # Application log groups
  log_groups = {
    application = {
      name              = "/aws/lambda/myapp-api"
      retention_in_days = 30
      purpose           = "application"
    }
    access = {
      name              = "/aws/applicationloadbalancer/myapp"
      retention_in_days = 90
      purpose           = "access"
    }
  }

  # Basic application metrics
  metric_alarms = {
    high_error_rate = {
      alarm_name          = "myapp-high-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      threshold          = 5
      alarm_description  = "High error rate detected"
      metric_name        = "Errors"
      namespace          = "AWS/Lambda"
      period             = 300
      statistic          = "Sum"
      dimensions = {
        FunctionName = "myapp-api"
      }
      alarm_actions = [module.app_monitoring.sns_topic_arns[0]]
      severity      = "high"
    }
  }

  # Alert channels
  alert_channels = {
    critical = {
      subscriptions = {
        email = {
          protocol = "email"
          endpoint = "alerts@mycompany.com"
        }
        slack = {
          protocol = "https"
          endpoint = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
        }
      }
    }
  }

  common_tags = {
    Project = "MyApp"
    Team    = "Platform"
  }
}
```

### Advanced Monitoring with Anomaly Detection

```hcl
module "advanced_monitoring" {
  source = "./addons/monitoring/cloudwatch"

  project_name = "enterprise-app"
  environment  = "prod"
  monitoring_level = "comprehensive"

  # Enhanced log management
  log_groups = {
    application = {
      name              = "/enterprise-app/application"
      retention_in_days = 365
      kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      purpose           = "application"
    }
    audit = {
      name              = "/enterprise-app/audit"
      retention_in_days = 2555  # 7 years for compliance
      kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      purpose           = "audit"
      skip_destroy      = true
    }
  }

  # Custom application metrics from logs
  custom_application_metrics = {
    login_failures = {
      name           = "login-failure-metric"
      log_group_name = "/enterprise-app/application"
      pattern        = "[timestamp, request_id, level=\"ERROR\", message=\"Login failed\", ...]"
      metric_name    = "LoginFailures"
      namespace      = "EnterpriseApp/Security"
      value          = "1"
      unit           = "Count"
    }
    response_time = {
      name           = "response-time-metric"
      log_group_name = "/enterprise-app/application"
      pattern        = "[timestamp, request_id, level, message=\"Request completed\", duration]"
      metric_name    = "ResponseTime"
      namespace      = "EnterpriseApp/Performance"
      value          = "$duration"
      unit           = "Milliseconds"
    }
  }

  # Anomaly detection for key metrics
  anomaly_detectors = {
    response_time = {
      metric_name = "ResponseTime"
      namespace   = "EnterpriseApp/Performance"
      stat        = "Average"
    }
    request_count = {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      stat        = "Sum"
      dimensions = {
        LoadBalancer = "app/enterprise-app-alb/50dc6c495c0c9188"
      }
    }
  }

  # Anomaly-based alarms
  anomaly_alarms = {
    response_time_anomaly = {
      alarm_name         = "enterprise-app-response-time-anomaly"
      evaluation_periods = 2
      alarm_description  = "Response time anomaly detected"
      metric_name        = "ResponseTime"
      namespace          = "EnterpriseApp/Performance"
      period            = 300
      stat              = "Average"
      alarm_actions     = [module.advanced_monitoring.sns_topic_arns[0]]
    }
  }

  # Composite alarms for complex conditions
  composite_alarms = {
    application_health = {
      alarm_name        = "enterprise-app-health-check"
      alarm_description = "Overall application health status"
      alarm_rule        = "ALARM(enterprise-app-high-error-rate) OR ALARM(enterprise-app-response-time-anomaly) OR ALARM(enterprise-app-db-connection-failures)"
      alarm_actions     = [module.advanced_monitoring.sns_topic_arns[0]]
    }
  }

  # Enhanced alert channels with filtering
  alert_channels = {
    critical = {
      subscriptions = {
        oncall = {
          protocol = "email"
          endpoint = "oncall@enterprise.com"
          filter_policy = jsonencode({
            severity = ["critical", "high"]
          })
        }
        pagerduty = {
          protocol = "https"
          endpoint = "https://events.pagerduty.com/integration/YOUR_KEY/enqueue"
          filter_policy = jsonencode({
            severity = ["critical"]
          })
        }
      }
    }
    monitoring = {
      subscriptions = {
        monitoring_team = {
          protocol = "email"
          endpoint = "monitoring@enterprise.com"
        }
      }
    }
  }

  # Auto-scaling integration
  autoscaling_policies = {
    scale_up = {
      name               = "enterprise-app-scale-up"
      policy_type        = "TargetTrackingScaling"
      resource_id        = "service/enterprise-app-cluster/enterprise-app-service"
      scalable_dimension = "ecs:service:DesiredCount"
      service_namespace  = "ecs"
      target_tracking_config = {
        target_value           = 70.0
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
        scale_out_cooldown     = 300
        scale_in_cooldown      = 300
      }
    }
  }

  # Synthetics monitoring for critical endpoints
  synthetics_canaries = {
    api_health = {
      name                 = "enterprise-app-api-health"
      artifact_s3_location = "s3://enterprise-app-synthetics-artifacts/"
      execution_role_arn   = "arn:aws:iam::123456789012:role/CloudWatchSyntheticsRole"
      handler             = "apiCanaryBlueprint.handler"
      zip_file            = "api-canary.zip"
      runtime_version     = "syn-nodejs-puppeteer-3.8"
      schedule_expression = "rate(5 minutes)"
      run_config = {
        timeout_in_seconds = 60
        memory_in_mb      = 960
        active_tracing    = true
      }
    }
  }

  # CloudWatch Insights queries for troubleshooting
  insights_queries = {
    error_analysis = {
      name = "Error Analysis"
      log_group_names = ["/enterprise-app/application"]
      query_string = <<-EOT
        fields @timestamp, level, message, request_id
        | filter level = "ERROR"
        | stats count() by bin(5m)
        | sort @timestamp desc
      EOT
    }
    performance_analysis = {
      name = "Performance Analysis"
      log_group_names = ["/enterprise-app/application"]
      query_string = <<-EOT
        fields @timestamp, duration, endpoint
        | filter duration > 1000
        | stats avg(duration), max(duration), count() by endpoint
        | sort avg desc
      EOT
    }
  }

  common_tags = {
    Project     = "EnterpriseApp"
    Environment = "Production"
    Compliance  = "SOX"
    CostCenter  = "Engineering"
  }
}
```

### Multi-Environment Dashboard Setup

```hcl
module "monitoring_dashboard" {
  source = "./addons/monitoring/cloudwatch"

  project_name = "myapp"
  environment  = "prod"

  # Comprehensive dashboard
  dashboards = {
    application_overview = {
      dashboard_name = "MyApp-Production-Overview"
      widgets = [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Lambda", "Duration", "FunctionName", "myapp-api"],
              ["AWS/Lambda", "Errors", "FunctionName", "myapp-api"],
              ["AWS/Lambda", "Invocations", "FunctionName", "myapp-api"]
            ]
            period = 300
            stat   = "Average"
            region = "us-east-1"
            title  = "Lambda Performance Metrics"
          }
        },
        {
          type   = "log"
          x      = 0
          y      = 6
          width  = 24
          height = 6
          properties = {
            query   = "SOURCE '/aws/lambda/myapp-api' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
            region  = "us-east-1"
            title   = "Recent Errors"
          }
        }
      ]
    }
  }
}
```

## Environment-Specific Configurations

### Development Environment
```hcl
monitoring_level = "basic"
log_retention_policies = {
  application_logs = 7
  access_logs      = 14
  error_logs       = 30
  audit_logs       = 90
  debug_logs       = 3
}
```

### Production Environment
```hcl
monitoring_level = "comprehensive"
log_retention_policies = {
  application_logs = 90
  access_logs      = 365
  error_logs       = 365
  audit_logs       = 2555  # 7 years
  debug_logs       = 14
}
```

## Integration Examples

### S3 Integration
```hcl
# Monitor S3 bucket access and errors
metric_filters = {
  s3_access_denied = {
    name           = "s3-access-denied"
    log_group_name = "/aws/s3/access-logs"
    pattern        = "[time, bucket, requestor, object, operation=\"REST.*.DENIED\", ...]"
    metric_name    = "S3AccessDenied"
    namespace      = "MyApp/Security"
    value          = "1"
  }
}
```

### ECS Integration
```hcl
# Container insights and service monitoring
enable_container_insights = true
container_insights_clusters = {
  main = {
    cluster_name               = "myapp-cluster"
    capacity_providers         = ["FARGATE", "FARGATE_SPOT"]
    default_capacity_provider  = "FARGATE"
  }
}
```

### Lambda Integration
```hcl
# Lambda function monitoring
metric_alarms = {
  lambda_cold_starts = {
    alarm_name          = "lambda-cold-starts"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    threshold          = 5
    metric_name        = "ColdStarts"
    namespace          = "AWS/Lambda"
    dimensions = {
      FunctionName = "myapp-function"
    }
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | yes |
| `environment` | Environment name | `string` | - | yes |
| `monitoring_level` | Monitoring level (basic, enhanced, comprehensive) | `string` | `"enhanced"` | no |
| `log_groups` | CloudWatch log groups configuration | `map(object)` | `{}` | no |
| `metric_alarms` | CloudWatch metric alarms configuration | `map(object)` | `{}` | no |
| `alert_channels` | SNS alert channels with subscriptions | `map(object)` | `{}` | no |

[See variables.tf for complete list]

## Outputs

| Name | Description |
|------|-------------|
| `log_group_arns` | List of log group ARNs for IAM policies |
| `sns_topic_arns` | List of SNS topic ARNs for alarm actions |
| `dashboard_urls` | URLs to CloudWatch dashboards |
| `monitoring_summary` | Summary of all monitoring resources |

[See outputs.tf for complete list]

## Best Practices

### 🔐 Security
1. **Encrypt log groups** with KMS for sensitive data
2. **Use IAM policies** to restrict access to monitoring resources
3. **Implement least privilege** for service roles
4. **Monitor security events** with custom metrics
5. **Set up audit logging** for compliance requirements

### 💰 Cost Optimization
1. **Configure appropriate retention policies** based on environment
2. **Use log filtering** to reduce storage costs
3. **Implement intelligent alerting** to reduce noise
4. **Monitor CloudWatch costs** with billing alarms
5. **Archive old logs** to S3 for long-term retention

### 📊 Monitoring Strategy
1. **Start with basic monitoring** and scale up
2. **Define SLIs and SLOs** before setting up alerts
3. **Use composite alarms** for complex conditions
4. **Implement anomaly detection** for dynamic thresholds
5. **Create runbooks** for common alert scenarios

### 🚀 Performance
1. **Use appropriate metric periods** to balance cost and resolution
2. **Implement efficient log queries** for Insights
3. **Set up proper alerting thresholds** to avoid false positives
4. **Use metric filters** for real-time metrics from logs
5. **Monitor monitoring costs** regularly

## Troubleshooting

### Common Issues

**High CloudWatch Costs**
- Review log retention policies
- Check for excessive metrics generation
- Optimize log filtering and metric extraction

**Missing Metrics**
- Verify IAM permissions for metric publishing
- Check log group and stream configurations
- Validate metric filter patterns

**Alert Fatigue**
- Review alarm thresholds and evaluation periods
- Implement intelligent alerting with composite alarms
- Use anomaly detection for dynamic thresholds

## Version History

### v1.0.0
- Initial release with comprehensive monitoring features
- Enhanced alerting with multiple channels and filtering
- Anomaly detection and intelligent thresholds
- Synthetics monitoring for endpoint availability
- Auto-scaling integration with CloudWatch metrics
- Cost optimization features and retention policies

## Support

For issues, feature requests, or questions:
1. Check existing documentation and examples
2. Review AWS CloudWatch best practices
3. Consult Terraform AWS provider documentation
4. Create issues in the project repository

## License

This addon is part of the StackKit Terraform framework and follows the same licensing terms.