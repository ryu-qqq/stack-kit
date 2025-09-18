variable "environment_name" {
  description = "Name of the ephemeral environment (e.g., dev-pr-123)"
  type        = string
}

variable "pr_number" {
  description = "Pull request number for tracking"
  type        = string
  default     = "manual"
}

variable "ttl_hours" {
  description = "Time to live in hours before auto-destroy"
  type        = number
  default     = 8
}

variable "use_spot_instances" {
  description = "Use Spot instances for cost savings"
  type        = bool
  default     = true
}

variable "spot_max_price" {
  description = "Maximum price for Spot instances"
  type        = string
  default     = "0.05"
}

variable "cpu" {
  description = "CPU units for the task (512 = 0.5 vCPU)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 1024
}

variable "max_tasks" {
  description = "Maximum number of tasks (1 for Vault DB)"
  type        = number
  default     = 1
}

variable "min_tasks" {
  description = "Minimum number of tasks (0 to scale to zero)"
  type        = number
  default     = 0
}

variable "enable_auto_destroy" {
  description = "Enable automatic cleanup after TTL"
  type        = bool
  default     = true
}

variable "idle_timeout_minutes" {
  description = "Minutes of idle time before scaling to zero"
  type        = number
  default     = 30
}

variable "enable_monitoring" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_cost_tracking" {
  description = "Enable cost tracking tags"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_id" {
  description = "VPC ID for the environment"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "ecr_repository_url" {
  description = "ECR repository URL for Atlantis image"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest-dev"
}

variable "domain_name" {
  description = "Domain name for the environment"
  type        = string
  default     = "dev.set-of.com"
}

variable "repo_allowlist" {
  description = "GitHub repositories allowed"
  type        = string
  default     = "github.com/ORG_NAME_PLACEHOLDER/*"
}

variable "github_token_secret_arn" {
  description = "ARN of the GitHub token secret in Secrets Manager"
  type        = string
}

variable "github_webhook_secret_arn" {
  description = "ARN of the GitHub webhook secret in Secrets Manager"
  type        = string
}

variable "create_route53_record" {
  description = "Whether to create Route53 record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = ""
}
