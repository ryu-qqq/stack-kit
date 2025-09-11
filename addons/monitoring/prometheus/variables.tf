# Prometheus Enhanced Monitoring Addon Variables
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

# Network Configuration
variable "vpc_id" {
  description = "VPC ID for deploying Prometheus resources"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancer (if public access enabled)"
  type        = list(string)
  default     = []
}

# Security Configuration
variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "prometheus_public_access" {
  description = "Enable public internet access to Prometheus (use with caution)"
  type        = bool
  default     = false
}

variable "grafana_public_access" {
  description = "Enable public internet access to Grafana"
  type        = bool
  default     = false
}

variable "custom_metrics_ports" {
  description = "Additional ports to open for custom metrics endpoints"
  type        = list(number)
  default     = []
}

# ECS Configuration
variable "enable_container_insights" {
  description = "Enable Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "enable_service_connect" {
  description = "Enable ECS Service Connect for service discovery"
  type        = bool
  default     = true
}

variable "prometheus_cpu" {
  description = "CPU units for Prometheus task (1 vCPU = 1024 units)"
  type        = number
  default     = 1024
}

variable "prometheus_memory" {
  description = "Memory for Prometheus task in MB"
  type        = number
  default     = 2048
}

variable "grafana_cpu" {
  description = "CPU units for Grafana task"
  type        = number
  default     = 512
}

variable "grafana_memory" {
  description = "Memory for Grafana task in MB"
  type        = number
  default     = 1024
}

variable "alertmanager_cpu" {
  description = "CPU units for AlertManager task"
  type        = number
  default     = 256
}

variable "alertmanager_memory" {
  description = "Memory for AlertManager task in MB"
  type        = number
  default     = 512
}

# Load Balancer Configuration
variable "enable_alb" {
  description = "Enable Application Load Balancer for Prometheus services"
  type        = bool
  default     = true
}

variable "alb_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listener"
  type        = string
  default     = null
}

# Storage Configuration
variable "enable_persistent_storage" {
  description = "Enable EFS persistent storage for Prometheus data"
  type        = bool
  default     = true
}

variable "enable_remote_storage" {
  description = "Enable S3 remote storage for long-term metrics"
  type        = bool
  default     = false
}

variable "efs_provisioned_throughput" {
  description = "Provisioned throughput for EFS in MiB/s"
  type        = number
  default     = 100
}

variable "prometheus_retention" {
  description = "Data retention period for Prometheus (e.g., 30d, 1y)"
  type        = string
  default     = "30d"
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Log level for services (debug, info, warn, error)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

# Service Configuration
variable "enable_grafana" {
  description = "Enable Grafana deployment"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Enable AlertManager deployment"
  type        = bool
  default     = true
}

variable "enable_node_exporter" {
  description = "Enable Node Exporter for host metrics"
  type        = bool
  default     = true
}

variable "enable_cadvisor" {
  description = "Enable cAdvisor for container metrics"
  type        = bool
  default     = true
}

# Prometheus Configuration
variable "prometheus_config" {
  description = "Prometheus configuration settings"
  type = object({
    scrape_interval     = optional(string, "15s")
    evaluation_interval = optional(string, "15s")
    external_labels     = optional(map(string), {})
  })
  default = {}
}

variable "custom_scrape_configs" {
  description = "Custom scrape configurations for Prometheus"
  type = list(object({
    job_name        = string
    scrape_interval = optional(string)
    metrics_path    = optional(string)
    static_configs = optional(list(object({
      targets = list(string)
      labels  = optional(map(string))
    })))
    ec2_sd_configs = optional(list(object({
      region = string
      port   = number
    })))
    ecs_sd_configs = optional(list(object({
      cluster = string
      region  = string
    })))
    relabel_configs = optional(list(object({
      source_labels = optional(list(string))
      target_label  = optional(string)
      regex         = optional(string)
      action        = optional(string)
    })))
  }))
  default = []
}

# Grafana Configuration
variable "grafana_config" {
  description = "Grafana configuration settings"
  type = object({
    admin_user     = optional(string, "admin")
    admin_password = optional(string, "admin")
    datasources = optional(list(object({
      name      = string
      type      = string
      url       = string
      access    = optional(string, "proxy")
      isDefault = optional(bool, false)
    })), [])
    dashboards = optional(list(object({
      name = string
      json = string
    })), [])
    plugins = optional(list(string), [])
  })
  default = {}
}

# AlertManager Configuration
variable "alertmanager_config" {
  description = "AlertManager configuration"
  type = object({
    global = optional(object({
      smtp_smarthost = optional(string)
      smtp_from      = optional(string)
    }))
    route = optional(object({
      group_by        = optional(list(string), ["alertname"])
      group_wait      = optional(string, "10s")
      group_interval  = optional(string, "10s")
      repeat_interval = optional(string, "1h")
      receiver        = optional(string, "web.hook")
    }))
    receivers = optional(list(object({
      name = string
      email_configs = optional(list(object({
        to      = string
        subject = optional(string)
        body    = optional(string)
      })))
      slack_configs = optional(list(object({
        api_url = string
        channel = string
        title   = optional(string)
        text    = optional(string)
      })))
      webhook_configs = optional(list(object({
        url = string
      })))
    })), [])
  })
  default = {}
}

# Alert Rules Configuration
variable "alert_rules" {
  description = "Prometheus alert rules"
  type = list(object({
    name = string
    rules = list(object({
      alert       = string
      expr        = string
      for         = optional(string, "5m")
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    }))
  }))
  default = []
}

# Service Discovery Configuration
variable "enable_ecs_service_discovery" {
  description = "Enable ECS service discovery for automatic target detection"
  type        = bool
  default     = true
}

variable "enable_ec2_service_discovery" {
  description = "Enable EC2 service discovery for automatic target detection"
  type        = bool
  default     = true
}

variable "service_discovery_configs" {
  description = "Custom service discovery configurations"
  type = list(object({
    type = string
    config = map(any)
  }))
  default = []
}

# Monitoring Targets
variable "monitoring_targets" {
  description = "Static monitoring targets to scrape"
  type = map(object({
    targets = list(string)
    labels  = optional(map(string), {})
  }))
  default = {}
}

# Integration Configuration
variable "enable_cloudwatch_integration" {
  description = "Enable CloudWatch metrics integration"
  type        = bool
  default     = true
}

variable "enable_xray_integration" {
  description = "Enable X-Ray tracing integration"
  type        = bool
  default     = false
}

variable "cloudwatch_metrics" {
  description = "CloudWatch metrics to collect"
  type = list(object({
    namespace  = string
    metric     = string
    dimensions = optional(map(string), {})
    statistics = optional(list(string), ["Average"])
  }))
  default = []
}

# Performance Configuration
variable "prometheus_storage_size" {
  description = "Prometheus local storage size (e.g., 20Gi)"
  type        = string
  default     = "20Gi"
}

variable "prometheus_max_samples" {
  description = "Maximum number of samples Prometheus can hold in memory"
  type        = number
  default     = 500000
}

variable "prometheus_query_timeout" {
  description = "Maximum time a query may take before being aborted"
  type        = string
  default     = "2m"
}

# High Availability Configuration
variable "enable_ha" {
  description = "Enable high availability deployment (multiple instances)"
  type        = bool
  default     = false
}

variable "ha_replica_count" {
  description = "Number of Prometheus replicas for HA"
  type        = number
  default     = 2
}

variable "ha_external_labels" {
  description = "External labels for HA cluster identification"
  type        = map(string)
  default     = {}
}

# Security and Authentication
variable "enable_authentication" {
  description = "Enable authentication for Prometheus and Grafana"
  type        = bool
  default     = true
}

variable "oauth_config" {
  description = "OAuth configuration for authentication"
  type = object({
    provider      = optional(string)
    client_id     = optional(string)
    client_secret = optional(string)
    auth_url      = optional(string)
    token_url     = optional(string)
  })
  default = {}
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "spot_instances" {
  description = "Use Spot instances for cost optimization (non-prod environments)"
  type        = bool
  default     = false
}

# Environment-specific Configurations
variable "environment_configs" {
  description = "Environment-specific configuration overrides"
  type = object({
    dev = optional(object({
      prometheus_retention = optional(string, "7d")
      log_retention_days   = optional(number, 7)
      enable_ha           = optional(bool, false)
      enable_persistent_storage = optional(bool, false)
    }))
    staging = optional(object({
      prometheus_retention = optional(string, "15d")
      log_retention_days   = optional(number, 14)
      enable_ha           = optional(bool, false)
      enable_persistent_storage = optional(bool, true)
    }))
    prod = optional(object({
      prometheus_retention = optional(string, "90d")
      log_retention_days   = optional(number, 90)
      enable_ha           = optional(bool, true)
      enable_persistent_storage = optional(bool, true)
    }))
  })
  default = {}
}