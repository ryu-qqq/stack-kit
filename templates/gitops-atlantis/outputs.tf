# =======================================
# Centralized Outputs for GitOps Atlantis
# =======================================
# Following StackKit standards with local value references

# =====================================
# 1. APPLICATION ENDPOINTS
# =====================================

output "atlantis_url" {
  description = "URL to access Atlantis"
  value       = local.atlantis_url
}

output "webhook_url" {
  description = "Webhook URL for GitHub"
  value       = "${local.atlantis_url}/events"
}

# =====================================
# 2. INFRASTRUCTURE IDENTIFIERS
# =====================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = local.private_subnet_ids
}

# =====================================
# 3. LOAD BALANCER
# =====================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.atlantis.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.atlantis.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.atlantis.arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.atlantis.arn
}

# =====================================
# 4. ECS CLUSTER
# =====================================

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.atlantis.name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.atlantis.arn
}

# =====================================
# 5. SECURITY GROUPS
# =====================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = local.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = local.ecs_security_group_id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = local.efs_security_group_id
}

# =====================================
# 6. IAM ROLES
# =====================================

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

# =====================================
# 7. STORAGE
# =====================================

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = var.enable_efs ? aws_efs_file_system.atlantis[0].id : null
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = var.enable_efs ? aws_efs_access_point.atlantis[0].id : null
}

output "terraform_state_bucket_name" {
  description = "Name of the Terraform state S3 bucket"
  value       = var.create_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].bucket : null
}

output "terraform_lock_table_name" {
  description = "Name of the Terraform lock DynamoDB table"
  value       = var.create_terraform_lock_table ? aws_dynamodb_table.terraform_lock[0].name : null
}

# =====================================
# 8. SECRETS (Sensitive)
# =====================================

output "webhook_secret" {
  description = "Webhook secret for GitHub (store securely)"
  value       = random_password.webhook_secret.result
  sensitive   = true
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for webhook"
  value       = aws_secretsmanager_secret.webhook_secret.arn
}

# =====================================
# 9. MONITORING
# =====================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.atlantis.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.atlantis.arn
}

# =====================================
# 10. AUTO SCALING (Conditional)
# =====================================

# Auto-scaling outputs removed for MVP (auto-scaling disabled)
# These outputs are no longer needed as auto-scaling is disabled
# If auto-scaling is re-enabled in the future, these can be restored
