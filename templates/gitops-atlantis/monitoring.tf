# =======================================
# Simplified CloudWatch Monitoring
# =======================================
# Minimal monitoring for MVP Atlantis deployment

# CloudWatch Dashboard for basic metrics
resource "aws_cloudwatch_dashboard" "atlantis_dashboard" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.atlantis.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.atlantis.arn_suffix]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Atlantis Service Metrics"
          period  = 300
        }
      }
    ]
  })
}

# SNS Topic for critical alerts
resource "aws_sns_topic" "atlantis_alerts" {
  name = "${local.name_prefix}-alerts"

  tags = local.common_tags
}

# Direct SNS to Slack subscription (if webhook URL provided)
resource "aws_sns_topic_subscription" "slack_direct" {
  count = var.slack_webhook_url != "" ? 1 : 0

  topic_arn = aws_sns_topic.atlantis_alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url

  # Enable raw message delivery for Slack formatting
  raw_message_delivery = true
}

# Critical alarm: Service unhealthy
resource "aws_cloudwatch_metric_alarm" "service_unhealthy" {
  alarm_name          = "${local.name_prefix}-service-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Atlantis service is unhealthy"

  dimensions = {
    TargetGroup  = aws_lb_target_group.atlantis.arn_suffix
    LoadBalancer = aws_lb.atlantis.arn_suffix
  }

  alarm_actions = [aws_sns_topic.atlantis_alerts.arn]
  ok_actions    = [aws_sns_topic.atlantis_alerts.arn]

  tags = local.common_tags
}

# Critical alarm: High CPU usage
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "ECS CPU utilization is too high"

  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions = [aws_sns_topic.atlantis_alerts.arn]

  tags = local.common_tags
}

# Critical alarm: High memory usage
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${local.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "ECS memory utilization is too high"

  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions = [aws_sns_topic.atlantis_alerts.arn]

  tags = local.common_tags
}

# VaultDB connection monitoring (if critical)
resource "aws_cloudwatch_log_metric_filter" "vaultdb_connection_errors" {
  name           = "${local.name_prefix}-vaultdb-errors"
  pattern        = "[time, request_id, level = ERROR, msg = *vault* || msg = *database* || msg = *connection*]"
  log_group_name = aws_cloudwatch_log_group.atlantis.name

  metric_transformation {
    name      = "VaultDBConnectionErrors"
    namespace = "Atlantis/VaultDB"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "vaultdb_connection_errors" {
  alarm_name          = "${local.name_prefix}-vaultdb-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "VaultDBConnectionErrors"
  namespace           = "Atlantis/VaultDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "VaultDB connection errors detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.atlantis_alerts.arn]

  tags = local.common_tags
}
