#!/bin/bash
set -euo pipefail

# 🚀 Atlantis ECS - 기존 인프라 활용 배포
# 기존 VPC, 서브넷, S3, DynamoDB 활용 가능한 간단 배포

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
 ___  _   _            _   _     
| _ \| |_| |__ _ _ _  _| |_(_)___ 
|   /|  _| / _` | ' \| _| (_-< 
|_|_\ \__|_\__,_|_||_|\__|_/__/ 
                               
🚀 기존 인프라 활용 - 5분 완성
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --org COMPANY --github-token TOKEN [OPTIONS]

🏗️  StackKit 표준 호환 Atlantis ECS 배포 스크립트

필수 Arguments:
    --org COMPANY               조직/회사 이름 (TF_STACK_NAME으로 대체 가능)
    --github-token TOKEN        GitHub Personal Access Token

StackKit 표준 변수 지원:
    환경변수 TF_STACK_REGION    AWS 리전 (기본: ap-northeast-2)
    환경변수 TF_STACK_NAME      스택 이름 (기본: org 이름 사용)
    환경변수 ATLANTIS_*         GitHub Secrets의 ATLANTIS_ 접두사 변수들
    환경변수 INFRACOST_API_KEY  Infracost API 키

선택 Arguments (기본값 사용 가능):
    --aws-region REGION         AWS 리전 (TF_STACK_REGION 우선)
    --environment ENV           환경 (기본: prod)
    --git-username USERNAME     Git 사용자명 (기본: STS에서 자동 탐지)
    
기존 인프라 활용 (선택사항):
    --vpc-id VPC_ID             기존 VPC ID (자동으로 서브넷 검색)
    --public-subnets "id1,id2"  기존 퍼블릭 서브넷 ID 목록
    --private-subnets "id1,id2" 기존 프라이빗 서브넷 ID 목록
    --state-bucket BUCKET       기존 Terraform 상태 S3 버킷
    --lock-table TABLE          기존 Terraform 락 DynamoDB 테이블

HTTPS 설정 (선택사항):
    --custom-domain DOMAIN      커스텀 도메인
    --certificate-arn ARN       SSL 인증서 ARN

고급 기능 (선택사항):
    --infracost-key KEY         Infracost API 키 (비용 분석)
    --slack-webhook URL         Slack 웹훅 URL (알림용)
    
기타:
    --dry-run                   실제 배포 없이 설정만 확인
    --help                      이 도움말 표시

Examples:
    # 최소 설정 (모든 인프라 신규 생성)
    $0 --org mycompany --github-token ghp_xxx

    # 기존 VPC 활용 (서브넷 자동 검색)
    $0 --org acme --github-token ghp_xxx \\
       --vpc-id vpc-12345678

    # 기존 S3/DynamoDB + HTTPS
    $0 --org enterprise --github-token ghp_xxx \\
       --state-bucket my-terraform-state \\
       --lock-table my-terraform-locks \\
       --custom-domain atlantis.enterprise.com \\
       --certificate-arn arn:aws:acm:...

    # Infracost 비용 분석 포함
    $0 --org mycompany --github-token ghp_xxx \\
       --infracost-key ico-xxx...
EOF
}

# Default values (StackKit 표준 호환)
ORG=""
GITHUB_TOKEN=""
TF_VERSION="1.7.5"
TF_STACK_REGION="${TF_STACK_REGION:-ap-northeast-2}"
TF_STACK_NAME="${TF_STACK_NAME:-}"
AWS_REGION="${TF_STACK_REGION}"
ENVIRONMENT="prod"
GIT_USERNAME=""

# StackKit 호환 - 환경변수에서 값 읽기 (GitHub Actions용)
ATLANTIS_AWS_ACCESS_KEY_ID="${ATLANTIS_AWS_ACCESS_KEY_ID:-}"
ATLANTIS_AWS_SECRET_ACCESS_KEY="${ATLANTIS_AWS_SECRET_ACCESS_KEY:-}"
ATLANTIS_GITHUB_TOKEN="${ATLANTIS_GITHUB_TOKEN:-$GITHUB_TOKEN}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
INFRACOST_API_KEY="${INFRACOST_API_KEY:-}"

# 기존 인프라 옵션
VPC_ID=""
PUBLIC_SUBNETS=""
PRIVATE_SUBNETS=""
STATE_BUCKET=""
LOCK_TABLE=""

# HTTPS 설정
CUSTOM_DOMAIN=""
CERTIFICATE_ARN=""

# 고급 기능
INFRACOST_KEY=""
SLACK_WEBHOOK=""

# 기타
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --org) ORG="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --aws-region) AWS_REGION="$2"; shift 2 ;;
        --environment) ENVIRONMENT="$2"; shift 2 ;;
        --git-username) GIT_USERNAME="$2"; shift 2 ;;
        --vpc-id) VPC_ID="$2"; shift 2 ;;
        --public-subnets) PUBLIC_SUBNETS="$2"; shift 2 ;;
        --private-subnets) PRIVATE_SUBNETS="$2"; shift 2 ;;
        --state-bucket) STATE_BUCKET="$2"; shift 2 ;;
        --lock-table) LOCK_TABLE="$2"; shift 2 ;;
        --custom-domain) CUSTOM_DOMAIN="$2"; shift 2 ;;
        --certificate-arn) CERTIFICATE_ARN="$2"; shift 2 ;;
        --infracost-key) INFRACOST_KEY="$2"; shift 2 ;;
        --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# StackKit 표준 호환 - 환경변수 우선 사용
if [[ -n "$TF_STACK_NAME" && -z "$ORG" ]]; then
    ORG="$TF_STACK_NAME"
    log_info "TF_STACK_NAME 환경변수 사용: $ORG"
fi

if [[ -n "$ATLANTIS_GITHUB_TOKEN" ]]; then
    GITHUB_TOKEN="$ATLANTIS_GITHUB_TOKEN"
    log_info "ATLANTIS_GITHUB_TOKEN 환경변수 사용"
fi

# Validation
if [[ -z "$ORG" || -z "$GITHUB_TOKEN" ]]; then
    log_error "필수 인수가 누락되었습니다."
    echo "💡 StackKit 표준: TF_STACK_NAME, ATLANTIS_GITHUB_TOKEN 환경변수도 사용 가능"
    show_help
    exit 1
fi

if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
    log_error "GitHub 토큰이 올바르지 않습니다. 'ghp_'로 시작해야 합니다."
    exit 1
fi

# 기본값 설정 - STS에서 사용자명 가져오기
if [[ -z "$GIT_USERNAME" ]]; then
    AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | sed 's/.*\///g' | sed 's/:.*//g')
    if [[ -n "$AWS_USER" && "$AWS_USER" != "None" ]]; then
        GIT_USERNAME="$AWS_USER"
        log_info "AWS STS에서 사용자명 자동 탐지: $GIT_USERNAME"
    else
        GIT_USERNAME="${ORG}-atlantis"
        log_info "기본 사용자명 사용: $GIT_USERNAME"
    fi
fi

# VPC ID가 있으면 기존 VPC 사용으로 간주
if [[ -n "$VPC_ID" ]]; then
    log_info "기존 VPC 사용: $VPC_ID"
fi

show_banner

log_info "🏗️  StackKit 표준 호환 배포 설정 확인:"
echo "  조직/스택명: $ORG"
echo "  환경: $ENVIRONMENT"  
echo "  AWS 리전 (TF_STACK_REGION): $AWS_REGION"
echo "  Git 사용자: $GIT_USERNAME"
echo "  Terraform 버전: $TF_VERSION"
if [[ -n "$INFRACOST_API_KEY" || -n "$INFRACOST_KEY" ]]; then
    echo "  Infracost: 활성화"
fi
if [[ -n "$SLACK_WEBHOOK_URL" || -n "$SLACK_WEBHOOK" ]]; then
    echo "  Slack 알림: 활성화"
fi
echo ""
echo "기존 인프라 활용:"
echo "  VPC: ${VPC_ID:-"신규 생성"}"
echo "  퍼블릭 서브넷: ${PUBLIC_SUBNETS:-"신규 생성"}"
echo "  프라이빗 서브넷: ${PRIVATE_SUBNETS:-"신규 생성"}"
echo "  S3 버킷: ${STATE_BUCKET:-"자동 생성"}"
echo "  DynamoDB: ${LOCK_TABLE:-"자동 생성"}"
echo ""
echo "HTTPS 설정:"
echo "  커스텀 도메인: ${CUSTOM_DOMAIN:-"없음 (ALB DNS 사용)"}"
echo "  SSL 인증서: ${CERTIFICATE_ARN:+"설정됨"}"
echo ""
echo "고급 기능:"
echo "  Infracost: $([ -n "$INFRACOST_KEY" ] || [ -n "$INFRACOST_API_KEY" ] && echo "활성화" || echo "비활성화")"
echo "  Slack 알림: $([ -n "$SLACK_WEBHOOK" ] || [ -n "$SLACK_WEBHOOK_URL" ] && echo "활성화" || echo "비활성화")"
echo "  Dry Run: $DRY_RUN"
echo ""

if [[ "$DRY_RUN" == false ]]; then
    read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 취소되었습니다."
        exit 0
    fi
fi

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/prod"  # prod 폴더로 이동

# Step 1: Check prerequisites
log_info "1/6 사전 요구사항 확인 중..."

missing_tools=()
for tool in aws terraform jq; do
    if ! command -v $tool &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "다음 도구들이 설치되어 있지 않습니다: ${missing_tools[*]}"
    echo "설치: brew install awscli terraform jq"
    exit 1
fi

# StackKit 표준 - AWS 자격 증명 설정 (GitHub Actions 환경변수 우선)
if [[ -n "$ATLANTIS_AWS_ACCESS_KEY_ID" && -n "$ATLANTIS_AWS_SECRET_ACCESS_KEY" ]]; then
    export AWS_ACCESS_KEY_ID="$ATLANTIS_AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$ATLANTIS_AWS_SECRET_ACCESS_KEY"
    log_info "GitHub Secrets에서 AWS 자격 증명 사용 (ATLANTIS_AWS_*)"
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
    log_error "AWS 자격 증명이 설정되지 않았습니다."
    echo "💡 설정 방법:"
    echo "  1. 로컬: aws configure"
    echo "  2. GitHub Secrets: ATLANTIS_AWS_ACCESS_KEY_ID, ATLANTIS_AWS_SECRET_ACCESS_KEY"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS 계정: $AWS_ACCOUNT_ID, 리전: $AWS_REGION"

# Step 2: Validate existing infrastructure
if [[ -n "$VPC_ID" ]]; then
    log_info "2/6 기존 VPC 검증 중..."
    
    if ! aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_error "VPC $VPC_ID를 찾을 수 없습니다."
        exit 1
    fi
    
    # 서브넷 자동 검색 (지정되지 않은 경우)
    if [[ -z "$PUBLIC_SUBNETS" || -z "$PRIVATE_SUBNETS" ]]; then
        log_info "서브넷 자동 검색 중..."
        
        # 퍼블릭 서브넷 검색 (IGW로 라우팅되는 서브넷)
        if [[ -z "$PUBLIC_SUBNETS" ]]; then
            PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' \
                --output text --region "$AWS_REGION" | tr '\t' ',')
        fi
        
        # 프라이빗 서브넷 검색
        if [[ -z "$PRIVATE_SUBNETS" ]]; then
            PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
                --output text --region "$AWS_REGION" | tr '\t' ',')
        fi
        
        log_info "검색된 퍼블릭 서브넷: $PUBLIC_SUBNETS"
        log_info "검색된 프라이빗 서브넷: $PRIVATE_SUBNETS"
    fi
    
    log_success "기존 VPC 검증 완료"
else
    log_info "2/6 신규 VPC 생성 예정"
fi

# Step 3: Setup S3 bucket for state
log_info "3/6 Terraform 상태 저장 설정 중..."

if [[ -n "$STATE_BUCKET" ]]; then
    # 기존 버킷 사용
    if ! aws s3 ls "s3://$STATE_BUCKET" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_error "지정된 S3 버킷을 찾을 수 없습니다: $STATE_BUCKET"
        exit 1
    fi
    log_success "기존 S3 버킷 사용: $STATE_BUCKET"
else
    # 새 버킷 생성
    STATE_BUCKET="${ENVIRONMENT}-atlantis-state-${AWS_REGION}"
    if ! aws s3 ls "s3://$STATE_BUCKET" --region "$AWS_REGION" >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == false ]]; then
            aws s3 mb "s3://$STATE_BUCKET" --region "$AWS_REGION"
            aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
            log_success "새 S3 버킷 생성: $STATE_BUCKET"
        else
            log_info "[DRY RUN] S3 버킷 생성 예정: $STATE_BUCKET"
        fi
    else
        log_success "기존 S3 버킷 사용: $STATE_BUCKET"
    fi
fi

# DynamoDB 테이블 설정
if [[ -n "$LOCK_TABLE" ]]; then
    # 기존 테이블 사용
    if ! aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_error "지정된 DynamoDB 테이블을 찾을 수 없습니다: $LOCK_TABLE"
        exit 1
    fi
    log_success "기존 DynamoDB 테이블 사용: $LOCK_TABLE"
else
    # 새 테이블 생성
    LOCK_TABLE="${ENVIRONMENT}-atlantis-lock"
    if ! aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == false ]]; then
            aws dynamodb create-table \
                --table-name "$LOCK_TABLE" \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region "$AWS_REGION" >/dev/null
            aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"
            log_success "새 DynamoDB 테이블 생성: $LOCK_TABLE"
        else
            log_info "[DRY RUN] DynamoDB 테이블 생성 예정: $LOCK_TABLE"
        fi
    else
        log_success "기존 DynamoDB 테이블 사용: $LOCK_TABLE"
    fi
fi

# Step 4: Generate backend config
log_info "4/6 Terraform 설정 생성 중..."

cat > backend.hcl <<HCL
bucket         = "${STATE_BUCKET}"
key            = "atlantis-${ENVIRONMENT}.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${LOCK_TABLE}"
encrypt        = true
HCL

# Step 5: Store secrets
log_info "5/6 비밀 정보 저장 중..."

SECRET_NAME="${ENVIRONMENT}-atlantis-secrets"
WEBHOOK_SECRET=$(openssl rand -hex 32)

SECRET_VALUE=$(cat <<JSON
{
    "github_token": "${GITHUB_TOKEN}",
    "webhook_secret": "${WEBHOOK_SECRET}"$([ -n "$INFRACOST_KEY" ] || [ -n "$INFRACOST_API_KEY" ] && echo ", \"infracost_api_key\": \"${INFRACOST_API_KEY:-$INFRACOST_KEY}\"")$([ -n "$SLACK_WEBHOOK" ] || [ -n "$SLACK_WEBHOOK_URL" ] && echo ", \"slack_webhook_url\": \"${SLACK_WEBHOOK_URL:-$SLACK_WEBHOOK}\"")
}
JSON
)


if [[ "$DRY_RUN" == false ]]; then
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws secretsmanager update-secret --secret-id "$SECRET_NAME" --secret-string "$SECRET_VALUE" --region "$AWS_REGION" >/dev/null
    else
        aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$SECRET_VALUE" --region "$AWS_REGION" >/dev/null
    fi
    log_success "시크릿 저장 완료: $SECRET_NAME"
else
    log_info "[DRY RUN] 시크릿 저장 예정: $SECRET_NAME"
fi

# Generate terraform.tfvars
cat > terraform.tfvars <<HCL
# 기본 설정
org_name     = "${ORG}"
environment  = "${ENVIRONMENT}"
aws_region   = "${AWS_REGION}"
stack_name   = "${ENVIRONMENT}-atlantis-stack"
secret_name  = "${SECRET_NAME}"

# GitHub 설정
git_username   = "${GIT_USERNAME}"
repo_allowlist = [
    "github.com/${ORG}/*"
]

# 기존 인프라 사용 설정
use_existing_vpc             = $([ -n "$VPC_ID" ] && echo "true" || echo "false")
existing_vpc_id              = "${VPC_ID}"
existing_public_subnet_ids   = [$([ -n "$PUBLIC_SUBNETS" ] && echo "\"${PUBLIC_SUBNETS//,/\", \"}\"")]
existing_private_subnet_ids  = [$([ -n "$PRIVATE_SUBNETS" ] && echo "\"${PRIVATE_SUBNETS//,/\", \"}\"")]
existing_state_bucket        = "${STATE_BUCKET}"
existing_lock_table          = "${LOCK_TABLE}"

# HTTPS 설정
custom_domain   = "${CUSTOM_DOMAIN}"
certificate_arn = "${CERTIFICATE_ARN}"

# 고급 기능
enable_infracost = $([ -n "$INFRACOST_KEY" ] || [ -n "$INFRACOST_API_KEY" ] && echo "true" || echo "false")
HCL

log_success "Terraform 설정 파일 생성 완료"

# Step 6: Deploy infrastructure  
log_info "6/6 Atlantis 인프라 배포 중..."

if [[ "$DRY_RUN" == false ]]; then
    terraform init -backend-config=backend.hcl >/dev/null
    terraform plan -out=tfplan >/dev/null

    if terraform apply -auto-approve tfplan; then
        log_success "배포 완료!"
    else
        log_error "배포 실패"
        exit 1
    fi

    # Get outputs
    ATLANTIS_URL=$(terraform output -raw atlantis_url 2>/dev/null || echo "http://pending")
    ALB_DNS=$(terraform output -raw atlantis_load_balancer_dns 2>/dev/null || echo "pending")
    WEBHOOK_ENDPOINT=$(terraform output -raw webhook_endpoint 2>/dev/null || echo "pending")
else
    log_info "[DRY RUN] Terraform 배포 시뮬레이션 완료"
    ATLANTIS_URL="http://${ORG}-atlantis-${ENVIRONMENT}.example.com"
    ALB_DNS="${ORG}-atlantis-${ENVIRONMENT}-alb.${AWS_REGION}.elb.amazonaws.com"
    WEBHOOK_ENDPOINT="$ATLANTIS_URL/events"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Atlantis ECS 배포 완료!${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🌐 Atlantis URL:${NC} $ATLANTIS_URL"
if [[ -n "$CUSTOM_DOMAIN" ]]; then
    echo -e "${BLUE}📋 DNS 설정 필요:${NC} $CUSTOM_DOMAIN → $ALB_DNS"
fi
echo ""
echo -e "${BLUE}📋 GitHub 웹훅 설정:${NC}"
echo "  URL: $WEBHOOK_ENDPOINT"
echo "  시크릿: AWS Secrets Manager '$SECRET_NAME'에서 webhook_secret 확인"
echo ""
echo -e "${BLUE}다음 단계:${NC}"
echo "1. GitHub 레포지토리에 웹훅 추가"
echo "2. Atlantis 웹 UI 접속 확인"
echo "3. PR 생성하여 'atlantis plan' 테스트"
if [[ -n "$INFRACOST_KEY" ]]; then
    echo "4. PR에서 Infracost 비용 분석 결과 확인"
fi
echo ""
echo -e "${GREEN}Happy Infrastructure as Code! 🚀${NC}"