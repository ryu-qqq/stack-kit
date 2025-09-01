#!/bin/bash

# StackKit 중앙 Atlantis + AI Reviewer 인프라 셋업 스크립트
# 단일 중앙 집중식 Atlantis 서버를 구축하여 여러 프로젝트 레포를 관리

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
ORG_NAME=""
GITHUB_TOKEN=""
OPENAI_API_KEY=""
SLACK_WEBHOOK=""
AWS_REGION="ap-northeast-2"
DOMAIN_NAME=""
REPO_ALLOWLIST=""
AUTO_SETUP=false

show_usage() {
    cat << EOF
🏗️ StackKit 중앙 Atlantis + AI Reviewer 인프라 셋업

여러 프로젝트 레포지토리를 관리할 수 있는 중앙 집중식 Atlantis 서버를 구축합니다.

Usage: $0 [options]

필수 옵션:
    -o, --org-name NAME         조직/회사 이름 (예: mycompany)
    -g, --github-token TOKEN    GitHub Personal Access Token
    -k, --openai-key KEY        OpenAI API Key  
    -s, --slack-webhook URL     Slack Webhook URL
    -a, --allowlist PATTERN     관리할 레포 패턴 (예: "github.com/myorg/*")

선택 옵션:
    -d, --domain DOMAIN         도메인 이름 (예: atlantis.mycompany.com)
    --region REGION             AWS 리전 (기본값: ap-northeast-2)
    --auto                      대화형 입력 없이 자동 실행
    -h, --help                  도움말 표시

예시:
    # 기본 설정
    $0 -o mycompany -g ghp_xxx -k sk-xxx -s https://hooks.slack.com/... -a "github.com/myorg/*"
    
    # 커스텀 도메인 포함
    $0 -o mycompany -g ghp_xxx -k sk-xxx -s https://hooks.slack.com/... -a "github.com/myorg/*" -d atlantis.mycompany.com

중요 사항:
- 이 스크립트는 atlantis-infrastructure 전용 레포에서 실행하세요
- 구축된 Atlantis는 allowlist의 모든 프로젝트 레포를 관리합니다
- 프로젝트 레포에는 setup-project-repo.sh를 사용하세요
EOF
}

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org-name)
                ORG_NAME="$2"
                shift 2
                ;;
            -g|--github-token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            -k|--openai-key)
                OPENAI_API_KEY="$2"
                shift 2
                ;;
            -s|--slack-webhook)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            -a|--allowlist)
                REPO_ALLOWLIST="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN_NAME="$2"
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
    
    if [[ -z "$ORG_NAME" ]]; then
        log_error "조직 이름이 필요합니다 (-o 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GitHub Token이 필요합니다 (-g 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        log_error "OpenAI API Key가 필요합니다 (-k 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        log_error "Slack Webhook URL이 필요합니다 (-s 옵션 사용)"
        exit 1
    fi
    
    if [[ -z "$REPO_ALLOWLIST" ]]; then
        log_error "관리할 레포 패턴이 필요합니다 (-a 옵션 사용)"
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
    
    if [[ -z "$ORG_NAME" ]]; then
        read -p "조직/회사 이름을 입력하세요: " ORG_NAME
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        read -s -p "GitHub Personal Access Token을 입력하세요: " GITHUB_TOKEN
        echo
    fi
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        read -s -p "OpenAI API Key를 입력하세요: " OPENAI_API_KEY
        echo
    fi
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        read -p "Slack Webhook URL을 입력하세요: " SLACK_WEBHOOK
    fi
    
    if [[ -z "$REPO_ALLOWLIST" ]]; then
        read -p "관리할 레포 패턴을 입력하세요 (예: github.com/myorg/*): " REPO_ALLOWLIST
    fi
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        read -p "도메인 이름 (선택사항, 엔터로 건너뛰기): " DOMAIN_NAME
    fi
}

create_terraform_stack() {
    log_info "Terraform 스택 생성 중..."
    
    STACK_NAME="atlantis-central-${ORG_NAME}"
    STACK_DIR="terraform/stacks/${STACK_NAME}"
    
    mkdir -p "${STACK_DIR}"
    
    # Backend configuration
    cat > "${STACK_DIR}/backend.hcl" << EOF
bucket         = "stackkit-tfstate-${AWS_REGION}-\$(aws sts get-caller-identity --query Account --output text)"
key            = "${STACK_NAME}/terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "stackkit-tf-lock"
EOF

    # Variables
    cat > "${STACK_DIR}/variables.tf" << 'EOF'
variable "org_name" {
  description = "Organization name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "central"
}

variable "github_token_secret_arn" {
  description = "ARN of GitHub token secret"
  type        = string
}

variable "openai_api_key_secret_arn" {
  description = "ARN of OpenAI API key secret" 
  type        = string
}

variable "slack_webhook_secret_arn" {
  description = "ARN of Slack webhook secret"
  type        = string
}

variable "repo_allowlist" {
  description = "Repository allowlist for Atlantis"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Atlantis (optional)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
EOF

    # Main configuration
    cat > "${STACK_DIR}/main.tf" << 'EOF'
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
  project_name = "atlantis-${var.org_name}"
  common_tags = merge(var.common_tags, {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "atlantis-central"
  })
}

# VPC for Atlantis infrastructure
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = local.project_name
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16"
  
  availability_zones = ["${var.region}a", "${var.region}c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false  # HA for central service
  
  common_tags = local.common_tags
}

# S3 bucket for Terraform plans and artifacts
module "plan_artifacts" {
  source = "../../modules/s3"
  
  project_name = local.project_name
  environment  = var.environment
  bucket_name  = "plan-artifacts"
  
  # Enable versioning for plan history
  enable_versioning = true
  
  # Lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id     = "delete_old_plans"
      status = "Enabled"
      expiration = {
        days = 30
      }
      noncurrent_version_expiration = {
        days = 7
      }
    }
  ]
  
  common_tags = local.common_tags
}

# EventBridge for S3 to Lambda triggers
module "event_bridge" {
  source = "../../modules/eventbridge"
  
  project_name = local.project_name
  environment  = var.environment
  
  # S3 event rules
  rules = [
    {
      name         = "plan-uploaded"
      description  = "Trigger when Terraform plan is uploaded"
      event_pattern = jsonencode({
        source      = ["aws.s3"]
        detail-type = ["Object Created"]
        detail = {
          bucket = {
            name = [module.plan_artifacts.bucket_id]
          }
          object = {
            key = [{
              suffix = "manifest.json"
            }]
          }
        }
      })
      targets = [{
        id  = "ai-reviewer"
        arn = module.ai_reviewer.function_arn
      }]
    }
  ]
  
  common_tags = local.common_tags
}

# AI Reviewer Lambda function
module "ai_reviewer" {
  source = "../../modules/lambda"
  
  project_name  = local.project_name
  environment   = var.environment
  function_name = "unified-reviewer-handler"
  
  runtime     = "java17"
  handler     = "com.stackkit.plan.handlers.UnifiedReviewerHandler::handleRequest"
  memory_size = 1024
  timeout     = 300
  
  # Package AI reviewer code (created below)
  filename = "./ai-reviewer-${var.org_name}.zip"
  
  environment_variables = {
    OPENAI_API_KEY_SECRET_ARN = var.openai_api_key_secret_arn
    SLACK_WEBHOOK_SECRET_ARN  = var.slack_webhook_secret_arn
    S3_BUCKET_NAME           = module.plan_artifacts.bucket_id
    AWS_REGION               = var.region
  }
  
  # IAM permissions for S3, Secrets Manager, and EventBridge
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${module.plan_artifacts.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.openai_api_key_secret_arn,
          var.slack_webhook_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream", 
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
  
  common_tags = local.common_tags
}

# ECS cluster for Atlantis
module "atlantis_cluster" {
  source = "../../modules/ecs"
  
  project_name = local.project_name
  environment  = var.environment
  
  # Cluster configuration
  cluster_name = "atlantis"
  
  # Service configuration
  services = [
    {
      name         = "atlantis"
      desired_count = 2  # HA setup
      
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
              name  = "ATLANTIS_REPO_ALLOWLIST"
              value = var.repo_allowlist
            },
            {
              name  = "ATLANTIS_PORT"
              value = "4141"
            },
            {
              name  = "ATLANTIS_ATLANTIS_URL"
              value = var.domain_name != "" ? "https://${var.domain_name}" : ""
            }
          ]
          
          secrets = [
            {
              name      = "ATLANTIS_GH_TOKEN"
              valueFrom = var.github_token_secret_arn
            }
          ]
          
          essential = true
          
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/atlantis-${var.org_name}"
              awslogs-region        = var.region
              awslogs-stream-prefix = "ecs"
            }
          }
        }
      ]
      
      # Resource requirements
      cpu    = 1024
      memory = 2048
      
      # Networking
      subnets         = module.vpc.private_subnet_ids
      security_groups = [aws_security_group.atlantis.id]
      
      # Load balancer
      load_balancer = {
        target_group_arn = aws_lb_target_group.atlantis.arn
        container_name   = "atlantis"
        container_port   = 4141
      }
    }
  ]
  
  common_tags = local.common_tags
}

# Security group for Atlantis
resource "aws_security_group" "atlantis" {
  name_prefix = "${local.project_name}-atlantis"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port       = 4141
    to_port         = 4141
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
    Name = "${local.project_name}-atlantis"
  })
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${local.project_name}-alb"
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
    Name = "${local.project_name}-alb"
  })
}

# Application Load Balancer
resource "aws_lb" "atlantis" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids
  
  enable_deletion_protection = false
  
  tags = local.common_tags
}

# Target group for Atlantis
resource "aws_lb_target_group" "atlantis" {
  name     = "${local.project_name}-tg"
  port     = 4141
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
  }
  
  tags = local.common_tags
}

# ALB Listener
resource "aws_lb_listener" "atlantis" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }
}

# CloudWatch log group for ECS
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/atlantis-${var.org_name}"
  retention_in_days = 7
  
  tags = local.common_tags
}
EOF

    # Outputs
    cat > "${STACK_DIR}/outputs.tf" << 'EOF'
output "atlantis_url" {
  description = "Atlantis server URL"
  value       = "http://${aws_lb.atlantis.dns_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket for plan artifacts"
  value       = module.plan_artifacts.bucket_id
}

output "ai_reviewer_function_name" {
  description = "AI Reviewer Lambda function name"
  value       = module.ai_reviewer.function_name
}

output "vpc_id" {
  description = "VPC ID for Atlantis infrastructure"
  value       = module.vpc.vpc_id
}

output "webhook_endpoint" {
  description = "GitHub webhook endpoint"
  value       = "http://${aws_lb.atlantis.dns_name}/events"
}
EOF

    # Terraform variables file
    cat > "${STACK_DIR}/terraform.tfvars" << EOF
org_name    = "${ORG_NAME}"
region      = "${AWS_REGION}"
environment = "central"

github_token_secret_arn    = "arn:aws:secretsmanager:${AWS_REGION}:\$(aws sts get-caller-identity --query Account --output text):secret:atlantis/${ORG_NAME}/github-token"
openai_api_key_secret_arn  = "arn:aws:secretsmanager:${AWS_REGION}:\$(aws sts get-caller-identity --query Account --output text):secret:atlantis/${ORG_NAME}/openai-api-key"
slack_webhook_secret_arn   = "arn:aws:secretsmanager:${AWS_REGION}:\$(aws sts get-caller-identity --query Account --output text):secret:atlantis/${ORG_NAME}/slack-webhook"

repo_allowlist = "${REPO_ALLOWLIST}"
domain_name    = "${DOMAIN_NAME}"

common_tags = {
  Organization = "${ORG_NAME}"
  Purpose      = "atlantis-central"
  CreatedBy    = "stackkit-setup"
}
EOF

    log_success "Terraform 스택이 ${STACK_DIR}에 생성되었습니다"
}

create_ai_reviewer_code() {
    log_info "AI Reviewer Lambda 코드 생성 중..."
    
    AI_REVIEWER_DIR="ai-reviewer-src"
    mkdir -p "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/handlers"
    mkdir -p "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/model"
    mkdir -p "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/util"
    
    # Maven POM
    cat > "${AI_REVIEWER_DIR}/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.stackkit</groupId>
    <artifactId>ai-reviewer</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>com.amazonaws</groupId>
            <artifactId>aws-lambda-java-core</artifactId>
            <version>1.2.2</version>
        </dependency>
        <dependency>
            <groupId>com.amazonaws</groupId>
            <artifactId>aws-lambda-java-events</artifactId>
            <version>3.11.1</version>
        </dependency>
        <dependency>
            <groupId>software.amazon.awssdk</groupId>
            <artifactId>s3</artifactId>
            <version>2.20.26</version>
        </dependency>
        <dependency>
            <groupId>software.amazon.awssdk</groupId>
            <artifactId>secretsmanager</artifactId>
            <version>2.20.26</version>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.15.1</version>
        </dependency>
        <dependency>
            <groupId>org.apache.httpcomponents</groupId>
            <artifactId>httpclient</artifactId>
            <version>4.5.14</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.4.1</version>
                <configuration>
                    <createDependencyReducedPom>false</createDependencyReducedPom>
                </configuration>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF

    # Main Handler class
    cat > "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/handlers/UnifiedReviewerHandler.java" << 'EOF'
package com.stackkit.plan.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.stackkit.plan.model.PlanManifest;
import com.stackkit.plan.util.Common;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class UnifiedReviewerHandler implements RequestHandler<S3Event, String> {
    
    private final S3Client s3Client;
    private final SecretsManagerClient secretsClient;
    private final ObjectMapper objectMapper;
    
    public UnifiedReviewerHandler() {
        String region = System.getenv("AWS_REGION");
        this.s3Client = S3Client.builder().region(Region.of(region)).build();
        this.secretsClient = SecretsManagerClient.builder().region(Region.of(region)).build();
        this.objectMapper = new ObjectMapper();
    }
    
    @Override
    public String handleRequest(S3Event event, Context context) {
        try {
            for (S3Event.S3EventNotificationRecord record : event.getRecords()) {
                String bucketName = record.getS3().getBucket().getName();
                String objectKey = record.getS3().getObject().getKey();
                
                if (!objectKey.endsWith("manifest.json")) {
                    continue;
                }
                
                // Download and parse manifest
                PlanManifest manifest = downloadManifest(bucketName, objectKey);
                
                if ("plan".equals(manifest.getAction())) {
                    // Download plan files
                    String planText = downloadPlanText(bucketName, objectKey);
                    String infracostJson = downloadInfracost(bucketName, objectKey);
                    
                    // Generate AI review
                    String aiReview = generateAIReview(manifest, planText, infracostJson);
                    
                    // Send to Slack
                    sendSlackNotification(manifest, aiReview);
                }
            }
            
            return "Success";
            
        } catch (Exception e) {
            context.getLogger().log("Error: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }
    
    private PlanManifest downloadManifest(String bucket, String objectKey) throws IOException {
        String prefix = objectKey.substring(0, objectKey.lastIndexOf("/"));
        String manifestKey = prefix + "/manifest.json";
        
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(bucket)
                .key(manifestKey)
                .build();
                
        try (ResponseInputStream<GetObjectResponse> response = s3Client.getObject(request)) {
            String content = new String(response.readAllBytes(), StandardCharsets.UTF_8);
            return objectMapper.readValue(content, PlanManifest.class);
        }
    }
    
    private String downloadPlanText(String bucket, String objectKey) throws IOException {
        String prefix = objectKey.substring(0, objectKey.lastIndexOf("/"));
        String planKey = prefix + "/plan.txt";
        
        try {
            GetObjectRequest request = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(planKey)
                    .build();
                    
            try (ResponseInputStream<GetObjectResponse> response = s3Client.getObject(request)) {
                return new String(response.readAllBytes(), StandardCharsets.UTF_8);
            }
        } catch (Exception e) {
            return "Plan text not available";
        }
    }
    
    private String downloadInfracost(String bucket, String objectKey) throws IOException {
        String prefix = objectKey.substring(0, objectKey.lastIndexOf("/"));
        String costKey = prefix + "/infracost.json";
        
        try {
            GetObjectRequest request = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(costKey)
                    .build();
                    
            try (ResponseInputStream<GetObjectResponse> response = s3Client.getObject(request)) {
                return new String(response.readAllBytes(), StandardCharsets.UTF_8);
            }
        } catch (Exception e) {
            return "{}";
        }
    }
    
    private String generateAIReview(PlanManifest manifest, String planText, String infracostJson) throws IOException {
        String openaiApiKey = getSecret(System.getenv("OPENAI_API_KEY_SECRET_ARN"));
        
        String prompt = String.format(
            "다음 Terraform Plan을 분석하고 한국어로 리뷰해주세요:\n\n" +
            "프로젝트: %s\n" +
            "레포지토리: %s\n" +
            "PR: #%d\n\n" +
            "Plan 내용:\n%s\n\n" +
            "비용 정보:\n%s\n\n" +
            "다음 형식으로 분석해주세요:\n" +
            "1. 주요 변경사항 요약\n" +
            "2. 보안 영향 평가\n" +
            "3. 비용 영향 분석\n" +
            "4. 권장사항\n" +
            "5. 승인/보류/거부 권장",
            manifest.getProject(),
            manifest.getRepo(),
            manifest.getPr(),
            planText.length() > 8000 ? planText.substring(0, 8000) + "..." : planText,
            infracostJson
        );
        
        return callOpenAI(openaiApiKey, prompt);
    }
    
    private String callOpenAI(String apiKey, String prompt) throws IOException {
        try (CloseableHttpClient httpClient = HttpClients.createDefault()) {
            HttpPost request = new HttpPost("https://api.openai.com/v1/chat/completions");
            
            request.setHeader("Content-Type", "application/json");
            request.setHeader("Authorization", "Bearer " + apiKey);
            
            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", "gpt-4");
            requestBody.put("messages", new Object[]{
                Map.of("role", "user", "content", prompt)
            });
            requestBody.put("max_tokens", 2000);
            requestBody.put("temperature", 0.3);
            
            String jsonBody = objectMapper.writeValueAsString(requestBody);
            request.setEntity(new StringEntity(jsonBody, StandardCharsets.UTF_8));
            
            try (CloseableHttpResponse response = httpClient.execute(request)) {
                String responseBody = EntityUtils.toString(response.getEntity());
                JsonNode jsonResponse = objectMapper.readTree(responseBody);
                
                return jsonResponse.path("choices").get(0).path("message").path("content").asText();
            }
        }
    }
    
    private void sendSlackNotification(PlanManifest manifest, String aiReview) throws IOException {
        String slackWebhook = getSecret(System.getenv("SLACK_WEBHOOK_SECRET_ARN"));
        
        String slackMessage = String.format(
            "🤖 *AI Review - %s*\n\n" +
            "*레포지토리:* %s\n" +
            "*PR:* #%d\n" +
            "*프로젝트:* %s\n" +
            "*상태:* %s\n\n" +
            "*AI 분석 결과:*\n```%s```",
            manifest.getAction().equals("plan") ? "Terraform Plan" : "Apply Result",
            manifest.getRepo(),
            manifest.getPr(), 
            manifest.getProject(),
            manifest.getStatus(),
            aiReview
        );
        
        try (CloseableHttpClient httpClient = HttpClients.createDefault()) {
            HttpPost request = new HttpPost(slackWebhook);
            request.setHeader("Content-Type", "application/json");
            
            Map<String, String> payload = new HashMap<>();
            payload.put("text", slackMessage);
            
            String jsonPayload = objectMapper.writeValueAsString(payload);
            request.setEntity(new StringEntity(jsonPayload, StandardCharsets.UTF_8));
            
            httpClient.execute(request);
        }
    }
    
    private String getSecret(String secretArn) {
        GetSecretValueRequest request = GetSecretValueRequest.builder()
                .secretId(secretArn)
                .build();
                
        return secretsClient.getSecretValue(request).secretString();
    }
}
EOF

    # Model classes
    cat > "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/model/PlanManifest.java" << 'EOF'
package com.stackkit.plan.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class PlanManifest {
    private String repo;
    private int pr;
    private String project;
    private String action;
    private String status;
    private String commit;
    
    @JsonProperty("has_changes")
    private boolean hasChanges;
    
    @JsonProperty("monthly_cost")
    private String monthlyCost;
    
    // Constructors
    public PlanManifest() {}
    
    // Getters and Setters
    public String getRepo() { return repo; }
    public void setRepo(String repo) { this.repo = repo; }
    
    public int getPr() { return pr; }
    public void setPr(int pr) { this.pr = pr; }
    
    public String getProject() { return project; }
    public void setProject(String project) { this.project = project; }
    
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    
    public String getCommit() { return commit; }
    public void setCommit(String commit) { this.commit = commit; }
    
    public boolean isHasChanges() { return hasChanges; }
    public void setHasChanges(boolean hasChanges) { this.hasChanges = hasChanges; }
    
    public String getMonthlyCost() { return monthlyCost; }
    public void setMonthlyCost(String monthlyCost) { this.monthlyCost = monthlyCost; }
}
EOF

    # Utility class
    cat > "${AI_REVIEWER_DIR}/src/main/java/com/stackkit/plan/util/Common.java" << 'EOF'
package com.stackkit.plan.util;

public class Common {
    
    public static String formatCurrency(String amount) {
        if (amount == null || amount.equals("0")) {
            return "$0";
        }
        
        try {
            double value = Double.parseDouble(amount);
            if (value < 1) {
                return String.format("$%.2f", value);
            } else {
                return String.format("$%.0f", value);
            }
        } catch (NumberFormatException e) {
            return amount;
        }
    }
    
    public static String truncateText(String text, int maxLength) {
        if (text == null || text.length() <= maxLength) {
            return text;
        }
        return text.substring(0, maxLength) + "...";
    }
}
EOF

    log_success "AI Reviewer Lambda 코드가 ${AI_REVIEWER_DIR}에 생성되었습니다"
}

build_ai_reviewer() {
    log_info "AI Reviewer Lambda 빌드 중..."
    
    cd "ai-reviewer-src"
    
    if ! command -v mvn &> /dev/null; then
        log_error "Maven이 설치되지 않았습니다"
        exit 1
    fi
    
    mvn clean package -q
    
    if [[ ! -f "target/ai-reviewer-1.0.0.jar" ]]; then
        log_error "Lambda 빌드에 실패했습니다"
        exit 1
    fi
    
    cp "target/ai-reviewer-1.0.0.jar" "../terraform/stacks/atlantis-central-${ORG_NAME}/ai-reviewer-${ORG_NAME}.zip"
    
    cd ..
    
    log_success "AI Reviewer Lambda 빌드 완료"
}

create_secrets() {
    log_info "AWS Secrets Manager에 시크릿 생성 중..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # GitHub Token
    aws secretsmanager create-secret \
        --name "atlantis/${ORG_NAME}/github-token" \
        --description "GitHub Personal Access Token for Atlantis" \
        --secret-string "${GITHUB_TOKEN}" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || \
    aws secretsmanager update-secret \
        --secret-id "atlantis/${ORG_NAME}/github-token" \
        --secret-string "${GITHUB_TOKEN}" \
        --region "${AWS_REGION}" >/dev/null
    
    # OpenAI API Key
    aws secretsmanager create-secret \
        --name "atlantis/${ORG_NAME}/openai-api-key" \
        --description "OpenAI API Key for AI Review" \
        --secret-string "${OPENAI_API_KEY}" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || \
    aws secretsmanager update-secret \
        --secret-id "atlantis/${ORG_NAME}/openai-api-key" \
        --secret-string "${OPENAI_API_KEY}" \
        --region "${AWS_REGION}" >/dev/null
    
    # Slack Webhook
    aws secretsmanager create-secret \
        --name "atlantis/${ORG_NAME}/slack-webhook" \
        --description "Slack Webhook URL for notifications" \
        --secret-string "${SLACK_WEBHOOK}" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || \
    aws secretsmanager update-secret \
        --secret-id "atlantis/${ORG_NAME}/slack-webhook" \
        --secret-string "${SLACK_WEBHOOK}" \
        --region "${AWS_REGION}" >/dev/null
    
    log_success "모든 시크릿이 생성/업데이트되었습니다"
}

deploy_infrastructure() {
    log_info "Terraform 인프라 배포 중..."
    
    STACK_DIR="terraform/stacks/atlantis-central-${ORG_NAME}"
    
    cd "${STACK_DIR}"
    
    # Initialize Terraform
    log_info "Terraform 초기화 중..."
    
    # Create S3 bucket and DynamoDB table if they don't exist
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_NAME="stackkit-tfstate-${AWS_REGION}-${ACCOUNT_ID}"
    
    aws s3 mb "s3://${BUCKET_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || true
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled >/dev/null 2>&1 || true
    
    aws dynamodb create-table \
        --table-name stackkit-tf-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}" >/dev/null 2>&1 || true
    
    # Substitute variables in backend config
    sed -i.bak "s/\$AWS_REGION/${AWS_REGION}/g; s/\$ACCOUNT_ID/${ACCOUNT_ID}/g" backend.hcl
    sed -i.bak "s/\$(aws sts get-caller-identity --query Account --output text)/${ACCOUNT_ID}/g" terraform.tfvars
    
    terraform init -backend-config=backend.hcl
    
    # Plan
    log_info "Terraform plan 실행 중..."
    terraform plan -out=tfplan
    
    # Apply
    log_info "Terraform apply 실행 중..."
    terraform apply tfplan
    
    # Get outputs
    ATLANTIS_URL=$(terraform output -raw atlantis_url)
    WEBHOOK_ENDPOINT=$(terraform output -raw webhook_endpoint)
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    
    cd - >/dev/null
    
    log_success "인프라 배포 완료!"
    log_success "Atlantis URL: ${ATLANTIS_URL}"
    log_success "Webhook 엔드포인트: ${WEBHOOK_ENDPOINT}"
    log_success "S3 버킷: ${S3_BUCKET}"
}

create_documentation() {
    log_info "문서 생성 중..."
    
    cat > "ATLANTIS_SETUP.md" << EOF
# 🤖 중앙 Atlantis + AI Reviewer 설정 완료

조직 **${ORG_NAME}**의 중앙 집중식 Atlantis + AI Reviewer 인프라가 구축되었습니다.

## 📋 배포된 리소스

### Atlantis 서버
- **URL**: \$(terraform output -raw atlantis_url)
- **Webhook 엔드포인트**: \$(terraform output -raw webhook_endpoint)
- **ECS 서비스**: 고가용성 2개 인스턴스

### AI Reviewer
- **Lambda 함수**: unified-reviewer-handler
- **S3 버킷**: Plan 아티팩트 저장소
- **EventBridge**: S3 → Lambda 트리거

### 보안
- **시크릿**: AWS Secrets Manager에 안전하게 저장
  - GitHub Token
  - OpenAI API Key  
  - Slack Webhook

## 🚀 프로젝트 레포 설정 방법

각 프로젝트 레포지토리에서 다음 단계를 수행하세요:

### 1. GitHub Webhook 설정
Repository → Settings → Webhooks → Add webhook:
- **Payload URL**: \`\$(terraform output -raw webhook_endpoint)\`
- **Content type**: \`application/json\`
- **Secret**: AWS Secrets Manager에서 \`atlantis/${ORG_NAME}/webhook-secret\` 값
- **Events**: Pull requests, Issue comments, Push

### 2. atlantis.yaml 추가
프로젝트 루트에 다음 파일 추가:

\`\`\`yaml
version: 3

parallel_plan: true
parallel_apply: true

projects:
  - name: \${PROJECT_NAME}-dev
    dir: terraform/stacks/\${PROJECT_NAME}/dev
    workflow: stackkit-dev
    autoplan:
      enabled: true
      when_modified: ["**/*.tf", "**/*.tfvars", "../../../modules/**"]
    terraform_version: v1.8.5

workflows:
  stackkit-dev:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-input=false", "-var-file", "dev.tfvars"]
        - run: |
            # Plan 결과를 S3에 업로드하여 AI 리뷰 트리거
            terraform show -json "\$PLANFILE" > tfplan.json
            terraform show "\$PLANFILE" > plan.txt
            
            # 비용 추정
            infracost breakdown --path . --format json --out-file infracost.json --terraform-plan-path "\$PLANFILE" || echo '{}' > infracost.json
            
            # 메타데이터 생성
            jq -n --arg repo "\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}" \\
                  --arg pr "\$PULL_NUM" \\
                  --arg proj "\$PROJECT_NAME" \\
                  --arg action "plan" \\
                  --arg status "success" \\
                  --arg commit "\$HEAD_COMMIT" \\
                  '{repo:\$repo,pr:(\$pr|tonumber),project:\$proj,action:\$action,status:\$status,commit:\$commit}' > manifest.json
            
            # S3 업로드
            BUCKET="\$(terraform output -raw s3_bucket_name)"
            PREFIX="atlantis/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/\${PULL_NUM}/\${PROJECT_NAME}"
            
            aws s3 cp tfplan.json "s3://\$BUCKET/\$PREFIX/tfplan.json"
            aws s3 cp plan.txt "s3://\$BUCKET/\$PREFIX/plan.txt"
            aws s3 cp infracost.json "s3://\$BUCKET/\$PREFIX/infracost.json"
            aws s3 cp manifest.json "s3://\$BUCKET/\$PREFIX/manifest.json"
    apply:
      steps:
        - run: terraform apply -input=false -no-color "\$PLANFILE"
\`\`\`

### 3. 프로젝트 설정 간편화

각 프로젝트에서 StackKit 모듈만 사용하여 빠르게 설정:

\`\`\`bash
# 프로젝트 레포로 이동
cd /path/to/your/project

# StackKit 설정 스크립트 실행
curl -sSL https://raw.githubusercontent.com/yourorg/stackkit/main/scripts/setup-project-repo.sh | bash -s -- \\
    --project-name my-web-app \\
    --atlantis-url \$(terraform output -raw atlantis_url)
\`\`\`

## 🔧 관리 방법

### Atlantis 서버 업데이트
\`\`\`bash
cd terraform/stacks/atlantis-central-${ORG_NAME}
terraform plan
terraform apply
\`\`\`

### 로그 확인
\`\`\`bash
# Atlantis 서버 로그
aws logs tail /ecs/atlantis-${ORG_NAME} --follow

# AI Reviewer 로그  
aws logs tail /aws/lambda/atlantis-${ORG_NAME}-central-unified-reviewer-handler --follow
\`\`\`

### 시크릿 업데이트
\`\`\`bash
# GitHub Token 업데이트
aws secretsmanager update-secret \\
    --secret-id "atlantis/${ORG_NAME}/github-token" \\
    --secret-string "new_token_here"

# OpenAI API Key 업데이트  
aws secretsmanager update-secret \\
    --secret-id "atlantis/${ORG_NAME}/openai-api-key" \\
    --secret-string "new_key_here"

# Slack Webhook 업데이트
aws secretsmanager update-secret \\
    --secret-id "atlantis/${ORG_NAME}/slack-webhook" \\
    --secret-string "new_webhook_here"
\`\`\`

## 📊 모니터링

### CloudWatch 대시보드
- Atlantis ECS 서비스 메트릭
- Lambda 실행 통계
- S3 업로드 통계

### Slack 알림
모든 Terraform Plan이 AI에 의해 자동 분석되어 Slack으로 전송됩니다:
- 🤖 변경사항 요약
- 💰 비용 영향 분석  
- 🔒 보안 영향 평가
- ✅ 승인/보류/거부 권장

## 🆘 문제 해결

### Atlantis 서버 접속 불가
\`\`\`bash
# ECS 서비스 상태 확인
aws ecs describe-services --cluster atlantis-${ORG_NAME}-central-atlantis --services atlantis

# ALB 상태 확인
aws elbv2 describe-target-health --target-group-arn \$(aws elbv2 describe-target-groups --names atlantis-${ORG_NAME}-central-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
\`\`\`

### AI 리뷰 작동 안함
\`\`\`bash
# Lambda 함수 상태 확인
aws lambda get-function --function-name atlantis-${ORG_NAME}-central-unified-reviewer-handler

# EventBridge 규칙 확인
aws events list-rules --name-prefix atlantis-${ORG_NAME}
\`\`\`

### 권한 문제
\`\`\`bash
# ECS 태스크 역할 확인
aws iam list-attached-role-policies --role-name atlantis-${ORG_NAME}-central-ecs-task-role

# Lambda 실행 역할 확인  
aws iam list-attached-role-policies --role-name atlantis-${ORG_NAME}-central-lambda-role
\`\`\`

---

✨ **축하합니다!** 중앙 집중식 Atlantis + AI Reviewer가 성공적으로 구축되었습니다.
이제 모든 프로젝트 레포지토리에서 안전하고 똑똑한 인프라 관리를 시작하세요!
EOF

    log_success "설정 완료 문서가 ATLANTIS_SETUP.md에 생성되었습니다"
}

main() {
    echo -e "${BLUE}🏗️ StackKit 중앙 Atlantis + AI Reviewer 설정${NC}"
    echo -e "${BLUE}================================================${NC}"
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
    log_info "- 조직: ${ORG_NAME}"
    log_info "- 관리할 레포: ${REPO_ALLOWLIST}"
    log_info "- AWS 리전: ${AWS_REGION}"
    log_info "- 도메인: ${DOMAIN_NAME:-없음}"
    echo
    
    if [[ "$AUTO_SETUP" == "false" ]]; then
        read -p "계속하시겠습니까? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "설정이 취소되었습니다"
            exit 0
        fi
    fi
    
    create_secrets
    create_terraform_stack  
    create_ai_reviewer_code
    build_ai_reviewer
    deploy_infrastructure
    create_documentation
    
    echo
    log_success "🎉 중앙 Atlantis + AI Reviewer 설정 완료!"
    log_success "📚 자세한 내용은 ATLANTIS_SETUP.md를 참조하세요"
    echo
    log_info "다음 단계:"
    log_info "1. 각 프로젝트 레포에 GitHub Webhook 설정"
    log_info "2. 프로젝트 레포에 atlantis.yaml 추가"  
    log_info "3. setup-project-repo.sh로 프로젝트별 StackKit 모듈 설정"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi