output "vpc_id" {
  value       = local.vpc_id
  description = "VPC ID for Atlantis infrastructure"
}

output "atlantis_outputs_bucket" {
  value       = local.atlantis_outputs_bucket_name
  description = "S3 bucket name for storing Atlantis plan/apply outputs"
}

output "plan_review_queue_url" {
  value       = module.ai_review_queue.queue_url
  description = "SQS queue URL for plan reviews"
}

output "apply_review_queue_url" {
  value       = module.ai_review_queue.queue_url
  description = "SQS queue URL for apply reviews"
}

output "plan_ai_reviewer_function" {
  value       = module.ai_reviewer.function_name
  description = "Lambda function name for AI plan reviews"
}

output "apply_ai_reviewer_function" {
  value       = module.ai_reviewer.function_name
  description = "Lambda function name for AI apply reviews"
}

output "atlantis_notifications_topic" {
  value       = module.atlantis_notifications.topic_arn
  description = "SNS topic ARN for Atlantis notifications"
}

output "atlantis_event_bus" {
  value       = aws_cloudwatch_event_bus.atlantis.name
  description = "EventBridge event bus name for Atlantis events"
}

output "encryption_key_id" {
  value       = aws_kms_key.atlantis_encryption.key_id
  description = "KMS key ID for Atlantis infrastructure encryption"
}

output "atlantis_cluster_id" {
  value       = var.use_existing_ecs_cluster ? var.existing_ecs_cluster_name : module.atlantis_cluster[0].cluster_id
  description = "ECS cluster ID for Atlantis"
}

output "atlantis_service_name" {
  value       = var.use_existing_ecs_cluster ? "existing-service" : module.atlantis_cluster[0].service_name
  description = "ECS service name for Atlantis"
}

output "atlantis_load_balancer_dns" {
  value       = local.alb_dns_name
  description = "DNS name of the Atlantis load balancer"
}

output "atlantis_url" {
  value       = "http://${local.alb_dns_name}"
  description = "URL to access Atlantis web interface"
}

output "efs_file_system_id" {
  value       = aws_efs_file_system.atlantis_data.id
  description = "EFS file system ID for Atlantis persistent data"
}

output "efs_access_point_id" {
  value       = aws_efs_access_point.atlantis_data.id
  description = "EFS access point ID for Atlantis data"
}

output "cloudwatch_alarms" {
  value = {
    service_count      = aws_cloudwatch_metric_alarm.atlantis_service_count.arn
    cpu_high          = aws_cloudwatch_metric_alarm.atlantis_cpu_high.arn
    memory_high       = aws_cloudwatch_metric_alarm.atlantis_memory_high.arn
    unhealthy_targets = aws_cloudwatch_metric_alarm.atlantis_unhealthy_targets.arn
  }
  description = "CloudWatch alarm ARNs for Atlantis monitoring"
}
