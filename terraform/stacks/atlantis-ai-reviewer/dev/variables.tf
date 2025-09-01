variable "region"     { type = string }
variable "env"        { type = string }
variable "stack_name" { type = string }

# Infrastructure Import Options
variable "use_existing_vpc" {
  description = "Use existing VPC instead of creating new one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "Existing VPC ID to use (required if use_existing_vpc is true)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "Existing public subnet IDs (required if use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "Existing private subnet IDs (required if use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "use_existing_s3_bucket" {
  description = "Use existing S3 bucket for Atlantis outputs"
  type        = bool
  default     = false
}

variable "existing_s3_bucket_name" {
  description = "Existing S3 bucket name (required if use_existing_s3_bucket is true)"
  type        = string
  default     = ""
}

variable "use_existing_ecs_cluster" {
  description = "Use existing ECS cluster instead of creating new one"
  type        = bool
  default     = false
}

variable "existing_ecs_cluster_name" {
  description = "Existing ECS cluster name (required if use_existing_ecs_cluster is true)"
  type        = string
  default     = ""
}

# Atlantis Configuration Variables
variable "git_username" {
  description = "Git username for Atlantis"
  type        = string
}

variable "git_hostname" {
  description = "Git hostname (e.g., github.com, gitlab.com)"
  type        = string
  default     = "github.com"
}

variable "webhook_secret" {
  description = "Webhook secret for Git integration"
  type        = string
  sensitive   = true
}

variable "repo_allowlist" {
  description = "Repository allowlist pattern for Atlantis"
  type        = string
}

variable "git_token_secret_arn" {
  description = "AWS Secrets Manager ARN containing the Git token"
  type        = string
}

variable "aws_access_key_secret_arn" {
  description = "AWS Secrets Manager ARN containing AWS access key"
  type        = string
}

variable "aws_secret_key_secret_arn" {
  description = "AWS Secrets Manager ARN containing AWS secret key"
  type        = string
}

# AI Review Pipeline Variables
variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for AI reviews"
  type        = string
  sensitive   = true
}

variable "infracost_api_key" {
  description = "Infracost API key for cost estimation"
  type        = string
  sensitive   = true
  default     = ""
}

# 기존 ALB 사용 여부 (기본값: false - 새 ALB 생성)
variable "use_existing_alb" {
  description = "Whether to use an existing Application Load Balancer"
  type        = bool
  default     = false
}

variable "existing_alb_arn" {
  description = "ARN of existing ALB to use"
  type        = string
  default     = ""
}

variable "existing_alb_dns_name" {
  description = "DNS name of existing ALB"
  type        = string
  default     = ""
}
