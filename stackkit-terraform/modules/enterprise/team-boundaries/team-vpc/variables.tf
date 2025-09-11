# Team VPC Module Variables

variable "team_name" {
  description = "Name of the team"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team_name))
    error_message = "Team name must be lowercase alphanumeric with hyphens only."
  }
}

variable "team_id" {
  description = "Numeric ID of the team (1-254)"
  type        = number
  
  validation {
    condition     = var.team_id >= 1 && var.team_id <= 254
    error_message = "Team ID must be between 1 and 254."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the team VPC"
  type        = string
  default     = "10.1.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "enable_cross_team_access" {
  description = "Enable limited cross-team access via security groups"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (set to false for cost optimization in dev)"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services (cost optimization)"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC flow logs"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_retention_days)
    error_message = "Flow log retention must be a valid CloudWatch Logs retention period."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}