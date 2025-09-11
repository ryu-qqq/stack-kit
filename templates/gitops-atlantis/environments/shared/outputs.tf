# =======================================
# Outputs for Atlantis GitOps
# =======================================

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.load_balancer.alb_zone_id
}

output "atlantis_url" {
  description = "URL to access Atlantis"
  value       = var.create_route53_record ? "https://${var.atlantis_hostname}" : "http://${module.load_balancer.alb_dns_name}"
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.compute.cluster_id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.compute.service_name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = module.compute.task_definition_arn
}

# Security Group IDs
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.security.ecs_security_group_id
}

# Storage Outputs
output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = module.storage.efs_file_system_id
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = module.storage.secrets_manager_arn
}

# Terraform State Backend
output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = module.storage.terraform_state_bucket_name
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = module.storage.terraform_lock_table_name
}

# GitHub Webhook URL
output "github_webhook_url" {
  description = "GitHub webhook URL for Atlantis"
  value       = "${var.atlantis_url}/events"
}

# CloudWatch Log Group
output "cloudwatch_log_group" {
  description = "CloudWatch log group for Atlantis"
  value       = "/ecs/${var.environment}-${var.project_name}"
}

# Connection Instructions
output "connection_instructions" {
  description = "Instructions for connecting to Atlantis"
  value       = <<-EOT
    
    ========================================
    Atlantis GitOps Setup Complete!
    ========================================
    
    1. Access Atlantis at:
       ${var.create_route53_record ? "https://${var.atlantis_hostname}" : "http://${module.load_balancer.alb_dns_name}"}
    
    2. Configure GitHub Webhook:
       - URL: ${var.atlantis_url}/events
       - Secret: (stored in Secrets Manager)
       - Events: Pull requests, Pull request reviews, Issue comments, Pushes
    
    3. View logs in CloudWatch:
       Log Group: /ecs/${var.environment}-${var.project_name}
    
    4. SSH into container (if needed):
       aws ecs execute-command --cluster ${module.compute.cluster_id} \
         --task <task-id> \
         --container atlantis \
         --interactive \
         --command "/bin/sh"
    
    ========================================
  EOT
}