# StackKit Monitoring Module Variables

variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "cost_alert_threshold" {
  description = "Cost increase threshold for alerts (USD)"
  type        = number
  default     = 50
}

variable "deployment_duration_threshold" {
  description = "Deployment duration threshold for alerts (seconds)"
  type        = number
  default     = 1800  # 30 minutes
}