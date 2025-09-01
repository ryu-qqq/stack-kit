#!/bin/bash

# StackKit Modular Installation Script
# Downloads only necessary Terraform modules and creates project templates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKKIT_REPO_URL="https://github.com/your-org/stackkit"
STACKKIT_RAW_URL="https://raw.githubusercontent.com/your-org/stackkit/main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME=""
PROJECT_TYPE=""
TARGET_DIR=""
REGION="ap-northeast-2"
ENABLE_AI_REVIEWER=false
GITHUB_ACTIONS=true

show_usage() {
    cat << EOF
🚀 StackKit Modular Installation Script

Downloads only the Terraform modules you need and creates project templates.

Usage: $0 [options]

Options:
    -n, --name NAME         Project name (required)
    -t, --type TYPE         Project type: web-app, api, serverless, custom
    -d, --dir DIR           Target directory (default: ./PROJECT_NAME)
    -r, --region REGION     AWS region (default: ap-northeast-2)
    --ai-reviewer          Enable AI-Reviewer setup guide
    --no-github-actions    Skip GitHub Actions workflow creation
    -h, --help             Show this help

Project Types:
    web-app      Full-stack web application (VPC + ECS/EC2 + RDS + ALB)
    api          API backend service (VPC + ECS + RDS)
    serverless   Serverless application (Lambda + DynamoDB)
    custom       Custom selection of modules

Examples:
    # Create web application project
    $0 -n my-web-app -t web-app

    # Create serverless project with AI reviewer
    $0 -n my-api -t serverless --ai-reviewer

    # Custom project in specific directory
    $0 -n my-infra -t custom -d /path/to/project

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "terraform" "aws")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo
        echo "Please install the missing dependencies:"
        echo "  - curl: https://curl.se/"
        echo "  - terraform: https://terraform.io/"
        echo "  - aws cli: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -t|--type)
                PROJECT_TYPE="$2"
                shift 2
                ;;
            -d|--dir)
                TARGET_DIR="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            --ai-reviewer)
                ENABLE_AI_REVIEWER=true
                shift
                ;;
            --no-github-actions)
                GITHUB_ACTIONS=false
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
    
    # Validate required arguments
    if [[ -z "$PROJECT_NAME" ]]; then
        log_error "Project name is required (-n|--name)"
        show_usage
        exit 1
    fi
    
    if [[ -z "$PROJECT_TYPE" ]]; then
        # Interactive project type selection
        select_project_type
    fi
    
    # Set default target directory
    if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="./$PROJECT_NAME"
    fi
    
    # Validate project type
    case "$PROJECT_TYPE" in
        web-app|api|serverless|custom)
            ;;
        *)
            log_error "Invalid project type: $PROJECT_TYPE"
            log_error "Valid types: web-app, api, serverless, custom"
            exit 1
            ;;
    esac
}

# Interactive project type selection
select_project_type() {
    echo
    echo "Select project type:"
    echo "1) web-app      - Full-stack web application (VPC + ECS/EC2 + RDS + ALB)"
    echo "2) api          - API backend service (VPC + ECS + RDS)"
    echo "3) serverless   - Serverless application (Lambda + DynamoDB)"
    echo "4) custom       - Custom selection of modules"
    echo
    
    while true; do
        read -p "Enter choice (1-4): " choice
        case $choice in
            1) PROJECT_TYPE="web-app"; break ;;
            2) PROJECT_TYPE="api"; break ;;
            3) PROJECT_TYPE="serverless"; break ;;
            4) PROJECT_TYPE="custom"; break ;;
            *) echo "Invalid choice. Please enter 1-4." ;;
        esac
    done
    
    log_info "Selected project type: $PROJECT_TYPE"
}

# Create project directory structure
create_project_structure() {
    log_info "Creating project structure in $TARGET_DIR"
    
    mkdir -p "$TARGET_DIR"/{terraform/{modules,environments/{dev,staging,prod}},docs,scripts}
    
    log_success "Created project structure"
}

# Download Terraform modules
download_modules() {
    local modules_dir="$TARGET_DIR/terraform/modules"
    local modules=()
    
    # Determine required modules based on project type
    case "$PROJECT_TYPE" in
        web-app)
            modules=("vpc" "ec2" "ecs" "rds" "alb" "s3" "iam" "kms" "cloudwatch")
            ;;
        api)
            modules=("vpc" "ecs" "rds" "alb" "s3" "iam" "kms" "cloudwatch")
            ;;
        serverless)
            modules=("lambda" "dynamodb" "s3" "iam" "kms" "cloudwatch" "apigateway")
            ;;
        custom)
            select_custom_modules modules
            ;;
    esac
    
    log_info "Downloading Terraform modules..."
    
    for module in "${modules[@]}"; do
        log_info "  Downloading $module module..."
        mkdir -p "$modules_dir/$module"
        
        # Download module files using GitHub API or raw URLs
        download_module_files "$module" "$modules_dir/$module"
    done
    
    log_success "Downloaded ${#modules[@]} Terraform modules"
}

# Download individual module files
download_module_files() {
    local module_name="$1"
    local target_dir="$2"
    local module_path="terraform/modules/$module_name"
    
    # List of common Terraform files to download
    local files=("main.tf" "variables.tf" "outputs.tf" "versions.tf")
    
    for file in "${files[@]}"; do
        local url="$STACKKIT_RAW_URL/$module_path/$file"
        if curl -f -s -L "$url" -o "$target_dir/$file" 2>/dev/null; then
            log_info "    Downloaded $file"
        else
            log_warning "    $file not found for $module_name module"
        fi
    done
}

# Select custom modules interactively
select_custom_modules() {
    local -n modules_array=$1
    local available_modules=("vpc" "ec2" "ecs" "lambda" "rds" "dynamodb" "s3" "alb" "apigateway" "iam" "kms" "cloudwatch" "elasticache" "eventbridge")
    
    echo
    echo "Available modules:"
    for i in "${!available_modules[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${available_modules[$i]}"
    done
    echo
    
    while true; do
        read -p "Enter module numbers (space-separated, e.g., 1 3 5), or 'done' to finish: " input
        
        if [[ "$input" == "done" ]]; then
            break
        fi
        
        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#available_modules[@]}" ]; then
                module="${available_modules[$((num-1))]}"
                if [[ ! " ${modules_array[*]} " =~ " $module " ]]; then
                    modules_array+=("$module")
                    log_info "Added $module"
                fi
            else
                log_warning "Invalid module number: $num"
            fi
        done
        
        if [ ${#modules_array[@]} -gt 0 ]; then
            echo "Selected modules: ${modules_array[*]}"
        fi
    done
}

# Create project templates
create_project_templates() {
    log_info "Creating project templates..."
    
    create_main_tf
    create_variables_tf
    create_terraform_tfvars
    create_backend_config
    create_makefile
    
    log_success "Created project templates"
}

# Create main Terraform configuration
create_main_tf() {
    local main_tf="$TARGET_DIR/terraform/environments/dev/main.tf"
    
    cat > "$main_tf" << EOF
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configuration loaded from backend.hcl
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources for common resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local variables
locals {
  name_prefix = "\${var.project_name}-\${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

EOF

    # Add modules based on project type
    case "$PROJECT_TYPE" in
        web-app)
            cat >> "$main_tf" << 'EOF'
# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  name               = local.name_prefix
  cidr               = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"
  
  name                = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "../../modules/rds"
  
  name                = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  engine_version      = var.db_engine_version
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  
  tags = local.common_tags
}

# Application Load Balancer
module "alb" {
  source = "../../modules/alb"
  
  name               = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  
  tags = local.common_tags
}
EOF
            ;;
        api)
            cat >> "$main_tf" << 'EOF'
# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  name               = local.name_prefix
  cidr               = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"
  
  name                = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "../../modules/rds"
  
  name                = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  engine_version      = var.db_engine_version
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  
  tags = local.common_tags
}
EOF
            ;;
        serverless)
            cat >> "$main_tf" << 'EOF'
# Lambda Module
module "lambda" {
  source = "../../modules/lambda"
  
  name          = local.name_prefix
  function_name = var.lambda_function_name
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  
  tags = local.common_tags
}

# DynamoDB Module
module "dynamodb" {
  source = "../../modules/dynamodb"
  
  name           = local.name_prefix
  table_name     = var.dynamodb_table_name
  hash_key       = var.dynamodb_hash_key
  
  tags = local.common_tags
}

# API Gateway Module
module "apigateway" {
  source = "../../modules/apigateway"
  
  name              = local.name_prefix
  lambda_invoke_arn = module.lambda.invoke_arn
  
  tags = local.common_tags
}
EOF
            ;;
    esac
}

# Create variables configuration
create_variables_tf() {
    local variables_tf="$TARGET_DIR/terraform/environments/dev/variables.tf"
    
    cat > "$variables_tf" << EOF
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$PROJECT_NAME"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "$REGION"
}

EOF

    # Add project-specific variables
    case "$PROJECT_TYPE" in
        web-app|api)
            cat >> "$variables_tf" << 'EOF'
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "db_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}
EOF
            ;;
        serverless)
            cat >> "$variables_tf" << 'EOF'
variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "main"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.9"
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "index.handler"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "main-table"
}

variable "dynamodb_hash_key" {
  description = "DynamoDB hash key"
  type        = string
  default     = "id"
}
EOF
            ;;
    esac
}

# Create terraform.tfvars template
create_terraform_tfvars() {
    local tfvars="$TARGET_DIR/terraform/environments/dev/terraform.tfvars"
    
    cat > "$tfvars" << EOF
# Project Configuration
project_name = "$PROJECT_NAME"
environment  = "dev"
aws_region   = "$REGION"

EOF

    case "$PROJECT_TYPE" in
        web-app|api)
            cat >> "$tfvars" << 'EOF'
# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

# Database Configuration
db_engine_version    = "15.4"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
EOF
            ;;
        serverless)
            cat >> "$tfvars" << 'EOF'
# Lambda Configuration
lambda_function_name = "main"
lambda_runtime       = "python3.9"
lambda_handler       = "index.handler"

# DynamoDB Configuration
dynamodb_table_name = "main-table"
dynamodb_hash_key   = "id"
EOF
            ;;
    esac
}

# Create backend configuration
create_backend_config() {
    local backend_hcl="$TARGET_DIR/terraform/environments/dev/backend.hcl"
    
    cat > "$backend_hcl" << EOF
# S3 Backend Configuration for Terraform State
# 
# Before using this backend, ensure you have:
# 1. Created an S3 bucket for Terraform state
# 2. Enabled versioning on the bucket
# 3. Created a DynamoDB table for state locking
#
# Replace the values below with your actual resources

bucket         = "$PROJECT_NAME-terraform-state"
key            = "environments/dev/terraform.tfstate"
region         = "$REGION"
encrypt        = true
dynamodb_table = "$PROJECT_NAME-terraform-locks"

# Optional: Additional security settings
# kms_key_id     = "arn:aws:kms:region:account-id:key/key-id"
# sse_algorithm  = "aws:kms"
EOF
}

# Create Makefile for common operations
create_makefile() {
    local makefile="$TARGET_DIR/Makefile"
    
    cat > "$makefile" << 'EOF'
.PHONY: help init plan apply destroy validate format clean

# Default environment
ENV ?= dev
TF_DIR = terraform/environments/$(ENV)

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	@echo "Initializing Terraform for $(ENV) environment..."
	cd $(TF_DIR) && terraform init -backend-config=backend.hcl

plan: ## Create Terraform execution plan
	@echo "Creating Terraform plan for $(ENV) environment..."
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars

apply: ## Apply Terraform changes
	@echo "Applying Terraform changes for $(ENV) environment..."
	cd $(TF_DIR) && terraform apply -var-file=terraform.tfvars

destroy: ## Destroy Terraform resources
	@echo "Destroying Terraform resources for $(ENV) environment..."
	cd $(TF_DIR) && terraform destroy -var-file=terraform.tfvars

validate: ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	cd $(TF_DIR) && terraform validate

format: ## Format Terraform code
	@echo "Formatting Terraform code..."
	terraform fmt -recursive terraform/

clean: ## Clean Terraform files
	@echo "Cleaning Terraform files..."
	find terraform/ -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform/ -name "terraform.tfstate*" -exec rm -f {} + 2>/dev/null || true
	find terraform/ -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true

# Environment-specific targets
init-dev: ENV=dev
init-dev: init

plan-dev: ENV=dev
plan-dev: plan

apply-dev: ENV=dev
apply-dev: apply

init-staging: ENV=staging
init-staging: init

plan-staging: ENV=staging
plan-staging: plan

apply-staging: ENV=staging
apply-staging: apply

init-prod: ENV=prod
init-prod: init

plan-prod: ENV=prod
plan-prod: plan

apply-prod: ENV=prod
apply-prod: apply
EOF
}

# Create GitHub Actions workflows
create_github_actions() {
    if [[ "$GITHUB_ACTIONS" != true ]]; then
        return
    fi
    
    log_info "Creating GitHub Actions workflows..."
    
    local workflows_dir="$TARGET_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Terraform validation workflow
    create_terraform_validation_workflow "$workflows_dir"
    
    # Terraform deployment workflow
    create_terraform_deployment_workflow "$workflows_dir"
    
    log_success "Created GitHub Actions workflows"
}

# Create Terraform validation workflow
create_terraform_validation_workflow() {
    local workflows_dir="$1"
    local workflow_file="$workflows_dir/terraform-validation.yml"
    
    cat > "$workflow_file" << 'EOF'
name: 'Terraform Validation'

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-validation.yml'
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-validation.yml'

env:
  TF_VERSION: '1.5.0'
  AWS_REGION: 'ap-northeast-2'

jobs:
  validate:
    name: 'Validate Terraform'
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - name: 'Checkout'
      uses: actions/checkout@v4
    
    - name: 'Setup Terraform'
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: 'Configure AWS Credentials'
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: 'Terraform Format Check'
      run: terraform fmt -check -recursive terraform/
    
    - name: 'Terraform Init'
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform init -backend=false
    
    - name: 'Terraform Validate'
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform validate
    
    - name: 'Terraform Plan'
      if: matrix.environment == 'dev'
      run: |
        cd terraform/environments/${{ matrix.environment }}
        terraform init -backend-config=backend.hcl
        terraform plan -var-file=terraform.tfvars -no-color
      env:
        TF_IN_AUTOMATION: true

  security:
    name: 'Security Scan'
    runs-on: ubuntu-latest
    
    steps:
    - name: 'Checkout'
      uses: actions/checkout@v4
    
    - name: 'Run Checkov'
      uses: bridgecrewio/checkov-action@v12
      with:
        directory: terraform/
        framework: terraform
        output_format: sarif
        output_file_path: reports/results.sarif
        soft_fail: true
    
    - name: 'Upload SARIF file'
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: reports/results.sarif

  cost-estimation:
    name: 'Cost Estimation'
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
    - name: 'Checkout'
      uses: actions/checkout@v4
    
    - name: 'Setup Terraform'
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: 'Configure AWS Credentials'
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: 'Setup Infracost'
      uses: infracost/actions/setup@v2
      with:
        api-key: ${{ secrets.INFRACOST_API_KEY }}
    
    - name: 'Generate Infracost cost estimate baseline'
      run: |
        cd terraform/environments/dev
        terraform init -backend-config=backend.hcl
        infracost breakdown --path=. \
                            --format=json \
                            --out-file=/tmp/infracost-base.json
    
    - name: 'Generate Infracost diff'
      run: |
        cd terraform/environments/dev
        infracost diff --path=. \
                       --format=json \
                       --compare-to=/tmp/infracost-base.json \
                       --out-file=/tmp/infracost.json
    
    - name: 'Post Infracost comment'
      run: |
        infracost comment github --path=/tmp/infracost.json \
                                 --repo=$GITHUB_REPOSITORY \
                                 --github-token=${{ github.token }} \
                                 --pull-request=${{ github.event.pull_request.number }} \
                                 --behavior=update
EOF
}

# Create Terraform deployment workflow
create_terraform_deployment_workflow() {
    local workflows_dir="$1"
    local workflow_file="$workflows_dir/terraform-deployment.yml"
    
    cat > "$workflow_file" << 'EOF'
name: 'Terraform Deployment'

on:
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod
      action:
        description: 'Terraform action'
        required: true
        default: 'apply'
        type: choice
        options:
          - plan
          - apply
          - destroy

env:
  TF_VERSION: '1.5.0'
  AWS_REGION: 'ap-northeast-2'

jobs:
  deploy:
    name: 'Deploy Terraform'
    runs-on: ubuntu-latest
    
    environment: ${{ github.event.inputs.environment || 'dev' }}
    
    steps:
    - name: 'Checkout'
      uses: actions/checkout@v4
    
    - name: 'Setup Terraform'
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: 'Configure AWS Credentials'
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: 'Terraform Init'
      run: |
        cd terraform/environments/${{ github.event.inputs.environment || 'dev' }}
        terraform init -backend-config=backend.hcl
    
    - name: 'Terraform Plan'
      if: github.event.inputs.action != 'destroy'
      run: |
        cd terraform/environments/${{ github.event.inputs.environment || 'dev' }}
        terraform plan -var-file=terraform.tfvars -out=tfplan
      env:
        TF_IN_AUTOMATION: true
    
    - name: 'Terraform Apply'
      if: github.event.inputs.action == 'apply' || (github.event.inputs.action == '' && github.ref == 'refs/heads/main')
      run: |
        cd terraform/environments/${{ github.event.inputs.environment || 'dev' }}
        terraform apply tfplan
      env:
        TF_IN_AUTOMATION: true
    
    - name: 'Terraform Destroy'
      if: github.event.inputs.action == 'destroy'
      run: |
        cd terraform/environments/${{ github.event.inputs.environment || 'dev' }}
        terraform destroy -var-file=terraform.tfvars -auto-approve
      env:
        TF_IN_AUTOMATION: true
    
    - name: 'Upload Terraform Plan'
      if: github.event.inputs.action == 'plan'
      uses: actions/upload-artifact@v3
      with:
        name: terraform-plan-${{ github.event.inputs.environment || 'dev' }}
        path: terraform/environments/${{ github.event.inputs.environment || 'dev' }}/tfplan
EOF
}

# Create documentation
create_documentation() {
    log_info "Creating project documentation..."
    
    create_project_readme
    create_deployment_guide
    
    if [[ "$ENABLE_AI_REVIEWER" == true ]]; then
        create_ai_reviewer_guide
    fi
    
    log_success "Created project documentation"
}

# Create project README
create_project_readme() {
    local readme="$TARGET_DIR/README.md"
    
    cat > "$readme" << EOF
# $PROJECT_NAME

Terraform infrastructure project for $PROJECT_NAME using StackKit modules.

## Project Structure

\`\`\`
$PROJECT_NAME/
├── terraform/
│   ├── modules/           # StackKit Terraform modules
│   └── environments/      # Environment-specific configurations
│       ├── dev/
│       ├── staging/
│       └── prod/
├── .github/
│   └── workflows/         # GitHub Actions CI/CD
├── docs/                  # Documentation
├── scripts/               # Helper scripts
└── Makefile              # Common operations
\`\`\`

## Getting Started

### Prerequisites

- [Terraform](https://terraform.io/) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured
- S3 bucket for Terraform state
- DynamoDB table for state locking

### Quick Start

1. **Initialize Terraform**:
   \`\`\`bash
   make init-dev
   \`\`\`

2. **Plan deployment**:
   \`\`\`bash
   make plan-dev
   \`\`\`

3. **Deploy infrastructure**:
   \`\`\`bash
   make apply-dev
   \`\`\`

### Configuration

Edit \`terraform/environments/dev/terraform.tfvars\` to customize your deployment:

\`\`\`hcl
project_name = "$PROJECT_NAME"
environment  = "dev"
aws_region   = "$REGION"
# ... other variables
\`\`\`

## Project Type: $PROJECT_TYPE

EOF

    case "$PROJECT_TYPE" in
        web-app)
            cat >> "$readme" << 'EOF'
This project creates a full-stack web application infrastructure including:

- **VPC**: Virtual Private Cloud with public/private subnets
- **ECS**: Container orchestration for application hosting
- **RDS**: Managed database service
- **ALB**: Application Load Balancer for traffic distribution
- **S3**: Object storage for assets
- **CloudWatch**: Monitoring and logging

### Architecture

```
Internet → ALB → ECS (Private) → RDS (Private)
             ↓
           S3 Bucket
```
EOF
            ;;
        api)
            cat >> "$readme" << 'EOF'
This project creates an API backend infrastructure including:

- **VPC**: Virtual Private Cloud with public/private subnets  
- **ECS**: Container orchestration for API hosting
- **RDS**: Managed database service
- **ALB**: Application Load Balancer for API traffic
- **CloudWatch**: API monitoring and logging

### Architecture

```
Internet → ALB → ECS API (Private) → RDS (Private)
```
EOF
            ;;
        serverless)
            cat >> "$readme" << 'EOF'
This project creates a serverless application infrastructure including:

- **Lambda**: Serverless compute functions
- **DynamoDB**: NoSQL database service  
- **API Gateway**: HTTP API endpoints
- **S3**: Object storage
- **CloudWatch**: Function monitoring and logging

### Architecture

```
Internet → API Gateway → Lambda → DynamoDB
                          ↓
                       S3 Bucket
```
EOF
            ;;
    esac
    
    cat >> "$readme" << 'EOF'

## Available Commands

| Command | Description |
|---------|-------------|
| `make help` | Show available commands |
| `make init-{env}` | Initialize Terraform for environment |
| `make plan-{env}` | Create execution plan |
| `make apply-{env}` | Apply Terraform changes |
| `make destroy-{env}` | Destroy infrastructure |
| `make validate` | Validate Terraform configuration |
| `make format` | Format Terraform code |

## Environment Management

### Development
```bash
make init-dev && make apply-dev
```

### Staging  
```bash
make init-staging && make apply-staging
```

### Production
```bash
make init-prod && make apply-prod
```

## CI/CD Pipeline

The project includes GitHub Actions workflows for:

- **Validation**: Format, validate, and security scanning
- **Cost Estimation**: Infracost analysis on PRs
- **Deployment**: Automated deployment to environments

## Security

- Infrastructure scanning with Checkov
- AWS IAM least privilege principles
- Encrypted storage and transit
- VPC security groups and NACLs

## Contributing

1. Create feature branch
2. Make changes and test locally
3. Create pull request
4. Review CI/CD validation results
5. Merge after approval

## Support

For issues and questions:
- Check the [documentation](docs/)
- Review [troubleshooting guide](docs/TROUBLESHOOTING.md)
- Open GitHub issue
EOF
}

# Create deployment guide
create_deployment_guide() {
    local guide="$TARGET_DIR/docs/DEPLOYMENT.md"
    mkdir -p "$(dirname "$guide")"
    
    cat > "$guide" << EOF
# Deployment Guide

## Prerequisites Setup

### 1. AWS Prerequisites

Create S3 bucket for Terraform state:
\`\`\`bash
aws s3 mb s3://$PROJECT_NAME-terraform-state
aws s3api put-bucket-versioning \\
  --bucket $PROJECT_NAME-terraform-state \\
  --versioning-configuration Status=Enabled
\`\`\`

Create DynamoDB table for state locking:
\`\`\`bash
aws dynamodb create-table \\
  --table-name $PROJECT_NAME-terraform-locks \\
  --attribute-definitions AttributeName=LockID,AttributeType=S \\
  --key-schema AttributeName=LockID,KeyType=HASH \\
  --billing-mode PAY_PER_REQUEST
\`\`\`

### 2. Update Backend Configuration

Edit \`terraform/environments/dev/backend.hcl\`:
\`\`\`hcl
bucket         = "$PROJECT_NAME-terraform-state"
key            = "environments/dev/terraform.tfstate"
region         = "$REGION"
encrypt        = true
dynamodb_table = "$PROJECT_NAME-terraform-locks"
\`\`\`

## Deployment Steps

### Development Environment

1. **Initialize**:
   \`\`\`bash
   cd terraform/environments/dev
   terraform init -backend-config=backend.hcl
   \`\`\`

2. **Plan**:
   \`\`\`bash
   terraform plan -var-file=terraform.tfvars
   \`\`\`

3. **Apply**:
   \`\`\`bash
   terraform apply -var-file=terraform.tfvars
   \`\`\`

### Production Environment

1. **Copy configuration**:
   \`\`\`bash
   cp -r terraform/environments/dev terraform/environments/prod
   \`\`\`

2. **Update variables**:
   \`\`\`bash
   # Edit terraform/environments/prod/terraform.tfvars
   environment = "prod"
   # Update other production-specific values
   \`\`\`

3. **Deploy**:
   \`\`\`bash
   cd terraform/environments/prod
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   \`\`\`

## Troubleshooting

### Common Issues

1. **State bucket not found**:
   - Verify bucket name in backend.hcl
   - Check AWS permissions

2. **DynamoDB table error**:
   - Verify table name matches backend.hcl
   - Check table exists and permissions

3. **Resource already exists**:
   - Import existing resources or use different names
   - Check for resource naming conflicts

### Recovery

To recover from corrupted state:
\`\`\`bash
# Backup current state
terraform state pull > backup.tfstate

# Import existing resources if needed
terraform import aws_vpc.main vpc-xxxxxx

# Force unlock if needed
terraform force-unlock LOCK_ID
\`\`\`
EOF
}

# Create AI Reviewer setup guide (if enabled)
create_ai_reviewer_guide() {
    local guide="$TARGET_DIR/docs/AI_REVIEWER_SETUP.md"
    
    cat > "$guide" << 'EOF'
# AI-Powered Terraform Review Setup

This guide shows how to set up the StackKit AI Reviewer as a centralized service for reviewing Terraform changes across multiple projects.

## Architecture Overview

```
Multiple Projects → GitHub PR → AI Reviewer Service → OpenAI GPT-4 → Review Comments
```

## Prerequisites

- AWS Account with appropriate permissions
- OpenAI API key
- GitHub repository with Atlantis integration

## Option 1: Centralized AI Reviewer Service

Deploy the AI reviewer as a centralized service that can review multiple projects:

1. **Clone StackKit** (for AI reviewer deployment only):
   ```bash
   git clone https://github.com/your-org/stackkit.git stackkit-ai-reviewer
   cd stackkit-ai-reviewer
   ```

2. **Deploy AI Reviewer Stack**:
   ```bash
   cd terraform/stacks
   ./new-stack.sh ai-reviewer prod --template=atlantis-ai-reviewer
   cd ai-reviewer-prod-ap-northeast-2
   # Edit terraform.tfvars
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

3. **Configure GitHub Webhook**:
   - Add webhook to your repositories
   - URL: `https://your-ai-reviewer-alb-url/webhook`
   - Events: Pull requests, Issue comments

## Option 2: GitHub Actions Integration

Add AI review workflow to this project:

1. **Create Workflow File** `.github/workflows/ai-terraform-review.yml`:
   ```yaml
   name: 'AI Terraform Review'
   
   on:
     pull_request:
       paths:
         - 'terraform/**'
   
   jobs:
     ai-review:
       runs-on: ubuntu-latest
       steps:
       - uses: actions/checkout@v4
       - name: 'AI Review'
         uses: stackkit/ai-terraform-review@v1
         with:
           openai-api-key: ${{ secrets.OPENAI_API_KEY }}
           terraform-dir: 'terraform/environments/dev'
   ```

2. **Add Secrets**:
   - `OPENAI_API_KEY`: Your OpenAI API key

## AI Review Features

- 🛡️ Security analysis (IAM, security groups, encryption)
- 💰 Cost optimization recommendations
- 📋 Best practices validation
- 🔍 Change impact analysis

For detailed setup instructions, visit:
https://github.com/your-org/stackkit#ai-reviewer
EOF
}

# Show completion summary
show_completion_summary() {
    log_success "StackKit project created successfully!"
    
    echo
    echo "📁 Project Details:"
    echo "   Name: $PROJECT_NAME"
    echo "   Type: $PROJECT_TYPE"  
    echo "   Directory: $TARGET_DIR"
    echo "   Region: $REGION"
    echo
    
    echo "📋 Next Steps:"
    echo "   1. cd $TARGET_DIR"
    echo "   2. Review and update terraform/environments/dev/terraform.tfvars"
    echo "   3. Create S3 bucket and DynamoDB table for Terraform state"
    echo "   4. Update backend configuration in backend.hcl"
    echo "   5. Run 'make init-dev' to initialize Terraform"
    echo "   6. Run 'make plan-dev' to preview changes"
    echo "   7. Run 'make apply-dev' to deploy infrastructure"
    echo
    
    if [[ "$ENABLE_AI_REVIEWER" == true ]]; then
        echo "🤖 AI Reviewer:"
        echo "   - See docs/AI_REVIEWER_SETUP.md for setup instructions"
        echo "   - Deploy centralized service or use project-specific integration"
        echo
    fi
    
    if [[ "$GITHUB_ACTIONS" == true ]]; then
        echo "🚀 GitHub Actions:"
        echo "   - Terraform validation workflow created"
        echo "   - Cost estimation with Infracost (requires INFRACOST_API_KEY secret)"
        echo "   - Security scanning with Checkov"
        echo "   - Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY secrets"
        echo
    fi
    
    echo "📚 Documentation:"
    echo "   - README.md: Project overview and quick start"
    echo "   - docs/DEPLOYMENT.md: Detailed deployment guide"
    if [[ "$ENABLE_AI_REVIEWER" == true ]]; then
        echo "   - docs/AI_REVIEWER_SETUP.md: AI review setup guide"
    fi
    echo
    
    echo "🛠️ Available Commands:"
    echo "   make help          # Show all available commands"
    echo "   make init-dev      # Initialize development environment"
    echo "   make plan-dev      # Preview development changes"
    echo "   make apply-dev     # Deploy development environment"
    echo
}

# Main execution
main() {
    echo "🚀 StackKit Modular Installation Script"
    echo "======================================="
    echo
    
    parse_arguments "$@"
    check_dependencies
    create_project_structure
    download_modules
    create_project_templates
    create_github_actions
    create_documentation
    show_completion_summary
}

# Execute main function with all arguments
main "$@"
