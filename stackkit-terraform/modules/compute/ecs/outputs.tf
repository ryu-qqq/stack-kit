output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = var.create_task_definition ? aws_ecs_task_definition.main[0].arn : null
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = var.create_task_definition ? aws_ecs_task_definition.main[0].family : null
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = var.create_task_definition ? aws_ecs_task_definition.main[0].revision : null
}

output "service_id" {
  description = "ID of the ECS service"
  value       = var.create_service ? aws_ecs_service.main[0].id : null
}

output "service_name" {
  description = "Name of the ECS service"
  value       = var.create_service ? aws_ecs_service.main[0].name : null
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = var.create_service ? aws_ecs_service.main[0].id : null
}

output "security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "security_group_arn" {
  description = "ARN of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_execution_role.name
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task_role.name
}