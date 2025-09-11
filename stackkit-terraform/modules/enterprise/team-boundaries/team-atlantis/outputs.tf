# Team Atlantis Module Outputs

output "atlantis_url" {
  description = "URL to access the team Atlantis instance"
  value       = local.full_domain != "" ? "https://${local.full_domain}" : "http://${aws_lb.atlantis.dns_name}"
}

output "dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.atlantis.dns_name
}

output "dns_zone_id" {
  description = "ALB DNS zone ID"
  value       = aws_lb.atlantis.zone_id
}

output "custom_domain" {
  description = "Custom domain name (if configured)"
  value       = local.full_domain
}

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.atlantis.id
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.atlantis.arn
}

output "ecs_service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.atlantis.id
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.atlantis.name
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.atlantis.arn
}

output "secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN containing team secrets"
  value       = aws_secretsmanager_secret.atlantis_secrets.arn
}

output "secrets_manager_secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.atlantis_secrets.name
}

output "github_webhook_secret" {
  description = "GitHub webhook secret for repository configuration"
  value       = random_password.github_webhook_secret.result
  sensitive   = true
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.atlantis.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.atlantis.dns_name
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.atlantis.arn
}

output "iam_execution_role_arn" {
  description = "IAM execution role ARN for ECS tasks"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "iam_task_role_arn" {
  description = "IAM task role ARN for Atlantis runtime permissions"
  value       = aws_iam_role.atlantis_task.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for Atlantis logs"
  value       = aws_cloudwatch_log_group.atlantis.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.atlantis.arn
}

output "s3_alb_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  value       = aws_s3_bucket.alb_logs.bucket
}

output "task_configuration" {
  description = "ECS task configuration details"
  value = {
    cpu           = local.task_config.cpu
    memory        = local.task_config.memory
    desired_count = local.task_config.desired_count
    size          = var.atlantis_size
  }
}

output "monitoring" {
  description = "Monitoring resources created"
  value = {
    cpu_alarm_name    = aws_cloudwatch_metric_alarm.atlantis_cpu.alarm_name
    memory_alarm_name = aws_cloudwatch_metric_alarm.atlantis_memory.alarm_name
    log_group_name    = aws_cloudwatch_log_group.atlantis.name
  }
}

output "network_info" {
  description = "Network configuration information"
  value = {
    vpc_id             = var.vpc_id
    public_subnet_ids  = var.public_subnet_ids
    private_subnet_ids = var.private_subnet_ids
    alb_security_group = var.alb_security_group_id
  }
}

output "team_info" {
  description = "Team information and configuration"
  value = {
    team_name         = var.team_name
    team_id           = var.team_id
    organization      = var.organization
    environment       = var.environment
    github_org        = var.github_org
    terraform_version = var.terraform_version
    atlantis_version  = var.atlantis_version
  }
}

output "endpoints" {
  description = "All service endpoints"
  value = {
    atlantis_url    = local.full_domain != "" ? "https://${local.full_domain}" : "http://${aws_lb.atlantis.dns_name}"
    webhook_url     = "${local.full_domain != "" ? "https://${local.full_domain}" : "http://${aws_lb.atlantis.dns_name}"}/events"
    health_check    = "${local.full_domain != "" ? "https://${local.full_domain}" : "http://${aws_lb.atlantis.dns_name}"}/healthz"
    alb_dns         = aws_lb.atlantis.dns_name
  }
}