output "atlantis_url" {
  description = "URL of the Atlantis dev environment"
  value       = "https://${local.name_prefix}.${var.domain_name}"
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.dev.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.dev.name
}

output "environment_name" {
  description = "Name of the environment"
  value       = var.environment_name
}

output "estimated_hourly_cost" {
  description = "Estimated hourly cost in USD"
  value       = var.use_spot_instances ? 0.40 : 1.20
}

output "auto_destroy_time" {
  description = "Time when environment will be auto-destroyed"
  value       = timeadd(timestamp(), "${var.ttl_hours}h")
}
