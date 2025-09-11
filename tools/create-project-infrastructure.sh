#!/bin/bash
set -euo pipefail

# 🏗️ Project Infrastructure Setup Script
# 표준화된 프로젝트 인프라 레포지토리 생성

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

show_help() {
    cat << EOF
Usage: $0 --project PROJECT_NAME --team TEAM_NAME --org ORGANIZATION [OPTIONS]

🏗️  표준화된 프로젝트 인프라 레포지토리 생성

필수 Arguments:
    --project PROJECT_NAME      프로젝트 이름 (예: user-api, payment-service)
    --team TEAM_NAME           팀 이름 (예: backend, frontend, data)
    --org ORGANIZATION         조직 이름 (S3 버킷 네이밍에 사용)

선택 Arguments:
    --environments ENVS        환경 목록 (기본: "dev,staging,prod")
    --central-repo REPO        중앙 레포 URL (기본: github.com/company/stackkit-terraform)
    --module-version VERSION   사용할 모듈 버전 (기본: latest)
    --aws-region REGION        AWS 리전 (기본: ap-northeast-2)
    --output-dir DIR           출력 디렉토리 (기본: ./{project}-infrastructure)
    --copy-governance          거버넌스 도구 및 정책을 프로젝트에 복사

Examples:
    # 기본 프로젝트 생성
    $0 --project user-api --team backend --org mycompany

    # 커스텀 환경으로 생성
    $0 --project payment-service --team platform --org acme \\
       --environments "dev,staging,prod,dr" \\
       --module-version v1.2.0
    
    # 거버넌스 도구 포함 생성
    $0 --project user-service --team backend --org connectly --copy-governance

EOF
}

# Default values
PROJECT_NAME=""
TEAM_NAME=""
ORGANIZATION=""  # 조직명 (필수)
ENVIRONMENTS="dev,staging,prod"
CENTRAL_REPO="github.com/company/stackkit-terraform"
MODULE_VERSION="v1.0.0"
AWS_REGION="ap-northeast-2"
OUTPUT_DIR=""
COPY_GOVERNANCE=false  # 거버넌스 도구 복사 여부

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --team)
            TEAM_NAME="$2"
            shift 2
            ;;
        --org)
            ORGANIZATION="$2"
            shift 2
            ;;
        --environments)
            ENVIRONMENTS="$2"
            shift 2
            ;;
        --central-repo)
            CENTRAL_REPO="$2"
            shift 2
            ;;
        --module-version)
            MODULE_VERSION="$2"
            shift 2
            ;;
        --aws-region)
            AWS_REGION="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --copy-governance)
            COPY_GOVERNANCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            ;;
    esac
done

# Validation
if [[ -z "$PROJECT_NAME" ]]; then
    log_error "Project name is required (--project)"
fi

if [[ -z "$TEAM_NAME" ]]; then
    log_error "Team name is required (--team)"
fi

if [[ -z "$ORGANIZATION" ]]; then
    log_error "Organization name is required (--org)"
fi

# Set output directory
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_NAME}-infrastructure}"

log_info "Creating project infrastructure for: $PROJECT_NAME"
log_info "Team: $TEAM_NAME"
log_info "Environments: $ENVIRONMENTS"
log_info "Output directory: $OUTPUT_DIR"

# Create directory structure
create_directory_structure() {
    log_info "Creating directory structure..."
    
    mkdir -p "$OUTPUT_DIR"/{.github/workflows,environments,modules,scripts,docs}
    
    # Create environment directories
    IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"
    for env in "${ENV_ARRAY[@]}"; do
        env=$(echo "$env" | tr -d ' ')
        mkdir -p "$OUTPUT_DIR/environments/$env"
    done
    
    log_success "Directory structure created"
}

# Create .terraform-version file
create_terraform_version() {
    cat > "$OUTPUT_DIR/.terraform-version" << EOF
1.7.5
EOF
}

# Create .gitignore
create_gitignore() {
    cat > "$OUTPUT_DIR/.gitignore" << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
*.tfplan
.terraform/
.terraform.lock.hcl

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Secrets
*.pem
*.key
secrets.tfvars
*.secret

# Logs
*.log

# Temporary
.tmp/
tmp/
EOF
}

# Create README
create_readme() {
    cat > "$OUTPUT_DIR/README.md" << EOF
# ${PROJECT_NAME} Infrastructure

## 📋 프로젝트 정보
- **프로젝트**: ${PROJECT_NAME}
- **팀**: ${TEAM_NAME}
- **관리 도구**: Terraform v1.7.5
- **중앙 모듈**: ${CENTRAL_REPO}

## 🏗️ 디렉토리 구조
\`\`\`
${PROJECT_NAME}-infrastructure/
├── environments/          # 환경별 인프라 정의
│   ├── dev/              # 개발 환경
│   ├── staging/          # 스테이징 환경
│   └── prod/             # 프로덕션 환경
├── modules/              # 프로젝트 전용 모듈
├── scripts/              # 유틸리티 스크립트
└── docs/                 # 문서
\`\`\`

## 🚀 Quick Start

### 1. AWS 인증 설정
\`\`\`bash
aws configure --profile ${PROJECT_NAME}-dev
export AWS_PROFILE=${PROJECT_NAME}-dev
\`\`\`

### 2. 개발 환경 배포
\`\`\`bash
cd environments/dev
terraform init
terraform plan
terraform apply
\`\`\`

## 📚 환경별 배포

### Development
\`\`\`bash
cd environments/dev
terraform apply -var-file="terraform.tfvars"
\`\`\`

### Staging
\`\`\`bash
cd environments/staging
terraform apply -var-file="terraform.tfvars"
\`\`\`

### Production
\`\`\`bash
cd environments/prod
terraform apply -var-file="terraform.tfvars"
\`\`\`

## 🔧 모듈 사용

이 프로젝트는 중앙 모듈 저장소의 표준 모듈을 사용합니다:
- Repository: ${CENTRAL_REPO}
- Version: ${MODULE_VERSION}

## 📋 표준 태그

모든 리소스에는 다음 태그가 자동으로 적용됩니다:
- Project: ${PROJECT_NAME}
- Team: ${TEAM_NAME}
- Environment: {dev|staging|prod}
- ManagedBy: terraform
- CostCenter: ${TEAM_NAME}

## 🔒 보안 가이드라인

1. 절대 시크릿을 커밋하지 마세요
2. tfvars 파일에 민감한 정보 저장 금지
3. AWS Secrets Manager 또는 Parameter Store 사용

## 📞 지원

- Slack: #${TEAM_NAME}-infrastructure
- Wiki: https://wiki.company.com/terraform
EOF
}

# Create atlantis.yaml
create_atlantis_config() {
    cat > "$OUTPUT_DIR/atlantis.yaml" << EOF
version: 3
automerge: false
delete_source_branch_on_merge: true

projects:
EOF

    # Add project configuration for each environment
    IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"
    for env in "${ENV_ARRAY[@]}"; do
        env=$(echo "$env" | tr -d ' ')
        
        # Set stricter requirements for production
        if [[ "$env" == "prod" ]]; then
            apply_requirements="[approved, mergeable]"
            workflow="production"
        else
            apply_requirements="[approved]"
            workflow="default"
        fi
        
        cat >> "$OUTPUT_DIR/atlantis.yaml" << EOF
  - name: ${PROJECT_NAME}-${env}
    dir: environments/${env}
    workspace: default
    terraform_version: v1.7.5
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ${apply_requirements}
    workflow: ${workflow}

EOF
    done
    
    # Add workflows
    cat >> "$OUTPUT_DIR/atlantis.yaml" << 'EOF'
workflows:
  default:
    plan:
      steps:
        - init
        - plan
        
  production:
    plan:
      steps:
        - init
        - plan
        - run: echo "⚠️  Production deployment - requires additional approval"
    apply:
      steps:
        - run: echo "🚀 Deploying to production..."
        - apply
EOF
}

# Create environment configuration
create_environment_config() {
    local env=$1
    local env_dir="$OUTPUT_DIR/environments/$env"
    
    log_info "Creating configuration for $env environment..."
    
    # backend.tf - 환경별 버킷 네이밍 컨벤션 적용
    # 버킷명: {env}-{org}
    # DynamoDB: {env}-{org}-tf-lock
    cat > "$env_dir/backend.tf" << EOF
terraform {
  backend "s3" {
    bucket         = "${env}-${ORGANIZATION}"
    key            = "${PROJECT_NAME}/${env}/terraform.tfstate"
    region         = "${AWS_REGION}"
    encrypt        = true
    dynamodb_table = "${env}-${ORGANIZATION}-tf-lock"
  }
}
EOF
    
    # provider.tf
    cat > "$env_dir/provider.tf" << EOF
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}
EOF
    
    # variables.tf
    cat > "$env_dir/variables.tf" << EOF
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${AWS_REGION}"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "${env}"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "${PROJECT_NAME}"
}

variable "team_name" {
  description = "Team name"
  type        = string
  default     = "${TEAM_NAME}"
}
EOF
    
    # data.tf - Reference shared infrastructure (connectly-shared-infrastructure)
    cat > "$env_dir/data.tf" << EOF
# ${ORGANIZATION} 공유 인프라 참조
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "\${var.environment}-${ORGANIZATION}"
    key    = "${ORGANIZATION}-shared/\${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# 공유 인프라 리소스 사용 예시:
# vpc_id          = data.terraform_remote_state.shared.outputs.vpc_id
# subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids  
# cluster_id      = data.terraform_remote_state.shared.outputs.ecs_cluster_id
# security_groups = [data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id]
# kms_key_id      = data.terraform_remote_state.shared.outputs.kms_key_id
EOF
    
    # main.tf
    cat > "$env_dir/main.tf" << EOF
locals {
  name_prefix = "\${var.project_name}-\${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Team        = var.team_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = var.team_name
    Owner       = var.team_name
  }
}

# Example: Application Load Balancer
# module "alb" {
#   source = "git::https://${CENTRAL_REPO}.git//modules/networking/alb?ref=${MODULE_VERSION}"
#   
#   name               = "\${local.name_prefix}-alb"
#   vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
#   subnet_ids        = data.terraform_remote_state.shared.outputs.public_subnet_ids
#   security_groups   = [data.terraform_remote_state.shared.outputs.alb_security_group_id]
#   
#   tags = local.common_tags
# }

# Example: ECS Service
# module "ecs_service" {
#   source = "git::https://${CENTRAL_REPO}.git//modules/compute/ecs-service?ref=${MODULE_VERSION}"
#   
#   name               = "\${local.name_prefix}-service"
#   cluster_id        = data.terraform_remote_state.shared.outputs.ecs_cluster_id
#   vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
#   subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
#   security_groups   = [data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id]
#   
#   container_image   = "your-registry/\${var.project_name}:latest"
#   container_port    = 8080
#   
#   tags = local.common_tags
# }

# Example: RDS Database
# module "database" {
#   source = "git::https://${CENTRAL_REPO}.git//modules/database/rds?ref=${MODULE_VERSION}"
#   
#   identifier        = "\${local.name_prefix}-db"
#   engine            = "postgres"
#   engine_version    = "15.4"
#   instance_class    = var.environment == "prod" ? "db.t3.medium" : "db.t3.small"
#   
#   db_subnet_group_name   = data.terraform_remote_state.shared.outputs.rds_subnet_group_name
#   vpc_security_group_ids = [data.terraform_remote_state.shared.outputs.rds_security_group_id]
#   kms_key_id            = data.terraform_remote_state.shared.outputs.kms_key_id
#   
#   tags = local.common_tags
# }
EOF
    
    # outputs.tf
    cat > "$env_dir/outputs.tf" << EOF
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Add your resource outputs here
# output "alb_dns_name" {
#   description = "ALB DNS name"
#   value       = module.alb.dns_name
# }
EOF
    
    # terraform.tfvars
    cat > "$env_dir/terraform.tfvars" << EOF
# Environment: ${env}
# Project: ${PROJECT_NAME}
# Team: ${TEAM_NAME}

aws_region   = "${AWS_REGION}"
environment  = "${env}"
project_name = "${PROJECT_NAME}"
team_name    = "${TEAM_NAME}"

# Add environment-specific variables here
EOF
    
    log_success "Configuration for $env environment created"
}

# Create GitHub Actions workflow
create_github_workflow() {
    cat > "$OUTPUT_DIR/.github/workflows/terraform-deploy.yml" << 'EOF'
name: Terraform Deploy

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main
      - develop

env:
  TF_VERSION: "1.7.5"

jobs:
  validate:
    name: Validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        working-directory: environments/${{ matrix.environment }}
        run: terraform init -backend=false
      
      - name: Terraform Validate
        working-directory: environments/${{ matrix.environment }}
        run: terraform validate
      
      - name: tfsec Security Scan
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: environments/${{ matrix.environment }}
      
      - name: Checkov Security Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: environments/${{ matrix.environment }}
          framework: terraform
          soft_fail: true

  plan:
    name: Plan
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2
      
      - name: Terraform Init
        working-directory: environments/${{ matrix.environment }}
        run: terraform init
      
      - name: Terraform Plan
        id: plan
        working-directory: environments/${{ matrix.environment }}
        run: |
          terraform plan -out=tfplan
          terraform show -no-color tfplan > plan.txt
      
      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('environments/${{ matrix.environment }}/plan.txt', 'utf8');
            const output = `#### Terraform Plan - ${{ matrix.environment }}
            <details><summary>Show Plan</summary>
            
            \`\`\`terraform
            ${plan}
            \`\`\`
            
            </details>`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });
EOF
}

# Create validation script
create_validation_script() {
    cat > "$OUTPUT_DIR/scripts/validate.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Running Terraform validation..."

# Check Terraform format
echo "Checking Terraform format..."
if ! terraform fmt -check -recursive .; then
    echo -e "${RED}❌ Terraform files are not formatted${NC}"
    echo "Run 'terraform fmt -recursive' to fix"
    exit 1
fi

# Validate each environment
for env in environments/*/; do
    if [[ -d "$env" ]]; then
        echo "Validating $env..."
        cd "$env"
        terraform init -backend=false
        terraform validate
        cd - > /dev/null
    fi
done

echo -e "${GREEN}✅ All validations passed${NC}"
EOF
    chmod +x "$OUTPUT_DIR/scripts/validate.sh"
}

# Copy governance tools if requested
copy_governance_tools() {
    if [[ "$COPY_GOVERNANCE" == true ]]; then
        log_info "Copying governance tools and policies..."
        
        # Copy governance validator script
        if [[ -f "tools/governance-validator.sh" ]]; then
            cp tools/governance-validator.sh "$OUTPUT_DIR/scripts/"
            chmod +x "$OUTPUT_DIR/scripts/governance-validator.sh"
            log_success "Governance validator copied"
        else
            log_warning "governance-validator.sh not found, skipping..."
        fi
        
        # Copy OPA policies if they exist
        if [[ -d "terraform/policies" ]]; then
            cp -r terraform/policies "$OUTPUT_DIR/"
            log_success "OPA policies copied"
        fi
        
        # Create enhanced README with governance info
        cat >> "$OUTPUT_DIR/README.md" << EOF

## 🛡️ 거버넌스 및 규정 준수

이 프로젝트는 ${ORGANIZATION}의 표준 거버넌스 정책을 준수합니다.

### 로컬 검증
\`\`\`bash
# 거버넌스 규칙 검증
./scripts/governance-validator.sh ./environments/dev

# 모든 환경 검증
for env in dev staging prod; do
  ./scripts/governance-validator.sh ./environments/\$env
done
\`\`\`

### CI/CD 통합
GitHub Actions 파이프라인에서 자동으로 거버넌스 검증이 실행됩니다:
- Terraform 포맷 검사
- 보안 스캔 (tfsec, Checkov)
- 비용 추정
- 태그 검증
- 네이밍 규칙 검증

### 정책 위반 시 대응
정책 위반이 발견되면:
1. CI/CD 파이프라인이 자동으로 차단
2. 위반 사항을 수정 후 재푸시
3. 필요시 #platform-infrastructure 채널에서 지원 요청
EOF
        
        # Update GitHub Actions workflow to include governance
        cat >> "$OUTPUT_DIR/.github/workflows/terraform-deploy.yml" << 'EOF'
      
      - name: Governance Validation
        if: hashFiles('scripts/governance-validator.sh') != ''
        run: |
          chmod +x ./scripts/governance-validator.sh
          ./scripts/governance-validator.sh ./environments/${{ matrix.environment }}
          
      - name: Cost Estimation
        uses: infracost/infracost-gh-action@v0.16
        env:
          INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
        with:
          path: environments/${{ matrix.environment }}
          
EOF
        
        log_success "Enhanced project with governance tools"
    fi
}

# Create pre-commit configuration
create_precommit_config() {
    cat > "$OUTPUT_DIR/.pre-commit-config.yaml" << 'EOF'
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_tfsec
      
  - repo: local
    hooks:
      - id: no-secrets
        name: Check for secrets
        entry: scripts/check-secrets.sh
        language: script
        files: \.tf$|\.tfvars$
        
      - id: validate-tags
        name: Validate required tags
        entry: scripts/validate-tags.sh
        language: script
        files: \.tf$
EOF
}

# Main execution
main() {
    log_info "Starting project infrastructure setup..."
    
    # Create base structure
    create_directory_structure
    create_terraform_version
    create_gitignore
    create_readme
    create_atlantis_config
    
    # Create environment configurations
    IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"
    for env in "${ENV_ARRAY[@]}"; do
        env=$(echo "$env" | tr -d ' ')
        create_environment_config "$env"
    done
    
    # Create CI/CD and validation
    create_github_workflow
    create_validation_script
    create_precommit_config
    
    # Copy governance tools if requested
    copy_governance_tools
    
    log_success "Project infrastructure created successfully!"
    
    if [[ "$COPY_GOVERNANCE" == true ]]; then
        log_info "✅ Governance tools included - project is ready for standalone use"
        log_info "📋 Governance features:"
        echo "   - governance-validator.sh script"
        echo "   - OPA policies (if available)"
        echo "   - Enhanced CI/CD with security scans"
        echo "   - Cost estimation integration"
    fi
    
    log_info "📁 Generated at: $(pwd)/$OUTPUT_DIR"
    log_info "🔧 Next steps:"
    echo "  1. cd $OUTPUT_DIR"
    echo "  2. Review and customize configurations"
    if [[ "$COPY_GOVERNANCE" == true ]]; then
        echo "  3. Test governance: ./scripts/governance-validator.sh ./environments/dev"
        echo "  4. Initialize git and push to repository"
    else
        echo "  3. Initialize git and push to repository"
    fi
    echo ""
    log_info "🚀 Ready to deploy infrastructure!"
}

main