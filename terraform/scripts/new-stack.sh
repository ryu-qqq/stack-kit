#!/usr/bin/env bash
set -euo pipefail

# Enhanced stack creation with template selection
# 사용법: scripts/new-stack.sh <stack_name> <env> [--template=TYPE] [--region=REGION] [--bucket=BUCKET] [--table=TABLE]

show_help() {
    cat << EOF
Usage: $0 <stack_name> <env> [OPTIONS]

Arguments:
    stack_name    Name of the stack to create
    env          Environment (dev|staging|prod)

Options:
    --template=TYPE    Template type: webapp|api-server|data-pipeline|custom (default: custom)
    --region=REGION    AWS region (default: ap-northeast-2)
    --bucket=BUCKET    S3 bucket for tfstate (default: stackkit-tfstate)
    --table=TABLE      DynamoDB table for locks (default: stackkit-tf-lock)
    --help            Show this help message

Examples:
    $0 my-web-app prod --template=webapp
    $0 my-api dev --template=api-server --region=us-west-2
    $0 custom-stack staging --template=custom
EOF
}

# Parse arguments
STACK="${1:-}"
ENV="${2:-}"
TEMPLATE="custom"
REGION="ap-northeast-2"
TFSTATE_BUCKET="stackkit-tfstate"
LOCK_TABLE="stackkit-tf-lock"

if [[ -z "$STACK" || -z "$ENV" ]]; then
    show_help
    exit 1
fi

# Parse optional arguments
for arg in "${@:3}"; do
    case $arg in
        --template=*)
            TEMPLATE="${arg#*=}"
            ;;
        --region=*)
            REGION="${arg#*=}"
            ;;
        --bucket=*)
            TFSTATE_BUCKET="${arg#*=}"
            ;;
        --table=*)
            LOCK_TABLE="${arg#*=}"
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

# Validate template
if [[ ! "$TEMPLATE" =~ ^(webapp|api-server|data-pipeline|atlantis-ai-reviewer|custom)$ ]]; then
    echo "❌ Invalid template: $TEMPLATE. Must be: webapp|api-server|data-pipeline|atlantis-ai-reviewer|custom"
    exit 1
fi

# Validate environment
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Invalid environment: $ENV. Must be: dev|staging|prod"
    exit 1
fi

# 스크립트 기준으로 infra 루트 계산
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$INFRA_ROOT/templates"
STACK_DIR="$INFRA_ROOT/stacks/${STACK}/${ENV}"

echo "🚀 Creating stack: $STACK ($ENV) with template: $TEMPLATE"

# Create stack directory
mkdir -p "${STACK_DIR}"

# Generate template-specific configuration
generate_template_config() {
    local template=$1
    case $template in
        webapp)
            echo "# Web Application Stack - VPC + EC2 + RDS + ElastiCache"
            ;;
        api-server)
            echo "# API Server Stack - VPC + Lambda + DynamoDB + SQS"
            ;;
        data-pipeline)
            echo "# Data Pipeline Stack - Lambda + SNS + SQS + EventBridge"
            ;;
        atlantis-ai-reviewer)
            echo "# Atlantis AI Reviewer Stack - ECS + Atlantis + AI Review Pipeline"
            ;;
        custom)
            echo "# Custom Stack - Add your modules as needed"
            ;;
    esac
}

cat > "${STACK_DIR}/versions.tf" <<'HCL'
terraform {
  required_version = "~> 1.7.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.66" }
  }
}
provider "aws" {
  region = var.region
}
HCL

cat > "${STACK_DIR}/backend.tf" <<'HCL'
terraform {
  backend "s3" {}
}
HCL

cat > "${STACK_DIR}/backend.hcl" <<HCL
bucket         = "${TFSTATE_BUCKET}"
key            = "stacks/${STACK}/${ENV}.tfstate"
region         = "${REGION}"
dynamodb_table = "${LOCK_TABLE}"
encrypt        = true
HCL

# Generate template-specific variables
generate_variables_tf() {
    local template=$1
    case $template in
        atlantis-ai-reviewer)
            cat <<'HCL'
variable "region"     { type = string }
variable "env"        { type = string }
variable "stack_name" { type = string }

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
HCL
            ;;
        *)
            cat <<'HCL'
variable "region"     { type = string }
variable "env"        { type = string }
variable "stack_name" { type = string }
HCL
            ;;
    esac
}

cat > "${STACK_DIR}/variables.tf" <<HCL
$(generate_variables_tf $TEMPLATE)
HCL

# Generate main.tf based on template
generate_main_tf() {
    local template=$1
    cat > "${STACK_DIR}/main.tf" <<HCL
$(generate_template_config $template)

locals {
  common_tags = {
    Project     = "stackkit"
    Environment = var.env
    Stack       = var.stack_name
    Owner       = "platform"
    ManagedBy   = "terraform"
  }
}

$(generate_modules_for_template $template)
HCL
}

# Generate modules based on template type
generate_modules_for_template() {
    local template=$1
    case $template in
        webapp)
            cat <<'HCL'
# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "stackkit"
  environment  = var.env
  vpc_cidr     = "10.0.0.0/16"
  
  common_tags = local.common_tags
}

# EC2 Module
module "web_server" {
  source = "../../modules/ec2"
  
  project_name   = "stackkit"
  environment    = var.env
  instance_type  = var.env == "prod" ? "t3.medium" : "t3.micro"
  ami_id         = "ami-0c2acfcb2ac4d02a0" # Amazon Linux 2023
  
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]
  
  common_tags = local.common_tags
}

# RDS Module
module "database" {
  source = "../../modules/rds"
  
  project_name     = "stackkit"
  environment      = var.env
  engine           = "mysql"
  engine_version   = "8.0"
  instance_class   = var.env == "prod" ? "db.t3.small" : "db.t3.micro"
  allocated_storage = 20
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  common_tags = local.common_tags
}

# ElastiCache Module
module "cache" {
  source = "../../modules/elasticache"
  
  project_name   = "stackkit"
  environment    = var.env
  engine         = "redis"
  node_type      = var.env == "prod" ? "cache.t3.micro" : "cache.t2.micro"
  num_cache_nodes = 1
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  common_tags = local.common_tags
}
HCL
            ;;
        api-server)
            cat <<'HCL'
# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "stackkit"
  environment  = var.env
  vpc_cidr     = "10.0.0.0/16"
  
  common_tags = local.common_tags
}

# Lambda Module
module "api_lambda" {
  source = "../../modules/lambda"
  
  project_name   = "stackkit"
  environment    = var.env
  function_name  = "${var.stack_name}-api"
  runtime        = "python3.9"
  handler        = "app.handler"
  filename       = "api.zip"
  
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.default_security_group_id]
  }
  
  common_tags = local.common_tags
}

# DynamoDB Module  
module "database" {
  source = "../../modules/dynamodb"
  
  project_name = "stackkit"
  environment  = var.env
  table_name   = "${var.stack_name}-data"
  
  hash_key  = "id"
  hash_key_type = "S"
  
  billing_mode = "PAY_PER_REQUEST"
  
  common_tags = local.common_tags
}

# SQS Module
module "queue" {
  source = "../../modules/sqs"
  
  project_name = "stackkit"
  environment  = var.env
  queue_name   = "${var.stack_name}-queue"
  
  visibility_timeout_seconds = 300
  
  common_tags = local.common_tags
}
HCL
            ;;
        data-pipeline)
            cat <<'HCL'
# Lambda Processing Function
module "processor_lambda" {
  source = "../../modules/lambda"
  
  project_name  = "stackkit"
  environment   = var.env
  function_name = "${var.stack_name}-processor"
  runtime       = "python3.9"
  handler       = "processor.handler"
  filename      = "processor.zip"
  
  common_tags = local.common_tags
}

# SNS Topic
module "notifications" {
  source = "../../modules/sns"
  
  project_name = "stackkit"
  environment  = var.env
  topic_name   = "${var.stack_name}-notifications"
  
  common_tags = local.common_tags
}

# SQS Queue
module "processing_queue" {
  source = "../../modules/sqs"
  
  project_name = "stackkit"
  environment  = var.env
  queue_name   = "${var.stack_name}-processing"
  
  visibility_timeout_seconds = 900
  
  common_tags = local.common_tags
}

# EventBridge
module "event_bus" {
  source = "../../modules/eventbridge"
  
  project_name = "stackkit"
  environment  = var.env
  event_bus_name = "${var.stack_name}-events"
  
  common_tags = local.common_tags
}
HCL
            ;;
        atlantis-ai-reviewer)
            cat <<'HCL'
# VPC Module for Atlantis Infrastructure
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "stackkit"
  environment  = var.env
  vpc_cidr     = "10.0.0.0/16"
  
  common_tags = local.common_tags
}

# S3 Bucket for storing Atlantis outputs
module "atlantis_outputs_bucket" {
  source = "../../modules/s3"
  
  project_name = "stackkit"
  environment  = var.env
  bucket_name  = "${var.stack_name}-atlantis-outputs"
  
  # Enable versioning and lifecycle policies
  versioning_enabled = true
  lifecycle_rules = [
    {
      id     = "cleanup_old_outputs"
      status = "Enabled"
      expiration = {
        days = 30
      }
    }
  ]
  
  common_tags = local.common_tags
}

# SQS Queues for AI processing pipeline
module "plan_review_queue" {
  source = "../../modules/sqs"
  
  project_name = "stackkit"
  environment  = var.env
  queue_name   = "${var.stack_name}-plan-reviews"
  
  visibility_timeout_seconds = 900  # 15 minutes for AI processing
  message_retention_seconds  = 1209600  # 14 days
  
  # DLQ for failed processing
  create_dlq = true
  max_receive_count = 3
  
  common_tags = local.common_tags
}

module "apply_review_queue" {
  source = "../../modules/sqs"
  
  project_name = "stackkit"
  environment  = var.env
  queue_name   = "${var.stack_name}-apply-reviews"
  
  visibility_timeout_seconds = 900
  message_retention_seconds  = 1209600
  
  create_dlq = true
  max_receive_count = 3
  
  common_tags = local.common_tags
}

# Lambda Functions for AI Review
module "plan_ai_reviewer" {
  source = "../../modules/lambda"
  
  project_name  = "stackkit"
  environment   = var.env
  function_name = "${var.stack_name}-plan-ai-reviewer"
  runtime       = "java21"
  handler       = "com.stackkit.atlantis.reviewer.PlanReviewerHandler::handleRequest"
  filename      = "../../lambda-functions/plan-ai-reviewer/target/plan-ai-reviewer-1.0.0.jar"
  
  memory_size = 512
  timeout     = 900  # 15 minutes
  
  # Environment variables for AI and Slack
  environment_variables = {
    ENV = var.env
    S3_BUCKET = module.atlantis_outputs_bucket.bucket_name
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    OPENAI_API_KEY = var.openai_api_key
  }
  
  # SQS trigger
  event_source_mapping = [
    {
      event_source_arn = module.plan_review_queue.arn
      batch_size      = 1
      starting_position = "LATEST"
    }
  ]
  
  common_tags = local.common_tags
}

module "apply_ai_reviewer" {
  source = "../../modules/lambda"
  
  project_name  = "stackkit"
  environment   = var.env
  function_name = "${var.stack_name}-apply-ai-reviewer"
  runtime       = "java21"
  handler       = "com.stackkit.atlantis.reviewer.ApplyReviewerHandler::handleRequest"
  filename      = "../../lambda-functions/apply-ai-reviewer/target/apply-ai-reviewer-1.0.0.jar"
  
  memory_size = 512
  timeout     = 900
  
  environment_variables = {
    ENV = var.env
    S3_BUCKET = module.atlantis_outputs_bucket.bucket_name
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    OPENAI_API_KEY = var.openai_api_key
  }
  
  event_source_mapping = [
    {
      event_source_arn = module.apply_review_queue.arn
      batch_size      = 1
      starting_position = "LATEST"
    }
  ]
  
  common_tags = local.common_tags
}

# SNS for additional notifications
module "atlantis_notifications" {
  source = "../../modules/sns"
  
  project_name = "stackkit"
  environment  = var.env
  topic_name   = "${var.stack_name}-atlantis-alerts"
  
  common_tags = local.common_tags
}

# EventBridge for orchestration
module "atlantis_event_bus" {
  source = "../../modules/eventbridge"
  
  project_name = "stackkit"
  environment  = var.env
  event_bus_name = "${var.stack_name}-atlantis-events"
  
  common_tags = local.common_tags
}

# KMS for encryption
module "atlantis_encryption_key" {
  source = "../../modules/kms"
  
  project_name = "stackkit"
  environment  = var.env
  key_name     = "${var.stack_name}-atlantis-encryption"
  description  = "Encryption key for Atlantis AI reviewer infrastructure"
  
  common_tags = local.common_tags
}

# Application Load Balancer for Atlantis
resource "aws_lb" "atlantis" {
  name               = "${var.stack_name}-atlantis-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = var.env == "prod" ? true : false

  tags = local.common_tags
}

resource "aws_lb_target_group" "atlantis" {
  name     = "${var.stack_name}-atlantis-tg"
  port     = 4141
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "atlantis" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${var.stack_name}-atlantis-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Cluster for Atlantis
module "atlantis_cluster" {
  source = "../../modules/ecs"
  
  project_name = "stackkit"
  environment  = var.env
  cluster_name = "${var.stack_name}-atlantis"
  
  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Service Configuration
  service_name    = "atlantis"
  desired_count   = var.env == "prod" ? 2 : 1
  task_cpu        = "512"
  task_memory     = "1024"
  
  # Container Definition
  container_definitions = [
    {
      name  = "atlantis"
      image = "ghcr.io/runatlantis/atlantis:latest"
      
      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "ATLANTIS_GH_USER"
          value = var.git_username
        },
        {
          name  = "ATLANTIS_GH_WEBHOOK_SECRET"
          value = var.webhook_secret
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = var.repo_allowlist
        },
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = "http://${aws_lb.atlantis.dns_name}"
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        },
        {
          name  = "ATLANTIS_DATA_DIR"
          value = "/atlantis-data"
        },
        {
          name  = "ATLANTIS_REPO_CONFIG"
          value = "/opt/atlantis/server-side-repo-config.yaml"
        },
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.region
        },
        {
          name  = "S3_BUCKET_NAME"
          value = module.atlantis_outputs_bucket.bucket_name
        },
        {
          name  = "PLAN_QUEUE_URL"
          value = module.plan_review_queue.queue_url
        },
        {
          name  = "APPLY_QUEUE_URL"
          value = module.apply_review_queue.queue_url
        }
      ]
      
      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = var.git_token_secret_arn
        },
        {
          name      = "AWS_ACCESS_KEY_ID"
          valueFrom = var.aws_access_key_secret_arn
        },
        {
          name      = "AWS_SECRET_ACCESS_KEY"
          valueFrom = var.aws_secret_key_secret_arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.stack_name}-atlantis"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      mountPoints = [
        {
          sourceVolume  = "atlantis-data"
          containerPath = "/atlantis-data"
          readOnly      = false
        }
      ]
      
      essential = true
    }
  ]
  
  # EFS Volume for persistent data
  volumes = [
    {
      name = "atlantis-data"
      efs_volume_configuration = {
        file_system_id = aws_efs_file_system.atlantis_data.id
        root_directory = "/"
        transit_encryption = "ENABLED"
      }
    }
  ]
  
  # Load Balancer Configuration
  load_balancer_config = [
    {
      target_group_arn = aws_lb_target_group.atlantis.arn
      container_name   = "atlantis"
      container_port   = 4141
    }
  ]
  
  # Security Group Rules
  security_group_rules = [
    {
      description = "Allow ALB traffic"
      from_port   = 4141
      to_port     = 4141
      protocol    = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  ]
  
  # IAM Policies for Atlantis
  task_role_policies = [
    {
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        module.atlantis_outputs_bucket.bucket_arn,
        "${module.atlantis_outputs_bucket.bucket_arn}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ]
      Resource = [
        module.plan_review_queue.arn,
        module.apply_review_queue.arn
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "sts:AssumeRole"
      ]
      Resource = "arn:aws:iam::*:role/stackkit-*-terraform-role"
    }
  ]
  
  # Auto Scaling
  enable_autoscaling     = true
  autoscaling_min_capacity = var.env == "prod" ? 1 : 1
  autoscaling_max_capacity = var.env == "prod" ? 4 : 2
  
  common_tags = local.common_tags
  
  depends_on = [aws_lb_target_group.atlantis]
}

# EFS File System for Atlantis persistent data
resource "aws_efs_file_system" "atlantis_data" {
  creation_token = "${var.stack_name}-atlantis-data"
  performance_mode = "generalPurpose"
  throughput_mode = "provisioned"
  provisioned_throughput_in_mibps = 100

  encrypted = true
  kms_key_id = module.atlantis_encryption_key.key_arn

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-data"
  })
}

resource "aws_efs_mount_target" "atlantis_data" {
  count           = length(module.vpc.private_subnet_ids)
  file_system_id  = aws_efs_file_system.atlantis_data.id
  subnet_id       = module.vpc.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.stack_name}-atlantis-efs-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [module.atlantis_cluster.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-efs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Atlantis
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${var.stack_name}-atlantis"
  retention_in_days = var.env == "prod" ? 30 : 7
  
  tags = local.common_tags
}
HCL
            ;;
        custom)
            cat <<'HCL'
# Example VPC Module - uncomment and modify as needed
# module "vpc" {
#   source = "../../modules/vpc"
#   
#   project_name = "stackkit"
#   environment  = var.env
#   vpc_cidr     = "10.0.0.0/16"
#   
#   common_tags = local.common_tags
# }

# Add your modules here following the pattern:
# module "module_name" {
#   source = "../../modules/module_name"
#   
#   project_name = "stackkit" 
#   environment  = var.env
#   
#   # module-specific variables
#   
#   common_tags = local.common_tags
# }
HCL
            ;;
    esac
}

generate_main_tf $TEMPLATE

# Generate outputs based on template
generate_outputs_tf() {
    local template=$1
    case $template in
        webapp)
            cat <<'HCL'
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for the web application"
}

output "web_server_ip" {
  value       = module.web_server.public_ip
  description = "Public IP of the web server"
}

output "database_endpoint" {
  value       = module.database.endpoint
  description = "RDS database endpoint"
}

output "cache_endpoint" {
  value       = module.cache.endpoint
  description = "ElastiCache Redis endpoint"
}
HCL
            ;;
        api-server)
            cat <<'HCL'
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for the API server"
}

output "lambda_function_name" {
  value       = module.api_lambda.function_name
  description = "Lambda function name"
}

output "dynamodb_table_name" {
  value       = module.database.table_name
  description = "DynamoDB table name"
}

output "sqs_queue_url" {
  value       = module.queue.queue_url
  description = "SQS queue URL"
}
HCL
            ;;
        data-pipeline)
            cat <<'HCL'
output "lambda_function_name" {
  value       = module.processor_lambda.function_name
  description = "Data processor Lambda function name"
}

output "sns_topic_arn" {
  value       = module.notifications.topic_arn
  description = "SNS topic ARN"
}

output "sqs_queue_url" {
  value       = module.processing_queue.queue_url
  description = "Processing queue URL"
}

output "eventbridge_bus_name" {
  value       = module.event_bus.event_bus_name
  description = "EventBridge bus name"
}
HCL
            ;;
        atlantis-ai-reviewer)
            cat <<'HCL'
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for Atlantis infrastructure"
}

output "atlantis_outputs_bucket" {
  value       = module.atlantis_outputs_bucket.bucket_name
  description = "S3 bucket name for storing Atlantis plan/apply outputs"
}

output "plan_review_queue_url" {
  value       = module.plan_review_queue.queue_url
  description = "SQS queue URL for plan reviews"
}

output "apply_review_queue_url" {
  value       = module.apply_review_queue.queue_url
  description = "SQS queue URL for apply reviews"
}

output "plan_ai_reviewer_function" {
  value       = module.plan_ai_reviewer.function_name
  description = "Lambda function name for AI plan reviews"
}

output "apply_ai_reviewer_function" {
  value       = module.apply_ai_reviewer.function_name
  description = "Lambda function name for AI apply reviews"
}

output "atlantis_notifications_topic" {
  value       = module.atlantis_notifications.topic_arn
  description = "SNS topic ARN for Atlantis notifications"
}

output "atlantis_event_bus" {
  value       = module.atlantis_event_bus.event_bus_name
  description = "EventBridge event bus name for Atlantis events"
}

output "encryption_key_id" {
  value       = module.atlantis_encryption_key.key_id
  description = "KMS key ID for Atlantis infrastructure encryption"
}

output "atlantis_cluster_id" {
  value       = module.atlantis_cluster.cluster_id
  description = "ECS cluster ID for Atlantis"
}

output "atlantis_service_name" {
  value       = module.atlantis_cluster.service_name
  description = "ECS service name for Atlantis"
}

output "atlantis_load_balancer_dns" {
  value       = aws_lb.atlantis.dns_name
  description = "DNS name of the Atlantis load balancer"
}

output "atlantis_url" {
  value       = "http://${aws_lb.atlantis.dns_name}"
  description = "URL to access Atlantis web interface"
}

output "efs_file_system_id" {
  value       = aws_efs_file_system.atlantis_data.id
  description = "EFS file system ID for Atlantis persistent data"
}
HCL
            ;;
        custom)
            cat <<'HCL'
# output "example" {
#   value       = module.example.output_value
#   description = "Example output description"
# }

# Add your outputs here
HCL
            ;;
    esac
}

cat > "${STACK_DIR}/outputs.tf" <<HCL
$(generate_outputs_tf $TEMPLATE)
HCL

# Generate template-specific tfvars
generate_tfvars() {
    local template=$1
    case $template in
        atlantis-ai-reviewer)
            cat <<HCL
region     = "${REGION}"
env        = "${ENV}"
stack_name = "${STACK}"

# Atlantis Configuration - UPDATE THESE VALUES
git_username  = "your-github-username"
git_hostname  = "github.com"
repo_allowlist = "github.com/your-org/*"

# AWS Secrets Manager ARNs - CREATE THESE SECRETS FIRST
git_token_secret_arn       = "arn:aws:secretsmanager:${REGION}:YOUR-ACCOUNT-ID:secret:atlantis/github-token-XXXXXX"
aws_access_key_secret_arn  = "arn:aws:secretsmanager:${REGION}:YOUR-ACCOUNT-ID:secret:atlantis/aws-access-key-XXXXXX"
aws_secret_key_secret_arn  = "arn:aws:secretsmanager:${REGION}:YOUR-ACCOUNT-ID:secret:atlantis/aws-secret-key-XXXXXX"

# Sensitive values - SET VIA ENVIRONMENT VARIABLES OR TERRAFORM CLOUD
# webhook_secret    = "your-webhook-secret"
# slack_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
# openai_api_key    = "sk-your-openai-api-key"
HCL
            ;;
        *)
            cat <<HCL
region     = "${REGION}"
env        = "${ENV}"
stack_name = "${STACK}"
HCL
            ;;
    esac
}

# Generate tfvars file
cat > "${STACK_DIR}/terraform.tfvars" <<HCL
$(generate_tfvars $TEMPLATE)
HCL

echo "✅ Scaffolding done at: ${STACK_DIR}"
echo "📋 Template: ${TEMPLATE}"
echo "🌏 Region: ${REGION}"
echo "📦 Bucket: ${TFSTATE_BUCKET}"
echo ""
echo "Next steps:"
echo "1️⃣  Init:     terraform -chdir=${STACK_DIR} init -backend-config=backend.hcl"  
echo "2️⃣  Plan:     terraform -chdir=${STACK_DIR} plan"
echo "3️⃣  Apply:    terraform -chdir=${STACK_DIR} apply"
echo ""
echo "📝 Files created:"
echo "  - versions.tf (Terraform & provider versions)"
echo "  - backend.tf & backend.hcl (S3 state configuration)" 
echo "  - variables.tf (Input variables)"
echo "  - main.tf (${TEMPLATE} template resources)"
echo "  - outputs.tf (Resource outputs)"
echo "  - terraform.tfvars (Variable values)"
