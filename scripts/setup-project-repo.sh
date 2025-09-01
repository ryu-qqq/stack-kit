#!/bin/bash

# StackKit 프로젝트 레포지토리 설정 스크립트  
# 기존 중앙 Atlantis 서버와 연동하여 StackKit 모듈을 사용하는 프로젝트 설정

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME=""
PROJECT_TYPE=""
ATLANTIS_URL=""
ATLANTIS_S3_BUCKET=""
AWS_REGION="ap-northeast-2"
ENVIRONMENT="dev"
AUTO_SETUP=false

show_usage() {
    cat << EOF
🚀 StackKit 프로젝트 레포지토리 설정

기존 중앙 Atlantis 서버와 연동하여 StackKit 모듈을 사용하는 프로젝트를 설정합니다.

Usage: $0 [options]

필수 옵션:
    -p, --project-name NAME     프로젝트 이름 (예: my-web-app)
    -u, --atlantis-url URL      중앙 Atlantis 서버 URL
    -b, --s3-bucket BUCKET      Atlantis S3 버킷 이름

선택 옵션:
    -t, --type TYPE             프로젝트 타입 (web-app|api|serverless|custom)
    -e, --environment ENV       환경 이름 (기본값: dev) 
    --region REGION             AWS 리전 (기본값: ap-northeast-2)
    --auto                      대화형 입력 없이 자동 실행
    -h, --help                  도움말 표시

예시:
    # 웹 애플리케이션 프로젝트
    $0 -p my-web-app -t web-app -u http://atlantis.example.com -b my-org-atlantis-artifacts
    
    # API 서버 프로젝트
    $0 -p my-api -t api -u http://atlantis.example.com -b my-org-atlantis-artifacts
    
    # 서버리스 프로젝트
    $0 -p my-lambda -t serverless -u http://atlantis.example.com -b my-org-atlantis-artifacts

프로젝트 타입별 포함 모듈:
    web-app    : VPC, EC2 (Auto Scaling), RDS, S3
    api        : VPC, ECS (Fargate), RDS, ElastiCache  
    serverless : Lambda, DynamoDB, S3, API Gateway
    custom     : 대화형 모듈 선택

결과물:
    - terraform/stacks/{PROJECT_NAME}/{ENV} 디렉토리 생성
    - StackKit 모듈을 사용하는 Terraform 구성
    - atlantis.yaml 설정 파일
    - 환경별 tfvars 파일
    - README.md 문서
EOF
}

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project-name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -t|--type)
                PROJECT_TYPE="$2"
                shift 2
                ;;
            -u|--atlantis-url)
                ATLANTIS_URL="$2"
                shift 2
                ;;
            -b|--s3-bucket)
                ATLANTIS_S3_BUCKET="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --auto)
                AUTO_SETUP=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

validate_inputs() {
    log_info "입력 값 검증 중..."
    
    if [[ -z "$PROJECT_NAME" ]]; then
        log_error "프로젝트 이름이 필요합니다 (-p 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$ATLANTIS_URL" ]]; then
        log_error "중앙 Atlantis 서버 URL이 필요합니다 (-u 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$ATLANTIS_S3_BUCKET" ]]; then
        log_error "Atlantis S3 버킷 이름이 필요합니다 (-b 옵션 사용)"
        exit 1
    fi
    
    # Validate project type
    if [[ -n "$PROJECT_TYPE" ]] && [[ ! "$PROJECT_TYPE" =~ ^(web-app|api|serverless|custom)$ ]]; then
        log_error "지원하지 않는 프로젝트 타입: $PROJECT_TYPE"
        log_error "지원 타입: web-app, api, serverless, custom"
        exit 1
    fi

    # Check required tools
    for tool in aws terraform jq; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool이 설치되지 않았습니다"
            exit 1
        fi
    done

    # Check AWS credentials  
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 자격증명이 설정되지 않았습니다"
        exit 1
    fi

    log_success "모든 입력 값이 유효합니다"
}

interactive_setup() {
    if [[ "$AUTO_SETUP" == "true" ]]; then
        return
    fi

    log_info "대화형 설정을 시작합니다..."
    
    if [[ -z "$PROJECT_NAME" ]]; then
        read -p "프로젝트 이름을 입력하세요: " PROJECT_NAME
    fi
    
    if [[ -z "$PROJECT_TYPE" ]]; then
        echo "프로젝트 타입을 선택하세요:"
        echo "1) web-app    - VPC + EC2 + RDS (웹 애플리케이션)"
        echo "2) api        - VPC + ECS + RDS + ElastiCache (API 서버)"  
        echo "3) serverless - Lambda + DynamoDB + S3 (서버리스)"
        echo "4) custom     - 모듈 직접 선택"
        
        while true; do
            read -p "선택 (1-4): " choice
            case $choice in
                1) PROJECT_TYPE="web-app"; break;;
                2) PROJECT_TYPE="api"; break;;
                3) PROJECT_TYPE="serverless"; break;;
                4) PROJECT_TYPE="custom"; break;;
                *) echo "올바른 번호를 입력하세요.";;
            esac
        done
    fi
    
    if [[ -z "$ATLANTIS_URL" ]]; then
        read -p "중앙 Atlantis 서버 URL을 입력하세요: " ATLANTIS_URL
    fi
    
    if [[ -z "$ATLANTIS_S3_BUCKET" ]]; then
        read -p "Atlantis S3 버킷 이름을 입력하세요: " ATLANTIS_S3_BUCKET
    fi
}

create_project_structure() {
    log_info "프로젝트 구조 생성 중..."
    
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    mkdir -p "${PROJECT_DIR}"
    
    log_success "프로젝트 디렉토리 생성: ${PROJECT_DIR}"
}

generate_terraform_config() {
    log_info "Terraform 구성 생성 중..."
    
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    
    # Backend configuration
    cat > "${PROJECT_DIR}/backend.hcl" << EOF
bucket         = "stackkit-tfstate-${AWS_REGION}-\$(aws sts get-caller-identity --query Account --output text)"
key            = "${PROJECT_NAME}/${ENVIRONMENT}/terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "stackkit-tf-lock"
EOF

    # Variables
    cat > "${PROJECT_DIR}/variables.tf" << 'EOF'
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
EOF

    # Generate main.tf based on project type
    case "$PROJECT_TYPE" in
        "web-app")
            generate_webapp_config
            ;;
        "api")
            generate_api_config
            ;;
        "serverless")
            generate_serverless_config
            ;;
        "custom")
            generate_custom_config
            ;;
        *)
            log_error "Unsupported project type: $PROJECT_TYPE"
            exit 1
            ;;
    esac
    
    # Terraform variables file
    cat > "${PROJECT_DIR}/terraform.tfvars" << EOF
project_name = "${PROJECT_NAME}"
environment  = "${ENVIRONMENT}"
region       = "${AWS_REGION}"

common_tags = {
  Project     = "${PROJECT_NAME}"
  Environment = "${ENVIRONMENT}"
  ManagedBy   = "terraform"
  CreatedBy   = "stackkit-setup"
}
EOF

    # Outputs
    cat > "${PROJECT_DIR}/outputs.tf" << 'EOF'
# Common outputs will be added based on project type
EOF
}

generate_webapp_config() {
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    
    cat > "${PROJECT_DIR}/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.common_tags, {
    ProjectType = "web-app"
  })
}

# VPC Module
module "vpc" {
  source = "../../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16"
  
  availability_zones = ["${var.region}a", "${var.region}c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "prod" ? false : true
  
  common_tags = local.common_tags
}

# EC2 Web Servers Module  
module "web_servers" {
  source = "../../../modules/ec2"
  
  project_name = var.project_name
  environment  = var.environment
  instance_type = var.environment == "prod" ? "t3.medium" : "t3.micro"
  
  # Auto Scaling Configuration
  min_size         = var.environment == "prod" ? 2 : 1
  max_size         = var.environment == "prod" ? 10 : 3
  desired_capacity = var.environment == "prod" ? 2 : 1
  
  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  # Security Group Rules
  security_group_rules = [
    {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      type        = "ingress" 
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
  ]
  
  common_tags = local.common_tags
}

# RDS Database Module
module "database" {
  source = "../../../modules/rds"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Database Configuration
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.environment == "prod" ? "db.t3.small" : "db.t3.micro"
  allocated_storage = var.environment == "prod" ? 100 : 20
  
  # Database Settings
  db_name  = replace(var.project_name, "-", "_")
  username = "admin"
  
  # High Availability
  multi_az = var.environment == "prod" ? true : false
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window = "03:00-04:00"
  
  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Security
  allowed_security_groups = [module.web_servers.security_group_id]
  
  common_tags = local.common_tags
}

# S3 Static Assets Module
module "static_assets" {
  source = "../../../modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  bucket_name  = "static-assets"
  
  # Enable static website hosting
  enable_static_website = true
  
  # CORS for web applications
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["*"]
      max_age_seconds = 3600
    }
  ]
  
  common_tags = local.common_tags
}
EOF

    # Add web app specific outputs
    cat > "${PROJECT_DIR}/outputs.tf" << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.web_servers.load_balancer_dns_name
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.endpoint
}

output "static_assets_bucket" {
  description = "S3 static assets bucket name"
  value       = module.static_assets.bucket_id
}

output "static_website_endpoint" {
  description = "S3 static website endpoint"
  value       = module.static_assets.website_endpoint
}
EOF
}

generate_api_config() {
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    
    cat > "${PROJECT_DIR}/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.common_tags, {
    ProjectType = "api"
  })
}

# VPC Module
module "vpc" {
  source = "../../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16"
  
  availability_zones = ["${var.region}a", "${var.region}c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "prod" ? false : true
  
  common_tags = local.common_tags
}

# ECS API Service Module
module "api_service" {
  source = "../../../modules/ecs"
  
  project_name = var.project_name
  environment  = var.environment
  
  cluster_name = "api-cluster"
  
  services = [
    {
      name         = "api"
      desired_count = var.environment == "prod" ? 3 : 1
      
      container_definitions = [
        {
          name  = "api"
          image = "${var.project_name}:latest"
          
          portMappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
          
          environment = [
            {
              name  = "ENVIRONMENT"
              value = var.environment
            },
            {
              name  = "AWS_REGION"
              value = var.region
            }
          ]
          
          essential = true
          
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/${var.project_name}-${var.environment}"
              awslogs-region        = var.region
              awslogs-stream-prefix = "ecs"
            }
          }
        }
      ]
      
      cpu    = var.environment == "prod" ? 1024 : 512
      memory = var.environment == "prod" ? 2048 : 1024
      
      subnets         = module.vpc.private_subnet_ids
      security_groups = [aws_security_group.api.id]
      
      load_balancer = {
        target_group_arn = aws_lb_target_group.api.arn
        container_name   = "api"
        container_port   = 8080
      }
    }
  ]
  
  common_tags = local.common_tags
}

# RDS Database Module
module "database" {
  source = "../../../modules/rds"
  
  project_name = var.project_name
  environment  = var.environment
  
  engine         = "postgresql"
  engine_version = "15.4"
  instance_class = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage = var.environment == "prod" ? 100 : 20
  
  db_name  = replace(var.project_name, "-", "_")
  username = "admin"
  
  multi_az = var.environment == "prod" ? true : false
  backup_retention_period = var.environment == "prod" ? 7 : 1
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  allowed_security_groups = [aws_security_group.api.id]
  
  common_tags = local.common_tags
}

# ElastiCache Redis Module
module "cache" {
  source = "../../../modules/elasticache"
  
  project_name = var.project_name
  environment  = var.environment
  
  engine         = "redis"
  node_type      = var.environment == "prod" ? "cache.t3.medium" : "cache.t3.micro"
  num_cache_nodes = var.environment == "prod" ? 3 : 1
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  allowed_security_groups = [aws_security_group.api.id]
  
  common_tags = local.common_tags
}

# Security Groups
resource "aws_security_group" "api" {
  name_prefix = "${var.project_name}-${var.environment}-api"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api"
  })
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
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
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

# Application Load Balancer
resource "aws_lb" "api" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  tags = local.common_tags
}

resource "aws_lb_target_group" "api" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
  
  tags = local.common_tags
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}
EOF

    # Add API specific outputs
    cat > "${PROJECT_DIR}/outputs.tf" << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "api_endpoint" {
  description = "API load balancer DNS name"
  value       = "http://${aws_lb.api.dns_name}"
}

output "database_endpoint" {
  description = "RDS database endpoint"  
  value       = module.database.endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.cache.redis_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.api_service.cluster_name
}
EOF
}

generate_serverless_config() {
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    
    cat > "${PROJECT_DIR}/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.common_tags, {
    ProjectType = "serverless"
  })
}

# DynamoDB Table Module
module "main_table" {
  source = "../../../modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
  table_name   = "main"
  
  hash_key = "pk"
  range_key = "sk"
  
  attributes = [
    {
      name = "pk"
      type = "S"
    },
    {
      name = "sk"
      type = "S"
    },
    {
      name = "gsi1pk"
      type = "S"
    },
    {
      name = "gsi1sk"
      type = "S"
    }
  ]
  
  global_secondary_indexes = [
    {
      name            = "GSI1"
      hash_key        = "gsi1pk"
      range_key       = "gsi1sk"
      projection_type = "ALL"
    }
  ]
  
  billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  
  read_capacity  = var.environment == "prod" ? 5 : null
  write_capacity = var.environment == "prod" ? 5 : null
  
  common_tags = local.common_tags
}

# S3 Storage Module
module "storage" {
  source = "../../../modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  bucket_name  = "storage"
  
  # Enable versioning for prod
  enable_versioning = var.environment == "prod" ? true : false
  
  # Lifecycle rules
  lifecycle_rules = [
    {
      id     = "delete_old_versions"
      status = "Enabled"
      noncurrent_version_expiration = {
        days = 90
      }
    }
  ]
  
  # CORS for API access
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"]
      allowed_origins = ["*"]
      max_age_seconds = 3600
    }
  ]
  
  common_tags = local.common_tags
}

# Lambda Function Module - API Handler
module "api_handler" {
  source = "../../../modules/lambda"
  
  project_name  = var.project_name
  environment   = var.environment
  function_name = "api-handler"
  
  runtime     = "python3.11"
  handler     = "app.handler"
  filename    = "./lambda-code/api-handler.zip"
  memory_size = var.environment == "prod" ? 512 : 256
  timeout     = 30
  
  # Environment variables
  environment_variables = {
    DYNAMODB_TABLE = module.main_table.table_name
    S3_BUCKET      = module.storage.bucket_id
    ENVIRONMENT    = var.environment
    AWS_REGION     = var.region
  }
  
  # IAM permissions
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem", 
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          module.main_table.table_arn,
          "${module.main_table.table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.storage.bucket_arn}/*"
      }
    ]
  })
  
  common_tags = local.common_tags
}

# Lambda Function Module - Background Worker
module "worker" {
  source = "../../../modules/lambda"
  
  project_name  = var.project_name
  environment   = var.environment
  function_name = "worker"
  
  runtime     = "python3.11"
  handler     = "worker.handler"
  filename    = "./lambda-code/worker.zip"
  memory_size = var.environment == "prod" ? 1024 : 512
  timeout     = 300
  
  # Environment variables
  environment_variables = {
    DYNAMODB_TABLE = module.main_table.table_name
    S3_BUCKET      = module.storage.bucket_id
    ENVIRONMENT    = var.environment
    AWS_REGION     = var.region
  }
  
  # IAM permissions (same as API handler)
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem", 
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          module.main_table.table_arn,
          "${module.main_table.table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.storage.bucket_arn}/*"
      }
    ]
  })
  
  common_tags = local.common_tags
}

# API Gateway (optional - can be added later)
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API Gateway for ${var.project_name}"
  
  tags = local.common_tags
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.api_handler.invoke_arn
}

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.lambda,
  ]
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = var.environment
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
EOF

    # Add serverless specific outputs
    cat > "${PROJECT_DIR}/outputs.tf" << 'EOF'
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.main_table.table_name
}

output "s3_bucket_name" {
  description = "S3 storage bucket name"
  value       = module.storage.bucket_id
}

output "api_handler_function_name" {
  description = "API handler Lambda function name"
  value       = module.api_handler.function_name
}

output "worker_function_name" {
  description = "Worker Lambda function name"
  value       = module.worker.function_name
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_deployment.main.invoke_url
}
EOF

    # Create sample Lambda code structure
    mkdir -p "lambda-code"
    
    # API Handler sample code
    cat > "lambda-code/app.py" << 'EOF'
import json
import boto3
import os
from decimal import Decimal

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE']
BUCKET_NAME = os.environ['S3_BUCKET']

table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Lambda API handler function
    """
    try:
        method = event.get('httpMethod', 'GET')
        path = event.get('path', '/')
        
        if method == 'GET' and path == '/health':
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'healthy',
                    'service': 'api-handler'
                })
            }
        
        elif method == 'GET' and path.startswith('/items'):
            # List items from DynamoDB
            response = table.scan(Limit=10)
            items = response.get('Items', [])
            
            return {
                'statusCode': 200,
                'body': json.dumps(items, default=decimal_default)
            }
        
        elif method == 'POST' and path == '/items':
            # Create new item
            body = json.loads(event.get('body', '{}'))
            
            item = {
                'pk': f"ITEM#{body.get('id')}",
                'sk': 'METADATA',
                'data': body
            }
            
            table.put_item(Item=item)
            
            return {
                'statusCode': 201,
                'body': json.dumps({'message': 'Item created successfully'})
            }
        
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not found'})
            }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def decimal_default(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError
EOF

    # Worker sample code
    cat > "lambda-code/worker.py" << 'EOF'
import json
import boto3
import os

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

# Environment variables
TABLE_NAME = os.environ['DYNAMODB_TABLE']
BUCKET_NAME = os.environ['S3_BUCKET']

table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    Lambda worker function for background processing
    """
    try:
        # Process each record in the event
        for record in event.get('Records', []):
            
            # Handle S3 events
            if 'aws:s3' in record.get('eventSource', ''):
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                print(f"Processing S3 object: {bucket}/{key}")
                
                # Add processing logic here
                # Example: read file, process, update DynamoDB
                
            # Handle DynamoDB events
            elif 'aws:dynamodb' in record.get('eventSource', ''):
                event_name = record['eventName']
                
                print(f"Processing DynamoDB event: {event_name}")
                
                # Add processing logic here
                # Example: send notifications, trigger workflows
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Processing completed successfully'})
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF

    # Create deployment packages
    cd lambda-code
    zip -q api-handler.zip app.py
    zip -q worker.zip worker.py  
    cd ..
    
    log_success "Lambda 코드 샘플이 생성되었습니다"
}

generate_custom_config() {
    PROJECT_DIR="terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}"
    
    log_info "사용할 모듈을 선택하세요 (쉼표로 구분):"
    echo "사용 가능한 모듈: vpc, ec2, ecs, rds, lambda, dynamodb, s3, elasticache"
    
    read -p "모듈 목록: " modules_input
    
    IFS=',' read -ra MODULES <<< "$modules_input"
    
    # Trim whitespace
    for i in "${!MODULES[@]}"; do
        MODULES[i]=$(echo "${MODULES[i]}" | xargs)
    done
    
    cat > "${PROJECT_DIR}/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(var.common_tags, {
    ProjectType = "custom"
  })
}
EOF

    for module in "${MODULES[@]}"; do
        case "$module" in
            "vpc")
                cat >> "${PROJECT_DIR}/main.tf" << 'EOF'

# VPC Module
module "vpc" {
  source = "../../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16"
  
  availability_zones = ["${var.region}a", "${var.region}c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "prod" ? false : true
  
  common_tags = local.common_tags
}
EOF
                ;;
            "ec2")
                cat >> "${PROJECT_DIR}/main.tf" << 'EOF'

# EC2 Module
module "ec2" {
  source = "../../../modules/ec2"
  
  project_name = var.project_name
  environment  = var.environment
  instance_type = var.environment == "prod" ? "t3.medium" : "t3.micro"
  
  min_size         = var.environment == "prod" ? 2 : 1
  max_size         = var.environment == "prod" ? 10 : 3
  desired_capacity = var.environment == "prod" ? 2 : 1
  
  # vpc_id and subnet_ids should reference VPC module if used
  # vpc_id     = module.vpc.vpc_id
  # subnet_ids = module.vpc.public_subnet_ids
  
  common_tags = local.common_tags
}
EOF
                ;;
            # Add other modules as needed...
        esac
    done
    
    log_success "커스텀 모듈 구성이 생성되었습니다"
}

create_atlantis_config() {
    log_info "atlantis.yaml 설정 파일 생성 중..."
    
    cat > "atlantis.yaml" << EOF
version: 3

parallel_plan: true
parallel_apply: true

projects:
  - name: ${PROJECT_NAME}-${ENVIRONMENT}
    dir: terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}
    workflow: stackkit-${ENVIRONMENT}
    autoplan:
      enabled: true
      when_modified: ["**/*.tf", "**/*.tfvars", "../../../modules/**"]
    terraform_version: v1.8.5

workflows:
  stackkit-${ENVIRONMENT}:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-input=false", "-var-file", "terraform.tfvars"]
        - run: |
            set -euo pipefail
            # Plan 결과를 JSON/텍스트로 덤프
            terraform show -json "\$PLANFILE" > tfplan.json
            terraform show "\$PLANFILE" > plan.txt
            
            # Infracost 비용 추정 실행
            echo "💰 Infracost 비용 추정 실행 중..."
            if command -v infracost &> /dev/null; then
                if [[ -z "\${INFRACOST_API_KEY:-}" ]]; then
                    echo "⚠️  INFRACOST_API_KEY가 설정되지 않음. 기본 비용 데이터 생성."
                    echo '{"totalMonthlyCost":"0","currency":"USD","projects":[]}' > infracost.json
                else
                    infracost breakdown \\
                        --path . \\
                        --format json \\
                        --out-file infracost.json \\
                        --terraform-plan-path "\$PLANFILE" || {
                        echo "⚠️  Infracost 실행 실패. 기본 비용 데이터 생성."
                        echo '{"totalMonthlyCost":"0","currency":"USD","projects":[]}' > infracost.json
                    }
                fi
            else
                echo "⚠️  Infracost가 설치되지 않음. 기본 비용 데이터 생성."
                echo '{"totalMonthlyCost":"0","currency":"USD","projects":[]}' > infracost.json
            fi
            
            # 변경 유무 계산
            HAS_CHANGES=\$(jq '(.resource_changes|length) > 0' tfplan.json)
            
            # 비용 정보 추출
            MONTHLY_COST=\$(jq -r '.totalMonthlyCost // "0"' infracost.json 2>/dev/null || echo "0")
            
            # 메타데이터 생성
            jq -n --arg repo "\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}" \\
                  --arg pr "\$PULL_NUM" \\
                  --arg proj "${PROJECT_NAME}" \\
                  --arg action "plan" \\
                  --arg status "success" \\
                  --arg commit "\$HEAD_COMMIT" \\
                  --arg cost "\$MONTHLY_COST" \\
                  --argjson has "\$HAS_CHANGES" \\
                  '{repo:\$repo,pr:(\$pr|tonumber),project:\$proj,action:\$action,status:\$status,commit:\$commit,has_changes:\$has,monthly_cost:\$cost}' \\
              > manifest.json
            
            # S3 업로드 경로 구성
            BUCKET="${ATLANTIS_S3_BUCKET}"
            PREFIX="atlantis/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/\${PULL_NUM}/${PROJECT_NAME}"
            
            # S3 업로드
            aws s3 cp "\$PLANFILE"      "s3://\$BUCKET/\$PREFIX/tfplan.bin"
            aws s3 cp tfplan.json      "s3://\$BUCKET/\$PREFIX/tfplan.json"
            aws s3 cp plan.txt         "s3://\$BUCKET/\$PREFIX/plan.txt"
            aws s3 cp infracost.json   "s3://\$BUCKET/\$PREFIX/infracost.json"
            aws s3 cp manifest.json    "s3://\$BUCKET/\$PREFIX/manifest.json"
            
            echo "📤 Plan 결과가 중앙 AI 리뷰어로 업로드되었습니다"
            echo "💰 예상 월간 비용: \$MONTHLY_COST USD"
    apply:
      steps:
        - run: |
            set +e
            terraform apply -input=false -no-color "\$PLANFILE" | tee apply.txt
            STATUS=\$?
            set -e
            
            # Apply 결과 메타데이터
            BUCKET="${ATLANTIS_S3_BUCKET}"
            PREFIX="atlantis/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/\${PULL_NUM}/${PROJECT_NAME}"
            
            jq -n --arg repo "\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}" \\
                  --arg pr "\$PULL_NUM" \\
                  --arg proj "${PROJECT_NAME}" \\
                  --arg action "apply" \\
                  --arg status "\$([ \$STATUS -eq 0 ] && echo success || echo failure)" \\
                  --arg commit "\$HEAD_COMMIT" \\
                  '{repo:\$repo,pr:(\$pr|tonumber),project:\$proj,action:\$action,status:\$status,commit:\$commit}' \\
              > manifest.json
              
            aws s3 cp apply.txt      "s3://\$BUCKET/\$PREFIX/apply.txt"
            aws s3 cp manifest.json  "s3://\$BUCKET/\$PREFIX/manifest.json"
            
            exit \$STATUS
EOF

    log_success "atlantis.yaml 설정 파일이 생성되었습니다"
}

create_project_readme() {
    log_info "프로젝트 README.md 생성 중..."
    
    cat > "README.md" << EOF
# ${PROJECT_NAME}

${PROJECT_TYPE} 프로젝트 - StackKit 모듈을 사용한 AWS 인프라

## 📁 프로젝트 구조

\`\`\`
${PROJECT_NAME}/
├── terraform/
│   └── stacks/
│       └── ${PROJECT_NAME}/
│           └── ${ENVIRONMENT}/
│               ├── main.tf           # 메인 Terraform 구성
│               ├── variables.tf      # 변수 정의
│               ├── outputs.tf        # 출력 값
│               ├── terraform.tfvars  # 환경별 변수 값
│               └── backend.hcl       # 백엔드 설정
├── atlantis.yaml                     # Atlantis 설정
└── README.md                         # 이 파일
\`\`\`

## 🚀 배포 방법

### 로컬 배포
\`\`\`bash
cd terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}

# Terraform 초기화
terraform init -backend-config=backend.hcl

# 계획 확인
terraform plan

# 배포 실행
terraform apply
\`\`\`

### Atlantis를 통한 배포
1. Terraform 파일 수정
2. Pull Request 생성
3. Atlantis가 자동으로 \`terraform plan\` 실행
4. AI가 Plan을 분석하여 Slack에 리뷰 결과 전송
5. 검토 후 PR 코멘트에 \`atlantis apply\` 입력

## 🏗️ 인프라 구성

### 프로젝트 타입: ${PROJECT_TYPE}

EOF

    case "$PROJECT_TYPE" in
        "web-app")
            cat >> "README.md" << 'EOF'
#### 포함된 AWS 리소스:
- **VPC**: 네트워킹 기반 (10.0.0.0/16)
- **EC2**: Auto Scaling Group + Application Load Balancer  
- **RDS**: MySQL 데이터베이스 (Multi-AZ for prod)
- **S3**: 정적 자산 저장소 (웹사이트 호스팅 지원)

#### 주요 출력값:
- `load_balancer_dns`: 웹 애플리케이션 접속 URL
- `database_endpoint`: 데이터베이스 연결 엔드포인트
- `static_website_endpoint`: 정적 웹사이트 URL
EOF
            ;;
        "api")
            cat >> "README.md" << 'EOF'
#### 포함된 AWS 리소스:
- **VPC**: 네트워킹 기반 (10.0.0.0/16)
- **ECS**: Fargate를 사용한 컨테이너 서비스
- **RDS**: PostgreSQL 데이터베이스 (Multi-AZ for prod)
- **ElastiCache**: Redis 캐시 클러스터

#### 주요 출력값:
- `api_endpoint`: API 접속 URL
- `database_endpoint`: 데이터베이스 연결 엔드포인트  
- `redis_endpoint`: Redis 캐시 엔드포인트
EOF
            ;;
        "serverless")
            cat >> "README.md" << 'EOF'
#### 포함된 AWS 리소스:
- **Lambda**: API 핸들러 및 백그라운드 워커 함수
- **DynamoDB**: NoSQL 데이터베이스 (GSI 포함)
- **S3**: 파일 저장소 (CORS 설정 포함)
- **API Gateway**: REST API 엔드포인트

#### 주요 출력값:
- `api_endpoint`: API Gateway URL
- `dynamodb_table_name`: DynamoDB 테이블 이름
- `s3_bucket_name`: S3 버킷 이름
EOF
            ;;
    esac

    cat >> "README.md" << 'EOF'

## 🔧 환경별 설정

### Development (dev)
- 비용 최적화 (t3.micro, 단일 AZ)
- 단순화된 설정
- 짧은 백업 보관 기간

### Production (prod)  
- 고가용성 (Multi-AZ)
- 향상된 성능 인스턴스
- 삭제 보호 활성화
- 긴 백업 보관 기간

## 📊 비용 추정

모든 Terraform Plan은 Infracost를 통해 자동으로 비용이 계산되며, AI 리뷰어가 비용 영향을 분석하여 Slack으로 알림을 보냅니다.

## 🤖 AI 리뷰 프로세스

1. **Plan 실행**: PR 생성 시 자동으로 `terraform plan` 실행
2. **AI 분석**: GPT-4가 Plan 결과를 분석
3. **Slack 알림**: 상세한 분석 결과와 권장사항 전송
4. **검토**: 팀에서 리뷰 후 approve/apply

## 🆘 문제 해결

### Terraform 오류
```bash
# 상태 파일 확인
terraform state list

# 특정 리소스 다시 생성
terraform apply -replace=module.vpc.aws_vpc.main
```

### Atlantis 관련 문제
- Atlantis 서버 로그: CloudWatch `/ecs/atlantis-{org-name}`
- AI 리뷰어 로그: CloudWatch `/aws/lambda/atlantis-{org-name}-central-unified-reviewer-handler`

## 🔗 관련 링크

- [StackKit 메인 문서](../../../README.md)
- [중앙 Atlantis 서버 관리](../../../ATLANTIS_SETUP.md)
- [StackKit 모듈 문서](../../../terraform/modules/)
EOF

    log_success "프로젝트 README.md가 생성되었습니다"
}

show_completion_summary() {
    echo
    log_success "🎉 프로젝트 설정 완료!"
    echo
    log_info "생성된 파일들:"
    log_info "- terraform/stacks/${PROJECT_NAME}/${ENVIRONMENT}/ (Terraform 구성)"
    log_info "- atlantis.yaml (Atlantis 설정)"
    log_info "- README.md (프로젝트 문서)"
    
    if [[ "$PROJECT_TYPE" == "serverless" ]]; then
        log_info "- lambda-code/ (Lambda 함수 샘플 코드)"
    fi
    
    echo
    log_info "다음 단계:"
    log_info "1. GitHub Repository에 Webhook 설정:"
    log_info "   - URL: ${ATLANTIS_URL}/events" 
    log_info "   - Events: Pull requests, Issue comments, Push"
    log_info "2. 코드를 Git에 커밋하고 PR 생성"
    log_info "3. Atlantis가 자동으로 Plan 실행하고 AI 리뷰 진행"
    
    echo
    log_success "🚀 이제 안전하고 똑똑한 인프라 관리를 시작하세요!"
}

main() {
    echo -e "${BLUE}🚀 StackKit 프로젝트 레포지토리 설정${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
    
    parse_args "$@"
    
    if [[ "${#@}" -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    interactive_setup
    validate_inputs
    
    echo
    log_info "설정 요약:"
    log_info "- 프로젝트: ${PROJECT_NAME}"
    log_info "- 타입: ${PROJECT_TYPE}"
    log_info "- 환경: ${ENVIRONMENT}"
    log_info "- Atlantis: ${ATLANTIS_URL}"
    echo
    
    if [[ "$AUTO_SETUP" == "false" ]]; then
        read -p "계속하시겠습니까? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "설정이 취소되었습니다"
            exit 0
        fi
    fi
    
    create_project_structure
    generate_terraform_config
    create_atlantis_config
    create_project_readme
    show_completion_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi