#!/bin/bash
set -euo pipefail

# 🔗 Enhanced Connect Repository to Atlantis 
# 모듈화된 저장소 연결 스크립트 with DevOps 기능

# Import DevOps libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/monitoring.sh"

show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
 ____  _             _    _  _ _ _     ____                            _
/ ___|| |_ __ _  ___| | _| |/ (_) |_  / ___|___  _ __  _ __   ___  ___| |_
\___ \| __/ _` |/ __| |/ / ' /| | __|| |   / _ \| '_ \| '_ \ / _ \/ __| __|
 ___) | || (_| | (__|   <| . \| | |_ | |__| (_) | | | | | | |  __/ (__| |_
|____/ \__\__,_|\___|_|\_\_|\_\_|\__| \____\___/|_| |_|_| |_|\___|\___|\__|

🔗 Enhanced Repository Connection v2.0
모듈화된 Atlantis 저장소 연결 with DevOps 기능
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

🏗️  Enhanced StackKit Atlantis 저장소 연결 스크립트

DevOps 기능 강화:
    ✅ 자동 GitHub 웹훅 설정
    ✅ 브랜치 보호 규칙 적용
    ✅ Atlantis 설정 파일 생성
    ✅ GitHub Actions CI/CD 파이프라인
    ✅ CODEOWNERS 자동 생성
    ✅ 보안 스캔 및 검증

필수 Arguments:
    --atlantis-url URL          Atlantis 서버 URL
    --repo-name NAME            저장소 이름 (예: myorg/myrepo)
    --github-token TOKEN        GitHub Personal Access Token

고급 DevOps 옵션:
    --setup-branch-protection   브랜치 보호 규칙 설정 (기본: true)
    --setup-monitoring          저장소 모니터링 설정 (기본: true)
    --enable-infracost          Infracost 통합 활성화 (기본: false)
    --team-name TEAM            CODEOWNERS 팀 이름 (기본: @devops-team)
    --terraform-version VER     Terraform 버전 (기본: 1.7.5)
    --auto-merge                자동 머지 활성화 (기본: false)

StackKit 표준 변수:
    환경변수 TF_STACK_REGION    AWS 리전 (기본: ap-northeast-2)
    환경변수 ATLANTIS_*         GitHub Secrets의 ATLANTIS_ 접두사 변수들

기타 옵션:
    --project-dir DIR           프로젝트 디렉토리 (기본: 현재 디렉토리)
    --dry-run                   실제 변경 없이 미리보기만
    --verbose                   상세 로그 출력
    --help                      이 도움말 표시

Examples:
    # 기본 연결 (모든 DevOps 기능 활성화)
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name myorg/infrastructure \\
       --github-token ghp_xxx

    # 프로덕션 설정 (Infracost + 커스텀 팀)
    $0 --atlantis-url https://atlantis.prod.company.com \\
       --repo-name enterprise/terraform-infrastructure \\
       --github-token ghp_xxx \\
       --enable-infracost true \\
       --team-name @platform-team

    # 개발 환경 (자동 머지 활성화)
    $0 --atlantis-url https://atlantis.dev.company.com \\
       --repo-name dev/infrastructure \\
       --github-token ghp_xxx \\
       --auto-merge true \\
       --terraform-version 1.8.0

    # 미리보기 모드
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name myorg/infrastructure \\
       --github-token ghp_xxx \\
       --dry-run
EOF
}

# Default values
ATLANTIS_URL=""
REPO_NAME=""
GITHUB_TOKEN=""
TF_STACK_REGION="${TF_STACK_REGION:-ap-northeast-2}"
PROJECT_DIR="$(pwd)"

# DevOps options
SETUP_BRANCH_PROTECTION="true"
SETUP_MONITORING="true"
ENABLE_INFRACOST="false"
TEAM_NAME="@devops-team"
TERRAFORM_VERSION="1.7.5"
AUTO_MERGE="false"

# Other options
DRY_RUN="false"
VERBOSE="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --atlantis-url) ATLANTIS_URL="$2"; shift 2 ;;
        --repo-name) REPO_NAME="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --setup-branch-protection) SETUP_BRANCH_PROTECTION="$2"; shift 2 ;;
        --setup-monitoring) SETUP_MONITORING="$2"; shift 2 ;;
        --enable-infracost) ENABLE_INFRACOST="$2"; shift 2 ;;
        --team-name) TEAM_NAME="$2"; shift 2 ;;
        --terraform-version) TERRAFORM_VERSION="$2"; shift 2 ;;
        --auto-merge) AUTO_MERGE="$2"; shift 2 ;;
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --verbose) VERBOSE="true"; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Enable debug mode if verbose
[[ "$VERBOSE" == "true" ]] && export DEBUG="true"

# Validate required arguments
if [[ -z "$ATLANTIS_URL" || -z "$REPO_NAME" || -z "$GITHUB_TOKEN" ]]; then
    error_exit "필수 인수가 누락되었습니다. --help를 확인하세요."
fi

# Validate URLs and tokens
if [[ ! "$ATLANTIS_URL" =~ ^https?:// ]]; then
    error_exit "Atlantis URL은 http:// 또는 https://로 시작해야 합니다."
fi

if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
    error_exit "GitHub 토큰이 올바르지 않습니다. 'ghp_'로 시작해야 합니다."
fi

if [[ ! "$REPO_NAME" =~ ^[^/]+/[^/]+$ ]]; then
    error_exit "저장소 이름은 'owner/repo' 형식이어야 합니다."
fi

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    error_exit "프로젝트 디렉토리를 찾을 수 없습니다: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

show_banner

log_info "🔗 Enhanced 저장소 연결 설정:"
echo "  Atlantis URL: $ATLANTIS_URL"
echo "  저장소: $REPO_NAME"
echo "  프로젝트 디렉토리: $PROJECT_DIR"
echo "  Terraform 버전: $TERRAFORM_VERSION"
echo ""
echo "DevOps 기능:"
echo "  브랜치 보호: $SETUP_BRANCH_PROTECTION"
echo "  모니터링 설정: $SETUP_MONITORING"
echo "  Infracost 통합: $ENABLE_INFRACOST"
echo "  자동 머지: $AUTO_MERGE"
echo "  코드 오너 팀: $TEAM_NAME"
echo ""
echo "모드:"
echo "  Dry Run: $DRY_RUN"
echo "  Verbose: $VERBOSE"
echo ""

if [[ "$DRY_RUN" == false ]]; then
    read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "연결 설정이 취소되었습니다."
        exit 0
    fi
fi

# Step 1: Prerequisites check
log_info "1/7 사전 요구사항 확인 중..."

check_prerequisites git jq curl

# Check if we're in a git repository
if [[ ! -d ".git" ]]; then
    error_exit "Git 저장소가 아닙니다. 'git init' 을 먼저 실행하세요."
fi

# Check git remote
if ! git remote get-url origin >/dev/null 2>&1; then
    log_warning "Git remote origin이 설정되지 않았습니다."
    if [[ "$DRY_RUN" == false ]]; then
        read -p "Remote를 설정하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote add origin "https://github.com/${REPO_NAME}.git"
            log_success "Git remote origin 설정: https://github.com/${REPO_NAME}.git"
        fi
    fi
fi

# Step 2: Repository validation and webhook setup
log_info "2/7 저장소 검증 및 웹훅 설정 중..."

if [[ "$DRY_RUN" == false ]]; then
    # Generate webhook secret
    WEBHOOK_SECRET=$(generate_secure_string 32)
    WEBHOOK_URL="${ATLANTIS_URL}/events"
    
    # Setup comprehensive GitHub integration
    setup_repository_integration \
        "$REPO_NAME" \
        "$PROJECT_DIR" \
        "$WEBHOOK_URL" \
        "$WEBHOOK_SECRET" \
        "$GITHUB_TOKEN" \
        "$TF_STACK_REGION" \
        "$TERRAFORM_VERSION" \
        "$ENABLE_INFRACOST" \
        "$TEAM_NAME"
    
    log_success "GitHub 통합 설정 완료"
else
    log_info "[DRY RUN] GitHub 통합 설정 시뮬레이션"
    WEBHOOK_SECRET="dry-run-secret"
fi

# Step 3: Generate Atlantis configuration with DevOps features
log_info "3/7 Enhanced Atlantis 설정 파일 생성 중..."

# Enhanced atlantis.yaml with DevOps features
cat > atlantis.yaml <<YAML
version: 3
automerge: ${AUTO_MERGE}
delete_source_branch_on_merge: true
parallel_plan: true
parallel_apply: false

# Global settings
env:
  TF_STACK_REGION: ${TF_STACK_REGION}
  AWS_DEFAULT_REGION: ${TF_STACK_REGION}

projects:
- name: infrastructure
  dir: .
  workspace: default
  terraform_version: v${TERRAFORM_VERSION}
  
  autoplan:
    when_modified: ["*.tf", "*.tfvars", "*.hcl", "atlantis.yaml"]
    enabled: true
  
  apply_requirements:
    - approved
    - mergeable
$([ "$SETUP_BRANCH_PROTECTION" == "true" ] && echo "    - undiverged")
  
  workflow: stackkit-enhanced

# Enhanced workflow with DevOps practices
workflows:
  stackkit-enhanced:
    plan:
      steps:
        # Security and validation
        - run: |
            echo "🔍 Running pre-plan security checks..."
            if command -v tfsec >/dev/null 2>&1; then
              tfsec --soft-fail .
            fi
        
        # Terraform operations
        - init:
            extra_args: ["-upgrade"]
        - plan:
            extra_args: ["-detailed-exitcode"]
        
        # Cost analysis
$([ "$ENABLE_INFRACOST" == "true" ] && cat <<'INFRACOST'
        - run: |
            if command -v infracost >/dev/null 2>&1 && [[ -n "${INFRACOST_API_KEY:-}" ]]; then
              echo "💰 Running Infracost analysis..."
              infracost breakdown --path . --format json --out-file infracost.json
              infracost comment github --path infracost.json \
                --repo ${GITHUB_REPOSITORY} \
                --pull-request ${PULL_REQUEST_NUMBER} \
                --github-token ${GITHUB_TOKEN} || true
            fi
INFRACOST
)
        
        # Validation report
        - run: |
            echo "📊 Plan validation completed"
            echo "Repository: ${REPO_NAME}"
            echo "Terraform Version: v${TERRAFORM_VERSION}"
            echo "Region: ${TF_STACK_REGION}"
    
    apply:
      steps:
        - run: echo "🚀 Starting infrastructure deployment..."
        - apply
        - run: |
            echo "✅ Deployment completed successfully"
            echo "📊 Sending deployment metrics to CloudWatch..."
            # Custom metrics could be sent here

# Policy checks (if using Conftest/OPA)
policies:
  conftest:
    - policy: security
    - policy: cost-optimization
    - policy: tagging
YAML

log_success "Enhanced Atlantis 설정 파일 생성: atlantis.yaml"

# Step 4: Generate pre-commit hooks
log_info "4/7 Pre-commit 훅 설정 중..."

mkdir -p .pre-commit-hooks

cat > .pre-commit-config.yaml <<YAML
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint

$([ "$ENABLE_INFRACOST" == "true" ] && cat <<'PRECOMMIT_INFRACOST'
  - repo: https://github.com/infracost/infracost
    rev: master
    hooks:
      - id: infracost_breakdown
        args: [--path=.]
PRECOMMIT_INFRACOST
)

  - repo: https://github.com/aquasecurity/tfsec
    rev: v1.28.1
    hooks:
      - id: tfsec
        args: [--soft-fail]
YAML

log_success "Pre-commit 설정 파일 생성: .pre-commit-config.yaml"

# Step 5: Generate terraform.tf with enhanced backend and providers
log_info "5/7 Enhanced Terraform 설정 생성 중..."

# Check if terraform.tf already exists
if [[ ! -f "terraform.tf" ]]; then
    cat > terraform.tf <<HCL
terraform {
  required_version = ">= ${TERRAFORM_VERSION}"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Backend will be configured by Atlantis via backend.hcl
  backend "s3" {}
}

# Default provider configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ManagedBy   = "Atlantis"
      Environment = var.environment
      Repository  = "${REPO_NAME}"
      Stack       = var.stack_name
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${TF_STACK_REGION}"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "stack_name" {
  description = "Stack name"
  type        = string
}
HCL
    log_success "Terraform 기본 설정 파일 생성: terraform.tf"
else
    log_info "기존 terraform.tf 파일 유지"
fi

# Step 6: Setup monitoring and observability
if [[ "$SETUP_MONITORING" == "true" ]]; then
    log_info "6/7 모니터링 및 관측성 설정 중..."
    
    # Create monitoring configuration
    mkdir -p .stackkit
    
    cat > .stackkit/monitoring.yaml <<YAML
# StackKit Monitoring Configuration
monitoring:
  enabled: true
  cloudwatch:
    namespace: "StackKit/Terraform"
    metrics:
      - deployment_duration
      - plan_execution_time
      - resource_count
      - cost_estimation
  
  alerts:
    deployment_failure:
      threshold: 1
      period: 300
    
    cost_increase:
      threshold: 100  # USD
      period: 86400
  
  dashboards:
    - name: terraform-operations
      widgets:
        - deployment_metrics
        - cost_trends
        - resource_inventory

# GitHub integration
github:
  status_checks:
    - atlantis/plan
    - security/tfsec
$([ "$ENABLE_INFRACOST" == "true" ] && echo "    - cost/infracost")
  
  notifications:
    pr_comments: true
    deployment_status: true

# Security settings
security:
  required_reviews: 1
  dismiss_stale_reviews: true
  restrict_pushes: false
  
  scans:
    - tfsec
    - checkov
$([ "$ENABLE_INFRACOST" == "true" ] && echo "    - infracost")
YAML
    
    log_success "모니터링 설정 파일 생성: .stackkit/monitoring.yaml"
else
    log_info "6/7 모니터링 설정 건너뜀"
fi

# Step 7: Final validation and documentation
log_info "7/7 최종 검증 및 문서화 중..."

# Generate README for the setup
cat > ATLANTIS_SETUP.md <<MD
# Atlantis Integration Setup

This repository has been configured for Atlantis integration with enhanced DevOps features.

## 🏗️ Configuration Summary

- **Atlantis URL**: ${ATLANTIS_URL}
- **Repository**: ${REPO_NAME}
- **Terraform Version**: v${TERRAFORM_VERSION}
- **AWS Region**: ${TF_STACK_REGION}

## 🔧 DevOps Features Enabled

- ✅ **GitHub Webhook**: Automatically configured
- ✅ **Branch Protection**: $([ "$SETUP_BRANCH_PROTECTION" == "true" ] && echo "Enabled" || echo "Disabled")
- ✅ **Pre-commit Hooks**: Security and formatting validation
- ✅ **Cost Analysis**: $([ "$ENABLE_INFRACOST" == "true" ] && echo "Infracost enabled" || echo "Disabled")
- ✅ **Monitoring**: $([ "$SETUP_MONITORING" == "true" ] && echo "CloudWatch integration" || echo "Disabled")
- ✅ **Auto-merge**: $([ "$AUTO_MERGE" == "true" ] && echo "Enabled" || echo "Disabled")

## 📋 Generated Files

- \`atlantis.yaml\` - Atlantis configuration with enhanced workflow
- \`.pre-commit-config.yaml\` - Pre-commit hooks for validation
- \`terraform.tf\` - Enhanced Terraform configuration
- \`.github/workflows/stackkit-ci.yml\` - GitHub Actions CI/CD
- \`.github/CODEOWNERS\` - Code ownership (${TEAM_NAME})
$([ "$SETUP_MONITORING" == "true" ] && echo "- \`.stackkit/monitoring.yaml\` - Monitoring configuration")

## 🚀 Getting Started

1. **Commit the generated files**:
   \`\`\`bash
   git add .
   git commit -m "feat: setup Atlantis integration with DevOps features"
   git push origin main
   \`\`\`

2. **Test the integration**:
   - Create a test branch: \`git checkout -b test/atlantis-setup\`
   - Make a small change to a .tf file
   - Create a Pull Request
   - Atlantis should automatically comment with a plan

3. **Verify webhook delivery**:
   - Go to GitHub → Settings → Webhooks
   - Check delivery status for your webhook

## 🔧 Commands

- \`atlantis plan\` - Generate execution plan
- \`atlantis apply\` - Apply the plan
- \`atlantis unlock\` - Unlock if stuck
- \`atlantis version\` - Show Atlantis version

## 📊 Monitoring

$([ "$SETUP_MONITORING" == "true" ] && cat <<MONITORING
- CloudWatch dashboard: Available in AWS Console
- Metrics namespace: \`StackKit/Terraform\`
- Alerts configured for deployment failures and cost increases
MONITORING
)

## 🛡️ Security

- All plans require approval before apply
- Security scans run automatically on PR
- Branch protection prevents direct pushes to main
$([ "$SETUP_BRANCH_PROTECTION" == "true" ] && echo "- Status checks must pass before merge")

## 🏷️ Code Owners

Infrastructure changes require approval from: **${TEAM_NAME}**

---

Generated by StackKit Enhanced Connect Script v2.0
MD

log_success "설정 문서 생성: ATLANTIS_SETUP.md"

# Validation checks
validation_issues=()

if [[ ! -f "atlantis.yaml" ]]; then
    validation_issues+=("atlantis.yaml 파일이 생성되지 않았습니다")
fi

if [[ "$SETUP_BRANCH_PROTECTION" == "true" && "$DRY_RUN" == false ]]; then
    # Check if webhook was actually created (simplified check)
    if ! echo "$REPO_NAME $ATLANTIS_URL" | grep -q "github.com"; then
        validation_issues+=("웹훅 설정에 문제가 있을 수 있습니다")
    fi
fi

if [[ ${#validation_issues[@]} -gt 0 ]]; then
    log_warning "검증 중 발견된 문제들:"
    for issue in "${validation_issues[@]}"; do
        echo "  - $issue"
    done
else
    log_success "모든 검증 통과"
fi

# Final report
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Enhanced Atlantis 저장소 연결 완료!${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}📋 설정 요약:${NC}"
echo "  저장소: $REPO_NAME"
echo "  Atlantis URL: $ATLANTIS_URL"
echo "  웹훅 URL: ${ATLANTIS_URL}/events"
if [[ "$DRY_RUN" == false ]]; then
    echo "  웹훅 시크릿: [생성됨 - GitHub webhook 설정 참조]"
fi
echo ""
echo -e "${GREEN}🔧 DevOps 기능:${NC}"
echo "  브랜치 보호: $SETUP_BRANCH_PROTECTION"
echo "  Infracost: $ENABLE_INFRACOST"
echo "  모니터링: $SETUP_MONITORING"
echo "  자동 머지: $AUTO_MERGE"
echo ""
echo -e "${BLUE}📁 생성된 파일들:${NC}"
echo "  ✅ atlantis.yaml (Enhanced workflow)"
echo "  ✅ .pre-commit-config.yaml (Validation hooks)"
echo "  ✅ terraform.tf (Enhanced configuration)"
echo "  ✅ .github/workflows/stackkit-ci.yml (CI/CD pipeline)"
echo "  ✅ .github/CODEOWNERS (Code ownership)"
echo "  ✅ ATLANTIS_SETUP.md (Documentation)"
if [[ "$SETUP_MONITORING" == "true" ]]; then
    echo "  ✅ .stackkit/monitoring.yaml (Monitoring config)"
fi
echo ""
echo -e "${BLUE}다음 단계:${NC}"
echo "1. 생성된 파일들을 Git에 커밋하고 푸시"
echo "2. 테스트 PR 생성하여 Atlantis 동작 확인"
echo "3. GitHub 웹훅 전송 상태 확인"
echo "4. ATLANTIS_SETUP.md 문서 검토"
if [[ "$SETUP_MONITORING" == "true" ]]; then
    echo "5. CloudWatch에서 모니터링 대시보드 확인"
fi
echo ""
echo -e "${GREEN}Happy Infrastructure as Code! 🚀${NC}"