# Standard Module Template for StackKit Infrastructure
# This template provides the standardized structure for all Terraform modules
# to ensure consistency, maintainability, and operational excellence.

# ==============================================================================
# RESOURCE DEFINITIONS
# ==============================================================================

# Primary Resource
resource "aws_[SERVICE]_[RESOURCE]" "main" {
  # Required configuration parameters
  name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}"
  
  # Resource-specific configuration
  # ... (add resource-specific attributes)
  
  # Lifecycle management
  lifecycle {
    prevent_destroy = var.prevent_destroy
    ignore_changes  = var.ignore_changes
  }
  
  # Standard tagging
  tags = merge(var.common_tags, var.resource_tags, {
    Name         = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}"
    ManagedBy    = "Terraform"
    Module       = "[MODULE_NAME]"
    Environment  = var.environment
    Project      = var.project_name
    CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
  })
}

# ==============================================================================
# OPTIONAL FEATURES
# ==============================================================================

# Monitoring & Alarms
resource "aws_cloudwatch_metric_alarm" "main" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-[METRIC]"
  comparison_operator = var.alarm_comparison_operator
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = var.alarm_metric_name
  namespace           = var.alarm_namespace
  period              = var.alarm_period
  statistic           = var.alarm_statistic
  threshold           = var.alarm_threshold
  alarm_description   = var.alarm_description
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = var.treat_missing_data
  
  dimensions = var.alarm_dimensions
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-alarm"
  })
}

# CloudWatch Log Group (optional)
resource "aws_cloudwatch_log_group" "main" {
  count = var.enable_logging ? 1 : 0
  
  name              = "/aws/[service]/${var.project_name}-${var.environment}-${var.[RESOURCE]_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-logs"
  })
}

# Dashboard (optional)
resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0
  
  dashboard_name = "${var.project_name}-${var.environment}-[service]-${var.[RESOURCE]_name}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = var.dashboard_metrics
          period  = var.dashboard_period
          stat    = var.dashboard_statistic
          region  = data.aws_region.current.name
          title   = "[Resource] Metrics"
          view    = "timeSeries"
        }
      }
    ]
  })
}

# ==============================================================================
# SECURITY CONFIGURATIONS
# ==============================================================================

# IAM Role (if needed)
resource "aws_iam_role" "main" {
  count = var.create_iam_role ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.service_principals
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-role"
  })
}

# IAM Policy Attachment
resource "aws_iam_role_policy" "main" {
  count = var.create_iam_role && var.iam_policy_document != null ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}-policy"
  role = aws_iam_role.main[0].id
  
  policy = var.iam_policy_document
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Standard naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common resource identifiers
  resource_id = "${local.name_prefix}-${var.[RESOURCE]_name}"
  
  # Conditional configurations
  enable_encryption = var.kms_key_id != null || var.enable_encryption
  
  # Merged tags with defaults
  default_tags = {
    Environment     = var.environment
    Project        = var.project_name
    ManagedBy      = "Terraform"
    Module         = "[MODULE_NAME]"
    LastModified   = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
  }
  
  final_tags = merge(local.default_tags, var.common_tags, var.resource_tags)
}