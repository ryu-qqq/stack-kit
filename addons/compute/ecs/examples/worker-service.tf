# Example: Worker Service (Background Processing)
# This example shows how to deploy a background worker service without load balancer

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-2"
}

# Backend configuration for state storage
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "services/my-worker/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Worker Service Module
module "worker_service" {
  source = "../"

  # Core Configuration
  project_name = "connectly"
  environment  = "prod"
  service_name = "message-processor"
  service_type = "worker"

  # Container Configuration
  container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/connectly-worker:latest"
  # No container_port needed for workers

  # Shared Infrastructure Integration
  use_shared_infrastructure = true
  shared_state_bucket       = "connectly-terraform-state"
  shared_state_key          = "shared/terraform.tfstate"

  # Disable ALB for worker services
  enable_alb = false

  # Production-grade environment configuration
  environment_config = {
    prod = {
      cpu              = "2048" # 2 vCPU
      memory           = "4096" # 4 GB
      container_cpu    = 2048
      container_memory = 4096
      desired_count    = 5 # Higher capacity for production
      min_capacity     = 3
      max_capacity     = 20
    }
  }

  # Environment Variables for worker
  environment_variables = {
    NODE_ENV           = "production"
    WORKER_CONCURRENCY = "10"
    QUEUE_NAME         = "message-processing"
    BATCH_SIZE         = "50"
  }

  # Secrets from Secrets Manager (production grade)
  secrets = {
    DATABASE_URL  = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:connectly/prod/database-url"
    REDIS_URL     = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:connectly/prod/redis-url"
    SQS_QUEUE_URL = "arn:aws:ssm:ap-northeast-2:123456789012:parameter/connectly/prod/sqs-queue-url"
  }

  # Enhanced IAM permissions for worker
  task_role_managed_policies = [
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
    "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  ]

  # Custom IAM policy for worker-specific resources
  task_role_policies = {
    worker_permissions = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:aws:s3:::connectly-prod-media/*",
            "arn:aws:s3:::connectly-prod-processing/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "sns:Publish"
          ]
          Resource = [
            "arn:aws:sns:ap-northeast-2:123456789012:connectly-notifications"
          ]
        }
      ]
    }
  }

  # Aggressive auto scaling for worker services
  enable_autoscaling             = true
  autoscaling_cpu_target         = 80
  autoscaling_memory_target      = 85
  autoscaling_scale_out_cooldown = 180 # Scale out faster
  autoscaling_scale_in_cooldown  = 300 # Scale in more conservatively

  # Enable service discovery for worker coordination
  enable_service_discovery = true

  # Longer log retention for production
  log_retention_days = 30

  # Health check for worker (custom command)
  health_check_command      = "node health-check.js"
  health_check_interval     = 60
  health_check_timeout      = 10
  health_check_start_period = 120

  # Production tags
  common_tags = {
    Project     = "connectly"
    Environment = "prod"
    Team        = "backend"
    Service     = "worker"
    Component   = "message-processor"
    Version     = "v1.0.0"
    CostCenter  = "engineering"
  }
}

# CloudWatch Alarms for worker monitoring
resource "aws_cloudwatch_metric_alarm" "worker_cpu_high" {
  alarm_name          = "connectly-prod-worker-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors worker CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = module.worker_service.service_name
    ClusterName = "shared-cluster"
  }

  tags = {
    Project     = "connectly"
    Environment = "prod"
    Service     = "worker"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "connectly-prod-worker-alerts"

  tags = {
    Project     = "connectly"
    Environment = "prod"
    Service     = "worker"
  }
}

# Outputs
output "worker_service_name" {
  description = "Name of the worker service"
  value       = module.worker_service.service_name
}

output "worker_log_group" {
  description = "CloudWatch log group for worker"
  value       = module.worker_service.log_group_name
}

output "worker_service_discovery_name" {
  description = "Service discovery name for worker"
  value       = module.worker_service.service_discovery_name
}