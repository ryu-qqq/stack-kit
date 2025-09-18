output "atlantis_url" {
  description = "URL of the Atlantis dev environment"
  value       = module.ephemeral_dev.atlantis_url
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.ephemeral_dev.cluster_name
}

output "service_name" {
  description = "ECS service name"
  value       = module.ephemeral_dev.service_name
}

output "environment_name" {
  description = "Environment name"
  value       = module.ephemeral_dev.environment_name
}

output "estimated_hourly_cost" {
  description = "Estimated hourly cost in USD"
  value       = module.ephemeral_dev.estimated_hourly_cost
}

output "auto_destroy_time" {
  description = "Time when environment will be destroyed"
  value       = module.ephemeral_dev.auto_destroy_time
}

output "ecr_repository_url" {
  description = "ECR repository URL for dev images"
  value       = aws_ecr_repository.atlantis_dev.repository_url
}
