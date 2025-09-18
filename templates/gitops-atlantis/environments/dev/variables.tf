variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment_name" {
  description = "Name of the environment"
  type        = string
  default     = "dev"
}

variable "pr_number" {
  description = "Pull request number"
  type        = string
  default     = "manual"
}

variable "ttl_hours" {
  description = "Time to live in hours"
  type        = number
  default     = 8
}

variable "use_spot_instances" {
  description = "Use Spot instances for cost savings"
  type        = bool
  default     = true
}

variable "cpu" {
  description = "CPU units (512 = 0.5 vCPU)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 1024
}

variable "max_tasks" {
  description = "Maximum number of tasks"
  type        = number
  default     = 1
}

variable "min_tasks" {
  description = "Minimum number of tasks"
  type        = number
  default     = 0
}

variable "enable_auto_destroy" {
  description = "Enable automatic cleanup"
  type        = bool
  default     = true
}

variable "idle_timeout_minutes" {
  description = "Minutes before scaling to zero"
  type        = number
  default     = 30
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_cost_tracking" {
  description = "Enable cost tracking"
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest-dev"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "dev.set-of.com"
}

variable "repo_allowlist" {
  description = "Allowed GitHub repositories"
  type        = string
  default     = "github.com/ORG_NAME_PLACEHOLDER/*,github.com/GITHUB_USER_PLACEHOLDER/*"
}
