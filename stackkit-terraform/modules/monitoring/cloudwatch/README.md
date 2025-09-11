# CloudWatch Monitoring Terraform Module

A comprehensive Terraform module for AWS CloudWatch monitoring that provides log management, metric alarms, dashboards, anomaly detection, and auto-scaling integration.

## Features

- **Log Management**: CloudWatch log groups, streams, and metric filters
- **Metric Alarms**: Standard and composite alarms with various comparison operators
- **Anomaly Detection**: ML-powered anomaly detectors and alarms
- **Dashboards**: Customizable CloudWatch dashboards with widgets
- **SNS Integration**: Optional SNS topics and subscriptions for notifications
- **Auto Scaling**: Application Auto Scaling policies and event rules
- **Comprehensive Tagging**: Consistent tagging across all resources

## Usage

### Basic Example

```hcl
module "cloudwatch_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "my-app"
  environment  = "production"

  tags = {
    Owner       = "DevOps Team"
    Application = "MyApp"
    CostCenter  = "Engineering"
  }

  # Log Groups
  log_groups = {
    app_logs = {
      name              = "/aws/application/my-app"
      retention_in_days = 30
    }
    error_logs = {
      name              = "/aws/application/my-app/errors"
      retention_in_days = 90
    }
  }

  # Metric Alarms
  metric_alarms = {
    high_cpu = {
      alarm_name          = "my-app-high-cpu"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_description   = "High CPU utilization"
      dimensions = {
        InstanceId = "i-1234567890abcdef0"
      }
    }
  }

  # Create SNS topic for alerts
  create_sns_topic = true
  sns_subscriptions = {
    email = {
      protocol = "email"
      endpoint = "devops@company.com"
    }
  }
}
```

### Advanced Example with Dashboard and Anomaly Detection

```hcl
module "comprehensive_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "my-microservice"
  environment  = "production"

  # Log Groups with KMS encryption
  log_groups = {
    api_logs = {
      name              = "/aws/lambda/my-microservice-api"
      retention_in_days = 30
      kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    }
    audit_logs = {
      name              = "/aws/lambda/my-microservice-audit"
      retention_in_days = 2555  # 7 years
    }
  }

  # Log Streams
  log_streams = {
    api_stream = {
      name          = "api-requests"
      log_group_key = "api_logs"
    }
  }

  # Metric Filters
  metric_filters = {
    error_count = {
      name           = "error-count"
      log_group_key  = "api_logs"
      pattern        = "[timestamp, requestId, ERROR, ...]"
      metric_name    = "ErrorCount"
      namespace      = "MyMicroservice/Errors"
      value          = "1"
      default_value  = 0
      unit           = "Count"
    }
  }

  # Metric Alarms
  metric_alarms = {
    error_rate = {
      alarm_name          = "my-microservice-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "ErrorCount"
      namespace           = "MyMicroservice/Errors"
      period              = 300
      statistic           = "Sum"
      threshold           = 10
      alarm_description   = "High error rate detected"
      alarm_actions       = [module.cloudwatch_monitoring.sns_topic_arn]
    }
    
    lambda_duration = {
      alarm_name          = "my-microservice-duration"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "Duration"
      namespace           = "AWS/Lambda"
      period              = 300
      statistic           = "Average"
      threshold           = 5000
      alarm_description   = "Lambda function duration is too high"
      dimensions = {
        FunctionName = "my-microservice-api"
      }
    }
  }

  # Composite Alarms
  composite_alarms = {
    service_health = {
      alarm_name        = "my-microservice-overall-health"
      alarm_description = "Overall service health based on multiple metrics"
      alarm_rule        = "ALARM(${module.cloudwatch_monitoring.metric_alarm_arns.error_rate}) OR ALARM(${module.cloudwatch_monitoring.metric_alarm_arns.lambda_duration})"
      alarm_actions     = [module.cloudwatch_monitoring.sns_topic_arn]
    }
  }

  # Anomaly Detectors
  anomaly_detectors = {
    request_count_anomaly = {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      stat        = "Sum"
      dimensions = {
        FunctionName = "my-microservice-api"
      }
    }
  }

  # Anomaly Alarms
  anomaly_alarms = {
    request_anomaly = {
      alarm_name         = "my-microservice-request-anomaly"
      evaluation_periods = 2
      metric_name        = "Invocations"
      namespace          = "AWS/Lambda"
      period             = 600
      stat               = "Sum"
      alarm_description  = "Anomalous request pattern detected"
      dimensions = {
        FunctionName = "my-microservice-api"
      }
    }
  }

  # Dashboard
  dashboards = {
    main = {
      dashboard_name = "my-microservice-dashboard"
      widgets = [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Lambda", "Invocations", "FunctionName", "my-microservice-api"],
              [".", "Duration", ".", "."],
              [".", "Errors", ".", "."]
            ]
            period = 300
            stat   = "Sum"
            region = "us-east-1"
            title  = "Lambda Function Metrics"
            view   = "timeSeries"
            stacked = false
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Error Threshold"
                  value = 10
                }
              ]
            }
          }
        },
        {
          type   = "log"
          x      = 0
          y      = 6
          width  = 24
          height = 6
          properties = {
            query   = "SOURCE '/aws/lambda/my-microservice-api' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100"
            region  = "us-east-1"
            title   = "Recent Errors"
            view    = "table"
          }
        }
      ]
    }
  }

  # SNS Configuration
  create_sns_topic = true
  sns_subscriptions = {
    email = {
      protocol = "email"
      endpoint = "devops@company.com"
    }
    slack = {
      protocol = "https"
      endpoint = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
    }
  }

  # Auto Scaling Policies
  autoscaling_policies = {
    scale_up = {
      name               = "my-app-scale-up"
      policy_type        = "StepScaling"
      resource_id        = "service/my-cluster/my-service"
      scalable_dimension = "ecs:service:DesiredCount"
      service_namespace  = "ecs"
      step_scaling_config = {
        adjustment_type         = "ChangeInCapacity"
        cooldown               = 300
        metric_aggregation_type = "Average"
        step_adjustments = [
          {
            metric_interval_lower_bound = 0
            scaling_adjustment          = 2
          }
        ]
      }
    }
  }

  tags = {
    Owner       = "DevOps Team"
    Application = "MyMicroservice"
    Environment = "production"
    CostCenter  = "Engineering"
  }
}
```

### Auto Scaling Integration Example

```hcl
module "autoscaling_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "scalable-app"
  environment  = "production"

  # Target Tracking Scaling Policy
  autoscaling_policies = {
    cpu_tracking = {
      name               = "cpu-target-tracking"
      policy_type        = "TargetTrackingScaling"
      resource_id        = "service/my-cluster/my-service"
      scalable_dimension = "ecs:service:DesiredCount"
      service_namespace  = "ecs"
      target_tracking_config = {
        target_value           = 70.0
        scale_in_cooldown      = 300
        scale_out_cooldown     = 300
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    }
    
    custom_metric_tracking = {
      name               = "request-count-tracking"
      policy_type        = "TargetTrackingScaling"
      resource_id        = "service/my-cluster/my-service"
      scalable_dimension = "ecs:service:DesiredCount"
      service_namespace  = "ecs"
      target_tracking_config = {
        target_value       = 1000.0
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
        custom_metric = {
          metric_name = "RequestCount"
          namespace   = "AWS/ApplicationELB"
          statistic   = "Sum"
          dimensions = {
            LoadBalancer = "app/my-load-balancer/1234567890123456"
          }
        }
      }
    }
  }

  # Event Rules for Auto Scaling Events
  autoscaling_event_rules = {
    scaling_events = {
      name        = "ecs-scaling-events"
      description = "Capture ECS service scaling events"
      source      = ["aws.ecs"]
      detail_type = ["ECS Service Action"]
      detail = {
        eventName = ["UpdateService"]
      }
      target_id  = "scaling-notification"
      target_arn = module.cloudwatch_monitoring.sns_topic_arn
      input_transformer = {
        input_paths = {
          service = "$.detail.serviceName"
          cluster = "$.detail.clusterName"
        }
        input_template = "{\"service\": \"<service>\", \"cluster\": \"<cluster>\", \"message\": \"ECS service scaling event occurred\"}"
      }
    }
  }
}
```

## Input Variables

### Core Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `project_name` | `string` | Name of the project | Required |
| `environment` | `string` | Environment name (e.g., dev, staging, prod) | Required |
| `tags` | `map(string)` | A map of tags to assign to resources | `{}` |

### Log Management Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `log_groups` | `map(object)` | Map of log groups to create | `{}` |
| `log_streams` | `map(object)` | Map of log streams to create | `{}` |
| `metric_filters` | `map(object)` | Map of metric filters to create | `{}` |
| `default_log_retention_days` | `number` | Default log retention in days | `14` |

### Alarm Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `metric_alarms` | `map(object)` | Map of metric alarms to create | `{}` |
| `composite_alarms` | `map(object)` | Map of composite alarms to create | `{}` |
| `anomaly_detectors` | `map(object)` | Map of anomaly detectors to create | `{}` |
| `anomaly_alarms` | `map(object)` | Map of anomaly-based alarms to create | `{}` |

### Threshold Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `cpu_threshold_high` | `number` | CPU utilization threshold for high alerts | `80` |
| `memory_threshold_high` | `number` | Memory utilization threshold for high alerts | `80` |
| `disk_threshold_high` | `number` | Disk utilization threshold for high alerts | `85` |
| `response_time_threshold` | `number` | Response time threshold in milliseconds | `1000` |
| `error_rate_threshold` | `number` | Error rate threshold as percentage | `5` |

### Dashboard and Visualization

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `dashboards` | `map(object)` | Map of dashboards to create | `{}` |

### SNS Integration

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `create_sns_topic` | `bool` | Whether to create an SNS topic for alerts | `false` |
| `sns_subscriptions` | `map(object)` | Map of SNS topic subscriptions | `{}` |

### Auto Scaling

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `autoscaling_policies` | `map(object)` | Map of auto scaling policies to create | `{}` |
| `autoscaling_event_rules` | `map(object)` | Map of CloudWatch Event Rules for auto scaling | `{}` |

## Outputs

### Log Management Outputs

| Output | Description |
|--------|-------------|
| `log_group_names` | Names of the created log groups |
| `log_group_arns` | ARNs of the created log groups |
| `log_stream_names` | Names of the created log streams |
| `metric_filter_names` | Names of the created metric filters |

### Alarm Outputs

| Output | Description |
|--------|-------------|
| `metric_alarm_names` | Names of the created metric alarms |
| `metric_alarm_arns` | ARNs of the created metric alarms |
| `composite_alarm_names` | Names of the created composite alarms |
| `composite_alarm_arns` | ARNs of the created composite alarms |
| `anomaly_alarm_names` | Names of the created anomaly alarms |
| `all_alarm_arns` | All alarm ARNs (metric, composite, and anomaly alarms) |

### Dashboard Outputs

| Output | Description |
|--------|-------------|
| `dashboard_names` | Names of the created dashboards |
| `dashboard_urls` | URLs of the created dashboards |
| `dashboard_arns` | ARNs of the created dashboards |

### SNS Outputs

| Output | Description |
|--------|-------------|
| `sns_topic_arn` | ARN of the SNS topic for alerts |
| `sns_topic_name` | Name of the SNS topic for alerts |
| `sns_subscription_arns` | ARNs of the SNS subscriptions |

### Summary Output

| Output | Description |
|--------|-------------|
| `monitoring_summary` | Summary of all monitoring resources created |

## Common Patterns

### 1. Application Performance Monitoring

```hcl
module "app_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "my-app"
  environment  = "prod"

  metric_alarms = {
    response_time = {
      alarm_name          = "high-response-time"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "TargetResponseTime"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Average"
      threshold           = var.response_time_threshold
      dimensions = {
        LoadBalancer = "app/my-lb/1234567890123456"
      }
    }
    
    error_rate = {
      alarm_name          = "high-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "HTTPCode_Target_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Sum"
      threshold           = var.error_rate_threshold
      dimensions = {
        LoadBalancer = "app/my-lb/1234567890123456"
      }
    }
  }
}
```

### 2. Database Monitoring

```hcl
module "db_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "my-app"
  environment  = "prod"

  metric_alarms = {
    db_cpu = {
      alarm_name          = "rds-high-cpu"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      dimensions = {
        DBInstanceIdentifier = "my-database"
      }
    }
    
    db_connections = {
      alarm_name          = "rds-high-connections"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "DatabaseConnections"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      dimensions = {
        DBInstanceIdentifier = "my-database"
      }
    }
  }
}
```

### 3. Lambda Function Monitoring

```hcl
module "lambda_monitoring" {
  source = "./modules/monitoring/cloudwatch"

  project_name = "my-lambda"
  environment  = "prod"

  log_groups = {
    lambda_logs = {
      name              = "/aws/lambda/my-function"
      retention_in_days = 14
    }
  }

  metric_filters = {
    error_filter = {
      name           = "lambda-errors"
      log_group_key  = "lambda_logs"
      pattern        = "ERROR"
      metric_name    = "ErrorCount"
      namespace      = "MyApp/Lambda"
    }
  }

  metric_alarms = {
    lambda_errors = {
      alarm_name          = "lambda-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "ErrorCount"
      namespace           = "MyApp/Lambda"
      period              = 300
      statistic           = "Sum"
      threshold           = 5
    }
    
    lambda_duration = {
      alarm_name          = "lambda-duration"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "Duration"
      namespace           = "AWS/Lambda"
      period              = 300
      statistic           = "Average"
      threshold           = 10000
      dimensions = {
        FunctionName = "my-function"
      }
    }
  }

  anomaly_detectors = {
    invocations_anomaly = {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      stat        = "Sum"
      dimensions = {
        FunctionName = "my-function"
      }
    }
  }
}
```

## Best Practices

1. **Use Composite Alarms**: Combine multiple metrics to reduce false positives
2. **Set Appropriate Thresholds**: Based on historical data and SLA requirements
3. **Implement Anomaly Detection**: For dynamic thresholds based on historical patterns
4. **Use Consistent Tagging**: Apply tags for cost allocation and resource management
5. **Monitor Key Metrics**: Focus on metrics that directly impact user experience
6. **Set Up Proper Notifications**: Configure SNS topics with multiple notification channels
7. **Use Dashboards**: Create comprehensive dashboards for operational visibility
8. **Log Retention**: Set appropriate retention periods based on compliance requirements
9. **Metric Math**: Use metric expressions for complex calculations
10. **Regular Review**: Periodically review and adjust thresholds and alarms

## Supported Comparison Operators

- `GreaterThanOrEqualToThreshold`
- `GreaterThanThreshold`
- `LessThanThreshold`
- `LessThanOrEqualToThreshold`
- `LessThanLowerOrGreaterThanUpperThreshold` (for anomaly detection)

## Supported Statistics

- `Average`
- `Sum`
- `SampleCount`
- `Maximum`
- `Minimum`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## License

This module is released under the MIT License. See LICENSE file for details.