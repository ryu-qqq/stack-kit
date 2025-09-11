# CloudWatch Enhanced Monitoring Addon Variables
# Version: v1.0.0

# Basic Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Log Groups Configuration
variable "log_groups" {
  description = "CloudWatch log groups configuration"
  type = map(object({
    name              = string
    retention_in_days = number
    kms_key_id        = optional(string)
    skip_destroy      = optional(bool)
    purpose           = optional(string)
    tags              = optional(map(string))
  }))
  default = {}
}

# Log Streams Configuration
variable "log_streams" {
  description = "CloudWatch log streams configuration"
  type = map(object({
    name           = string
    log_group_name = string
  }))
  default = {}
}

# Metric Filters Configuration
variable "metric_filters" {
  description = "CloudWatch log metric filters"
  type = map(object({
    name           = string
    log_group_name = string
    pattern        = string
    metric_name    = string
    namespace      = string
    value          = string
    default_value  = optional(number)
    unit           = optional(string)
  }))
  default = {}
}

# Enhanced Metric Alarms Configuration
variable "metric_alarms" {
  description = "CloudWatch metric alarms with enhanced features"
  type = map(object({
    alarm_name          = string
    comparison_operator = string
    evaluation_periods  = number
    threshold           = number
    alarm_description   = string
    alarm_actions       = list(string)
    ok_actions          = optional(list(string))
    treat_missing_data  = optional(string)
    datapoints_to_alarm = optional(number)
    actions_enabled     = optional(bool)
    severity            = optional(string)
    alert_type          = optional(string)
    
    # Simple metric configuration (use either this OR metric_queries)
    metric_name = optional(string)
    namespace   = optional(string)
    period      = optional(number)
    statistic   = optional(string)
    unit        = optional(string)
    dimensions  = optional(map(string))
    
    # Advanced metric queries for complex scenarios
    metric_queries = optional(list(object({
      id          = string
      return_data = optional(bool)
      label       = optional(string)
      metric = optional(object({
        metric_name = string
        namespace   = string
        period      = number
        stat        = string
        unit        = optional(string)
        dimensions  = optional(map(string))
      }))
      expression = optional(string)
    })))
    
    tags = optional(map(string))
  }))
  default = {}
}

# Composite Alarms Configuration
variable "composite_alarms" {
  description = "CloudWatch composite alarms for complex conditions"
  type = map(object({
    alarm_name                = string
    alarm_description         = string
    alarm_rule                = string
    actions_enabled           = optional(bool)
    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))
    tags                      = optional(map(string))
  }))
  default = {}
}

# Anomaly Detectors Configuration
variable "anomaly_detectors" {
  description = "CloudWatch anomaly detectors for intelligent monitoring"
  type = map(object({
    metric_name = string
    namespace   = string
    stat        = string
    dimensions  = optional(map(string))
    tags        = optional(map(string))
  }))
  default = {}
}

# Anomaly Alarms Configuration
variable "anomaly_alarms" {
  description = "CloudWatch anomaly-based alarms"
  type = map(object({
    alarm_name          = string
    evaluation_periods  = number
    alarm_description   = string
    alarm_actions       = list(string)
    ok_actions          = optional(list(string))
    treat_missing_data  = optional(string)
    datapoints_to_alarm = optional(number)
    metric_name         = string
    namespace           = string
    period              = number
    stat                = string
    dimensions          = optional(map(string))
    tags                = optional(map(string))
  }))
  default = {}
}

# Dashboard Configuration
variable "dashboards" {
  description = "CloudWatch dashboards configuration"
  type = map(object({
    dashboard_name = string
    widgets        = list(any)
  }))
  default = {}
}

# Custom Application Metrics
variable "custom_application_metrics" {
  description = "Custom application metrics from log patterns"
  type = map(object({
    name           = string
    log_group_name = string
    pattern        = string
    metric_name    = string
    namespace      = string
    value          = string
    default_value  = optional(number)
    unit           = optional(string)
  }))
  default = {}
}

# Enhanced Alert Channels
variable "alert_channels" {
  description = "Enhanced SNS alert channels with subscriptions"
  type = map(object({
    kms_key_id                  = optional(string)
    fifo_topic                  = optional(bool)
    content_based_deduplication = optional(bool)
    topic_policy                = optional(string)
    subscriptions = optional(map(object({
      protocol               = string
      endpoint               = string
      filter_policy          = optional(string)
      filter_policy_scope    = optional(string)
      confirmation_timeout   = optional(number)
      endpoint_auto_confirms = optional(bool)
    })))
  }))
  default = {}
}

# Auto Scaling Policies
variable "autoscaling_policies" {
  description = "Application Auto Scaling policies integrated with CloudWatch"
  type = map(object({
    name               = string
    policy_type        = string
    resource_id        = string
    scalable_dimension = string
    service_namespace  = string
    
    # Step Scaling Configuration
    step_scaling_config = optional(object({
      adjustment_type         = string
      cooldown               = optional(number)
      metric_aggregation_type = optional(string)
      step_adjustments = list(object({
        metric_interval_lower_bound = optional(number)
        metric_interval_upper_bound = optional(number)
        scaling_adjustment          = number
      }))
    }))
    
    # Target Tracking Configuration
    target_tracking_config = optional(object({
      target_value           = number
      scale_in_cooldown      = optional(number)
      scale_out_cooldown     = optional(number)
      predefined_metric_type = optional(string)
      resource_label         = optional(string)
      custom_metric = optional(object({
        metric_name = string
        namespace   = string
        statistic   = string
        unit        = optional(string)
        dimensions  = optional(map(string))
      }))
    }))
  }))
  default = {}
}

# EventBridge Rules Configuration
variable "event_rules" {
  description = "EventBridge rules for advanced event handling"
  type = map(object({
    name                = string
    description         = string
    event_pattern       = optional(string)
    schedule_expression = optional(string)
    state               = optional(string)
    target_id           = string
    target_arn          = string
    role_arn            = optional(string)
    
    input_transformer = optional(object({
      input_paths    = optional(map(string))
      input_template = string
    }))
    
    retry_policy = optional(object({
      maximum_event_age      = optional(number)
      maximum_retry_attempts = optional(number)
    }))
    
    dead_letter_config = optional(object({
      arn = string
    }))
    
    tags = optional(map(string))
  }))
  default = {}
}

# CloudWatch Insights Queries
variable "insights_queries" {
  description = "CloudWatch Insights saved queries for log analysis"
  type = map(object({
    name            = string
    log_group_names = list(string)
    query_string    = string
  }))
  default = {}
}

# Synthetics Canaries Configuration
variable "synthetics_canaries" {
  description = "CloudWatch Synthetics canaries for endpoint monitoring"
  type = map(object({
    name                      = string
    artifact_s3_location      = string
    execution_role_arn        = string
    handler                   = string
    zip_file                  = string
    runtime_version           = string
    start_canary              = optional(bool)
    success_retention_period  = optional(number)
    failure_retention_period  = optional(number)
    schedule_expression       = string
    duration_in_seconds       = optional(number)
    
    run_config = optional(object({
      timeout_in_seconds    = optional(number)
      memory_in_mb         = optional(number)
      active_tracing       = optional(bool)
      environment_variables = optional(map(string))
    }))
    
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    
    tags = optional(map(string))
  }))
  default = {}
}

# Container Insights Configuration
variable "enable_container_insights" {
  description = "Enable Container Insights for ECS/EKS monitoring"
  type        = bool
  default     = false
}

variable "container_insights_clusters" {
  description = "ECS clusters for Container Insights"
  type = map(object({
    cluster_name               = string
    capacity_providers         = list(string)
    default_capacity_provider  = string
    base                       = optional(number)
    weight                     = optional(number)
  }))
  default = {}
}

# X-Ray Tracing Configuration
variable "xray_sampling_rules" {
  description = "X-Ray sampling rules for distributed tracing"
  type = map(object({
    rule_name      = string
    priority       = number
    version        = optional(number)
    reservoir_size = number
    fixed_rate     = number
    url_path       = string
    host           = string
    http_method    = string
    service_name   = string
    service_type   = string
    resource_arn   = string
    attributes     = optional(map(string))
  }))
  default = {}
}

# Environment-specific Configuration
variable "monitoring_level" {
  description = "Monitoring level (basic, enhanced, comprehensive)"
  type        = string
  default     = "enhanced"
  validation {
    condition     = contains(["basic", "enhanced", "comprehensive"], var.monitoring_level)
    error_message = "Monitoring level must be one of: basic, enhanced, comprehensive."
  }
}

variable "alert_severity_levels" {
  description = "Alert severity levels configuration"
  type = object({
    critical = object({
      evaluation_periods  = number
      datapoints_to_alarm = number
      treat_missing_data  = string
    })
    high = object({
      evaluation_periods  = number
      datapoints_to_alarm = number
      treat_missing_data  = string
    })
    medium = object({
      evaluation_periods  = number
      datapoints_to_alarm = number
      treat_missing_data  = string
    })
    low = object({
      evaluation_periods  = number
      datapoints_to_alarm = number
      treat_missing_data  = string
    })
  })
  default = {
    critical = {
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      treat_missing_data  = "breaching"
    }
    high = {
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      treat_missing_data  = "breaching"
    }
    medium = {
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      treat_missing_data  = "notBreaching"
    }
    low = {
      evaluation_periods  = 5
      datapoints_to_alarm = 3
      treat_missing_data  = "notBreaching"
    }
  }
}

# Cost Optimization Settings
variable "log_retention_policies" {
  description = "Environment-specific log retention policies"
  type = object({
    application_logs = number
    access_logs      = number
    error_logs       = number
    audit_logs       = number
    debug_logs       = number
  })
  default = {
    application_logs = 30
    access_logs      = 90
    error_logs       = 180
    audit_logs       = 365
    debug_logs       = 7
  }
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

# Integration Settings
variable "integration_settings" {
  description = "Settings for integration with other AWS services"
  type = object({
    enable_s3_integration     = optional(bool)
    enable_lambda_integration = optional(bool)
    enable_ecs_integration    = optional(bool)
    enable_eks_integration    = optional(bool)
    enable_rds_integration    = optional(bool)
    enable_elasticache_integration = optional(bool)
  })
  default = {}
}