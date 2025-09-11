variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS service"
  type        = list(string)
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "List of short names of one or more capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy for the cluster"
  type = list(object({
    capacity_provider = string
    weight           = optional(number)
    base             = optional(number)
  }))
  default = [
    {
      capacity_provider = "FARGATE"
      weight           = 1
      base             = 0
    }
  ]
}

variable "security_group_rules" {
  description = "Security group rules for ECS tasks"
  type = list(object({
    description     = optional(string)
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
  }))
  default = []
}

# Task Definition Variables
variable "create_task_definition" {
  description = "Whether to create a task definition"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "app"
}

variable "requires_compatibilities" {
  description = "Set of launch types required by the task"
  type        = list(string)
  default     = ["FARGATE"]
}

variable "network_mode" {
  description = "Docker networking mode to use for the containers in the task"
  type        = string
  default     = "awsvpc"
}

variable "task_cpu" {
  description = "Number of CPU units used by the task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Amount (in MiB) of memory used by the task"
  type        = string
  default     = "512"
}

variable "container_definitions" {
  description = "Container definitions for the task"
  type        = any
  default     = []
}

variable "volumes" {
  description = "Volume definitions for the task"
  type = list(object({
    name      = string
    host_path = optional(string)
    docker_volume_configuration = optional(object({
      scope         = optional(string)
      autoprovision = optional(bool)
      driver        = optional(string)
      driver_opts   = optional(map(string))
      labels        = optional(map(string))
    }))
    efs_volume_configuration = optional(object({
      file_system_id          = string
      root_directory          = optional(string)
      transit_encryption      = optional(string)
      transit_encryption_port = optional(number)
      authorization_config = optional(object({
        access_point_id = optional(string)
        iam            = optional(string)
      }))
    }))
  }))
  default = []
}

# Service Variables
variable "create_service" {
  description = "Whether to create an ECS service"
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running"
  type        = number
  default     = 1
}

variable "launch_type" {
  description = "Launch type on which to run your service"
  type        = string
  default     = "FARGATE"
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy for the service"
  type = list(object({
    capacity_provider = string
    weight           = optional(number)
    base             = optional(number)
  }))
  default = []
}

variable "assign_public_ip" {
  description = "Assign a public IP address to the ENI"
  type        = bool
  default     = false
}

variable "load_balancer_config" {
  description = "Load balancer configuration for the service"
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default = []
}

variable "service_discovery_config" {
  description = "Service discovery configuration"
  type = object({
    registry_arn   = string
    port           = optional(number)
    container_name = optional(string)
    container_port = optional(number)
  })
  default = null
}

variable "deployment_maximum_percent" {
  description = "Upper limit on the number of tasks in a service that are allowed in the RUNNING or PENDING state"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit on the number of tasks in a service that must remain in the RUNNING state"
  type        = number
  default     = 100
}

variable "enable_execute_command" {
  description = "Enable the execute command functionality for the containers in this service"
  type        = bool
  default     = false
}

# Auto Scaling Variables
variable "enable_autoscaling" {
  description = "Enable auto scaling for the ECS service"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 80
}

# IAM Variables
variable "task_role_policies" {
  description = "Additional IAM policies for the task role"
  type        = list(any)
  default     = []
}

variable "task_role_managed_policies" {
  description = "List of IAM managed policy ARNs to attach to the task role"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}