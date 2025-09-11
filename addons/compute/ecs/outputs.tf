# ECS Service Outputs
output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.service.id
}

output "service_cluster" {
  description = "Cluster of the ECS service"
  value       = aws_ecs_service.service.cluster
}

output "service_desired_count" {
  description = "Desired count of the ECS service"
  value       = aws_ecs_service.service.desired_count
}

# Task Definition Outputs
output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.service.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.service.family
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = aws_ecs_task_definition.service.revision
}

# IAM Role Outputs
output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.task_role.arn
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the service security group"
  value       = aws_security_group.service.id
}

output "security_group_arn" {
  description = "ARN of the service security group"
  value       = aws_security_group.service.arn
}

# CloudWatch Log Group Outputs
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.service.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.service.arn
}

# ALB Target Group Outputs (for API services)
output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = var.service_type == "api" && var.enable_alb ? aws_lb_target_group.service[0].arn : null
}

output "target_group_name" {
  description = "Name of the ALB target group"
  value       = var.service_type == "api" && var.enable_alb ? aws_lb_target_group.service[0].name : null
}

# Service Discovery Outputs
output "service_discovery_arn" {
  description = "ARN of the service discovery service"
  value       = var.enable_service_discovery ? aws_service_discovery_service.service[0].arn : null
}

output "service_discovery_name" {
  description = "Name of the service discovery service"
  value       = var.enable_service_discovery ? aws_service_discovery_service.service[0].name : null
}

# Auto Scaling Outputs
output "autoscaling_target_resource_id" {
  description = "Resource ID of the auto scaling target"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.service[0].resource_id : null
}

output "autoscaling_cpu_policy_arn" {
  description = "ARN of the CPU auto scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.cpu[0].arn : null
}

output "autoscaling_memory_policy_arn" {
  description = "ARN of the memory auto scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.memory[0].arn : null
}

# Container Configuration Outputs
output "container_image" {
  description = "Container image used"
  value       = var.container_image
}

output "container_port" {
  description = "Container port"
  value       = var.container_port
}

# Environment Configuration Outputs
output "environment_config" {
  description = "Environment-specific configuration used"
  value       = var.environment_config[var.environment]
}

# Network Configuration Outputs (useful for debugging)
output "vpc_id" {
  description = "VPC ID used by the service"
  value       = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.vpc_id : var.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the service"
  value       = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.private_subnet_ids : var.subnet_ids
}

# Service URL (for API services with ALB)
output "service_url" {
  description = "URL of the service (for API services with ALB)"
  value = var.service_type == "api" && var.enable_alb && var.use_shared_infrastructure ? (
    length(var.alb_listener_rule_conditions) > 0 &&
    lookup(var.alb_listener_rule_conditions[0], "host_header", null) != null ?
    "https://${var.alb_listener_rule_conditions[0].host_header.values[0]}" :
    data.terraform_remote_state.shared_infrastructure.outputs.alb_dns_name
  ) : null
}