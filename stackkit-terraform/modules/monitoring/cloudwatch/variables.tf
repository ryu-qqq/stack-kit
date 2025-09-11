# Core Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

# Log Groups Configuration
variable "log_groups" {
  description = "Map of log groups to create"
  type = map(object({
    name              = string
    retention_in_days = number
    kms_key_id        = optional(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}

# Log Streams Configuration
variable "log_streams" {
  description = "Map of log streams to create"
  type = map(object({
    name           = string
    log_group_key  = string
  }))
  default = {}
}

# Metric Filters Configuration
variable "metric_filters" {
  description = "Map of metric filters to create"
  type = map(object({
    name           = string
    log_group_key  = string
    pattern        = string
    metric_name    = string
    namespace      = string
    value          = optional(string, "1")
    default_value  = optional(number, 0)
    unit           = optional(string, "Count")
  }))
  default = {}
}

# Metric Alarms Configuration
variable "metric_alarms" {
  description = "Map of metric alarms to create"
  type = map(object({
    alarm_name          = string
    comparison_operator = string
    evaluation_periods  = number
    metric_name         = string
    namespace           = string
    period              = number
    statistic           = optional(string, "Average")
    threshold           = number
    alarm_description   = optional(string, "")
    alarm_actions       = optional(list(string), [])
    ok_actions          = optional(list(string), [])
    datapoints_to_alarm = optional(number)
    treat_missing_data  = optional(string, "missing")
    unit                = optional(string)
    dimensions          = optional(map(string))
    tags                = optional(map(string), {})
    metric_queries = optional(list(object({
      id          = string
      return_data = optional(bool, true)
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
  }))
  default = {}
}

# Composite Alarms Configuration
variable "composite_alarms" {
  description = "Map of composite alarms to create"
  type = map(object({
    alarm_name                = string
    alarm_description         = optional(string, "")
    alarm_rule                = string
    actions_enabled           = optional(bool, true)
    alarm_actions            = optional(list(string), [])
    ok_actions               = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    tags                     = optional(map(string), {})
  }))
  default = {}
}

# Anomaly Detectors Configuration
variable "anomaly_detectors" {
  description = "Map of anomaly detectors to create"
  type = map(object({
    metric_name = string
    namespace   = string
    stat        = string
    dimensions  = optional(map(string))
    tags        = optional(map(string), {})
  }))
  default = {}
}

# Anomaly Alarms Configuration
variable "anomaly_alarms" {
  description = "Map of anomaly-based alarms to create"
  type = map(object({
    alarm_name         = string
    evaluation_periods = number
    metric_name        = string
    namespace          = string
    period             = number
    stat               = string
    alarm_description  = optional(string, "")
    alarm_actions      = optional(list(string), [])
    ok_actions         = optional(list(string), [])
    treat_missing_data = optional(string, "breaching")
    dimensions         = optional(map(string))
    tags               = optional(map(string), {})
  }))
  default = {}
}

# Dashboard Configuration
variable "dashboards" {
  description = "Map of dashboards to create"
  type = map(object({
    dashboard_name = string
    widgets = list(object({
      type   = string
      x      = number
      y      = number
      width  = number
      height = number
      properties = object({
        metrics = optional(list(list(string)))
        view    = optional(string, "timeSeries")
        stacked = optional(bool, false)
        region  = optional(string)
        title   = optional(string)
        period  = optional(number, 300)
        stat    = optional(string, "Average")
        annotations = optional(object({
          horizontal = optional(list(object({
            label = string
            value = number
          })))
        }))
        yAxis = optional(object({
          left = optional(object({
            min = optional(number)
            max = optional(number)
          }))
          right = optional(object({
            min = optional(number)
            max = optional(number)
          }))
        }))
        query = optional(string)
        sparkline = optional(bool, true)
        trend = optional(bool, true)
        liveData = optional(bool, false)
        setPeriodToTimeRange = optional(bool, true)
      })
    }))
  }))
  default = {}
}

# SNS Configuration
variable "create_sns_topic" {
  description = "Whether to create an SNS topic for alerts"
  type        = bool
  default     = false
}

variable "sns_subscriptions" {
  description = "Map of SNS topic subscriptions"
  type = map(object({
    protocol = string
    endpoint = string
  }))
  default = {}
}

# Auto Scaling Configuration
variable "autoscaling_policies" {
  description = "Map of auto scaling policies to create"
  type = map(object({
    name               = string
    policy_type        = string
    resource_id        = string
    scalable_dimension = string
    service_namespace  = string
    step_scaling_config = optional(object({
      adjustment_type         = string
      cooldown               = number
      metric_aggregation_type = string
      step_adjustments = list(object({
        metric_interval_lower_bound = optional(number)
        metric_interval_upper_bound = optional(number)
        scaling_adjustment          = number
      }))
    }))
    target_tracking_config = optional(object({
      target_value              = number
      scale_in_cooldown        = optional(number, 300)
      scale_out_cooldown       = optional(number, 300)
      predefined_metric_type   = optional(string)
      resource_label           = optional(string)
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

# Auto Scaling Event Rules
variable "autoscaling_event_rules" {
  description = "Map of CloudWatch Event Rules for auto scaling"
  type = map(object({
    name        = string
    description = optional(string, "")
    source      = list(string)
    detail_type = list(string)
    detail      = optional(map(any), {})
    target_id   = string
    target_arn  = string
    role_arn    = optional(string)
    tags        = optional(map(string), {})
    input_transformer = optional(object({
      input_paths    = map(string)
      input_template = string
    }))
  }))
  default = {}
}

# Common Alarm Thresholds
variable "cpu_threshold_high" {
  description = "CPU utilization threshold for high alerts"
  type        = number
  default     = 80
}

variable "cpu_threshold_low" {
  description = "CPU utilization threshold for low alerts"
  type        = number
  default     = 10
}

variable "memory_threshold_high" {
  description = "Memory utilization threshold for high alerts"
  type        = number
  default     = 80
}

variable "disk_threshold_high" {
  description = "Disk utilization threshold for high alerts"
  type        = number
  default     = 85
}

variable "response_time_threshold" {
  description = "Response time threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "error_rate_threshold" {
  description = "Error rate threshold as percentage"
  type        = number
  default     = 5
}

# Common Periods and Evaluation Settings
variable "default_period" {
  description = "Default period for metrics in seconds"
  type        = number
  default     = 300
}

variable "default_evaluation_periods" {
  description = "Default number of evaluation periods"
  type        = number
  default     = 2
}

variable "default_datapoints_to_alarm" {
  description = "Default number of datapoints to alarm"
  type        = number
  default     = 2
}

# Log Retention Settings
variable "default_log_retention_days" {
  description = "Default log retention in days"
  type        = number
  default     = 14
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (1-minute metrics)"
  type        = bool
  default     = false
}