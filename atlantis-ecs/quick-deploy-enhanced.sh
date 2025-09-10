#!/bin/bash
set -euo pipefail

# 🚀 Enhanced Atlantis ECS Deployment with DevOps Best Practices
# DynamoDB 기반 동시성 제어, 자동 롤백, 모니터링 통합

# Import DevOps libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/deployment.sh"
source "$SCRIPT_DIR/lib/monitoring.sh"
source "$SCRIPT_DIR/lib/github.sh"

show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
 ___  _   _            _   _     
| _ \| |_| |__ _ _ _  _| |_(_)___ 
|   /|  _| / _` | ' \| _| (_-< 
|_|_\ \__|_\__,_|_||_|\__|_/__/ 
                               
🚀 Enhanced DevOps Deployment v2.0
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --org COMPANY --github-token TOKEN [OPTIONS]

🏗️  Enhanced StackKit Atlantis ECS 배포 (DevOps 개선 버전)

새로운 DevOps 기능:
    ✅ DynamoDB 기반 동시성 제어
    ✅ 자동 롤백 메커니즘 
    ✅ CloudWatch 메트릭 & 알림
    ✅ 배포 상태 추적
    ✅ 종합 모니터링 대시보드

필수 Arguments:
    --org COMPANY               조직/회사 이름
    --github-token TOKEN        GitHub Personal Access Token

DevOps 고급 옵션:
    --enable-monitoring         CloudWatch 모니터링 활성화 (기본: true)
    --notification-email EMAIL  알림 이메일 주소
    --auto-rollback             자동 롤백 활성화 (기본: true)  
    --deployment-timeout MIN    배포 타임아웃 (기본: 30분)
    --lock-table TABLE          배포 잠금용 DynamoDB 테이블
    --state-table TABLE         배포 상태 추적용 DynamoDB 테이블

기존 옵션들:
    --aws-region REGION         AWS 리전 (기본: ap-northeast-2)
    --environment ENV           환경 (기본: prod)
    --vpc-id VPC_ID             기존 VPC ID
    --state-bucket BUCKET       Terraform 상태 S3 버킷
    --infracost-key KEY         Infracost API 키
    --slack-webhook URL         Slack 웹훅 URL
    --dry-run                   배포 시뮬레이션만 수행

Examples:
    # 기본 배포 (모든 DevOps 기능 활성화)
    $0 --org mycompany --github-token ghp_xxx \\
       --notification-email admin@company.com

    # 프로덕션 배포 (고급 모니터링)
    $0 --org enterprise --github-token ghp_xxx \\
       --notification-email devops@enterprise.com \\
       --slack-webhook https://hooks.slack.com/... \\
       --deployment-timeout 45

    # 기존 인프라 활용 + 모니터링
    $0 --org acme --github-token ghp_xxx \\
       --vpc-id vpc-12345678 \\
       --state-bucket acme-terraform-state \\
       --enable-monitoring true
EOF
}

# Default values
ORG=""
GITHUB_TOKEN=""
TF_VERSION="1.7.5"
TF_STACK_REGION="${TF_STACK_REGION:-ap-northeast-2}"
TF_STACK_NAME="${TF_STACK_NAME:-}"
AWS_REGION="${TF_STACK_REGION}"
ENVIRONMENT="prod"

# DevOps enhanced options
ENABLE_MONITORING="true"
NOTIFICATION_EMAIL=""
AUTO_ROLLBACK="true"
DEPLOYMENT_TIMEOUT="30"
LOCK_TABLE=""
STATE_TABLE=""

# Existing options
VPC_ID=""
STATE_BUCKET=""
INFRACOST_KEY=""
SLACK_WEBHOOK=""
DRY_RUN="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --org) ORG="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --aws-region) AWS_REGION="$2"; shift 2 ;;
        --environment) ENVIRONMENT="$2"; shift 2 ;;
        --enable-monitoring) ENABLE_MONITORING="$2"; shift 2 ;;
        --notification-email) NOTIFICATION_EMAIL="$2"; shift 2 ;;
        --auto-rollback) AUTO_ROLLBACK="$2"; shift 2 ;;
        --deployment-timeout) DEPLOYMENT_TIMEOUT="$2"; shift 2 ;;
        --lock-table) LOCK_TABLE="$2"; shift 2 ;;
        --state-table) STATE_TABLE="$2"; shift 2 ;;
        --vpc-id) VPC_ID="$2"; shift 2 ;;
        --state-bucket) STATE_BUCKET="$2"; shift 2 ;;
        --infracost-key) INFRACOST_KEY="$2"; shift 2 ;;
        --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Validation
if [[ -z "$ORG" || -z "$GITHUB_TOKEN" ]]; then
    error_exit "필수 인수가 누락되었습니다. --help를 확인하세요."
fi

if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
    error_exit "GitHub 토큰이 올바르지 않습니다. 'ghp_'로 시작해야 합니다."
fi

# Default table names
LOCK_TABLE="${LOCK_TABLE:-stackkit-deployment-locks}"
STATE_TABLE="${STATE_TABLE:-stackkit-deployment-states}"
STATE_BUCKET="${STATE_BUCKET:-${ENVIRONMENT}-atlantis-state-${AWS_REGION}}"

show_banner

log_info "🏗️  Enhanced StackKit 배포 설정:"
echo "  조직: $ORG"
echo "  환경: $ENVIRONMENT"  
echo "  AWS 리전: $AWS_REGION"
echo "  Terraform 버전: $TF_VERSION"
echo ""
echo "DevOps 기능:"
echo "  모니터링: $ENABLE_MONITORING"
echo "  자동 롤백: $AUTO_ROLLBACK"
echo "  배포 타임아웃: ${DEPLOYMENT_TIMEOUT}분"
echo "  알림 이메일: ${NOTIFICATION_EMAIL:-"설정 안됨"}"
echo "  Slack 웹훅: $([ -n "$SLACK_WEBHOOK" ] && echo "설정됨" || echo "설정 안됨")"
echo ""
echo "Infrastructure:"
echo "  VPC: ${VPC_ID:-"신규 생성"}"
echo "  상태 버킷: $STATE_BUCKET"
echo "  잠금 테이블: $LOCK_TABLE"
echo "  상태 추적 테이블: $STATE_TABLE"
echo ""

if [[ "$DRY_RUN" == false ]]; then
    read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 취소되었습니다."
        exit 0
    fi
fi

# Move to prod directory
cd "$SCRIPT_DIR/prod" || error_exit "prod 디렉토리를 찾을 수 없습니다"

# Step 1: Prerequisites and setup
log_info "1/8 사전 요구사항 확인 및 설정 중..."

# Check required tools
check_prerequisites aws terraform jq

# Validate AWS credentials
AWS_ACCOUNT_ID=$(validate_aws_credentials)

# Setup DynamoDB tables for deployment control
if [[ "$DRY_RUN" == false ]]; then
    log_info "DevOps 테이블 설정 중..."
    
    # Create deployment locks table
    if ! aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws dynamodb create-table \
            --table-name "$LOCK_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$AWS_REGION" >/dev/null
        aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"
        log_success "배포 잠금 테이블 생성: $LOCK_TABLE"
    fi
    
    # Create deployment states table
    if ! aws dynamodb describe-table --table-name "$STATE_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws dynamodb create-table \
            --table-name "$STATE_TABLE" \
            --attribute-definitions \
                AttributeName=DeploymentID,AttributeType=S \
                AttributeName=StackName,AttributeType=S \
                AttributeName=Timestamp,AttributeType=S \
            --key-schema AttributeName=DeploymentID,KeyType=HASH \
            --global-secondary-indexes \
                IndexName=StackName-Timestamp-index,KeySchema="[{AttributeName=StackName,KeyType=HASH},{AttributeName=Timestamp,KeyType=RANGE}]",Projection="{ProjectionType=ALL}",ProvisionedThroughput="{ReadCapacityUnits=5,WriteCapacityUnits=5}" \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$AWS_REGION" >/dev/null
        aws dynamodb wait table-exists --table-name "$STATE_TABLE" --region "$AWS_REGION"
        log_success "배포 상태 추적 테이블 생성: $STATE_TABLE"
    fi
fi

# Step 2: S3 bucket for state with versioning and lifecycle
log_info "2/8 Terraform 상태 저장 설정 중..."

if [[ "$DRY_RUN" == false ]]; then
    if ! aws s3 ls "s3://$STATE_BUCKET" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws s3 mb "s3://$STATE_BUCKET" --region "$AWS_REGION"
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$STATE_BUCKET" \
            --versioning-configuration Status=Enabled
        
        # Set up lifecycle policy for cost optimization
        aws s3api put-bucket-lifecycle-configuration \
            --bucket "$STATE_BUCKET" \
            --lifecycle-configuration file://<(cat <<JSON
{
    "Rules": [
        {
            "ID": "StackKitStateManagement",
            "Status": "Enabled",
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "NoncurrentDays": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 365
            }
        }
    ]
}
JSON
        )
        
        log_success "S3 버킷 생성 (버전 관리 및 라이프사이클 정책 적용): $STATE_BUCKET"
    else
        log_success "기존 S3 버킷 사용: $STATE_BUCKET"
    fi
fi

# Step 3: Backend configuration
log_info "3/8 Terraform 백엔드 설정 중..."

cat > backend.hcl <<HCL
bucket         = "${STATE_BUCKET}"
key            = "atlantis-${ENVIRONMENT}.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${LOCK_TABLE}"
encrypt        = true
HCL

# Step 4: Secrets management
log_info "4/8 시크릿 관리 설정 중..."

SECRET_NAME="${ENVIRONMENT}-atlantis-secrets"
WEBHOOK_SECRET=$(generate_secure_string 32)

SECRET_VALUE=$(cat <<JSON
{
    "github_token": "${GITHUB_TOKEN}",
    "webhook_secret": "${WEBHOOK_SECRET}"$([ -n "$INFRACOST_KEY" ] && echo ", \"infracost_api_key\": \"${INFRACOST_KEY}\"")$([ -n "$SLACK_WEBHOOK" ] && echo ", \"slack_webhook_url\": \"${SLACK_WEBHOOK}\"")
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
fi

# Step 5: Generate enhanced terraform.tfvars
log_info "5/8 Enhanced Terraform 설정 생성 중..."

cat > terraform.tfvars <<HCL
# StackKit Enhanced Configuration
org_name     = "${ORG}"
environment  = "${ENVIRONMENT}"
aws_region   = "${AWS_REGION}"
stack_name   = "${ENVIRONMENT}-atlantis-stack"
secret_name  = "${SECRET_NAME}"

# GitHub 설정
git_username   = "${ORG}-atlantis"
repo_allowlist = [
    "github.com/${ORG}/*"
]

# 기존 인프라 사용 설정
use_existing_vpc   = $([ -n "$VPC_ID" ] && echo "true" || echo "false")
existing_vpc_id    = "${VPC_ID}"

# DevOps 기능 설정
enable_monitoring           = ${ENABLE_MONITORING}
enable_auto_rollback       = ${AUTO_ROLLBACK}
deployment_timeout_minutes = ${DEPLOYMENT_TIMEOUT}
deployment_lock_table      = "${LOCK_TABLE}"
deployment_state_table     = "${STATE_TABLE}"

# 알림 설정  
notification_email = "${NOTIFICATION_EMAIL}"
slack_webhook_url  = "${SLACK_WEBHOOK}"

# 고급 기능
enable_infracost = $([ -n "$INFRACOST_KEY" ] && echo "true" || echo "false")
HCL

log_success "Enhanced Terraform 설정 파일 생성 완료"

# Step 6: Monitoring setup
if [[ "$ENABLE_MONITORING" == "true" ]]; then
    log_info "6/8 모니터링 시스템 설정 중..."
    
    if [[ "$DRY_RUN" == false ]]; then
        # Setup comprehensive monitoring
        setup_comprehensive_monitoring "$ORG" "$NOTIFICATION_EMAIL" "$SLACK_WEBHOOK" "$AWS_REGION" "$ENVIRONMENT"
        log_success "모니터링 시스템 설정 완료"
    else
        log_info "[DRY RUN] 모니터링 시스템 설정 시뮬레이션"
    fi
else
    log_info "6/8 모니터링 설정 건너뜀 (비활성화됨)"
fi

# Step 7: Enhanced deployment with concurrency control and rollback
log_info "7/8 Enhanced Atlantis 배포 실행 중..."

deployment_start_time=$(date +%s)

if [[ "$DRY_RUN" == false ]]; then
    # Track deployment start
    send_deployment_log "$ORG" "INFO" "Starting enhanced deployment with DevOps features" "$AWS_REGION"
    
    # Execute deployment with all DevOps features
    if execute_deployment "$ORG" "$AWS_REGION" "$AUTO_ROLLBACK" "$STATE_BUCKET" "$LOCK_TABLE"; then
        deployment_end_time=$(date +%s)
        deployment_duration=$((deployment_end_time - deployment_start_time))
        
        # Send success metrics
        send_deployment_metrics "$ORG" "success" "$deployment_duration" "$AWS_REGION" "$ENVIRONMENT"
        send_terraform_state_metrics "$ORG" "$AWS_REGION" "$ENVIRONMENT"
        send_deployment_log "$ORG" "INFO" "Deployment completed successfully in ${deployment_duration}s" "$AWS_REGION"
        
        log_success "Enhanced 배포 완료! (${deployment_duration}초)"
    else
        deployment_end_time=$(date +%s)
        deployment_duration=$((deployment_end_time - deployment_start_time))
        
        # Send failure metrics
        send_deployment_metrics "$ORG" "failure" "$deployment_duration" "$AWS_REGION" "$ENVIRONMENT"
        send_deployment_log "$ORG" "ERROR" "Deployment failed after ${deployment_duration}s" "$AWS_REGION"
        
        error_exit "배포 실패"
    fi
    
    # Get deployment outputs
    ATLANTIS_URL=$(terraform output -raw atlantis_url 2>/dev/null || echo "http://pending")
    ALB_DNS=$(terraform output -raw atlantis_load_balancer_dns 2>/dev/null || echo "pending")
    WEBHOOK_ENDPOINT=$(terraform output -raw webhook_endpoint 2>/dev/null || echo "pending")
else
    log_info "[DRY RUN] Enhanced 배포 시뮬레이션 완료"
    ATLANTIS_URL="http://${ORG}-atlantis-${ENVIRONMENT}.example.com"
    ALB_DNS="${ORG}-atlantis-${ENVIRONMENT}-alb.${AWS_REGION}.elb.amazonaws.com"
    WEBHOOK_ENDPOINT="$ATLANTIS_URL/events"
fi

# Step 8: Post-deployment verification and reporting
log_info "8/8 배포 후 검증 및 보고서 생성 중..."

if [[ "$DRY_RUN" == false && "$ENABLE_MONITORING" == "true" ]]; then
    # Create monitoring dashboard
    dashboard_url=$(create_deployment_dashboard "$ORG" "$AWS_REGION" "$ENVIRONMENT")
    log_success "모니터링 대시보드 생성 완료"
fi

# Final report
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Enhanced Atlantis ECS 배포 완료!${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🌐 Atlantis URL:${NC} $ATLANTIS_URL"
echo -e "${BLUE}📋 GitHub 웹훅 URL:${NC} $WEBHOOK_ENDPOINT"
echo -e "${BLUE}📋 웹훅 시크릿:${NC} AWS Secrets Manager '$SECRET_NAME'"
echo ""
echo -e "${GREEN}🔧 DevOps 기능:${NC}"
echo "  ✅ DynamoDB 기반 동시성 제어"
echo "  ✅ 자동 롤백 메커니즘 ($AUTO_ROLLBACK)"
echo "  ✅ CloudWatch 모니터링 ($ENABLE_MONITORING)"
echo "  ✅ 배포 상태 추적"
echo "  ✅ 종합 알림 시스템"
echo ""
if [[ "$ENABLE_MONITORING" == "true" && -n "${dashboard_url:-}" ]]; then
    echo -e "${BLUE}📊 모니터링 대시보드:${NC} $dashboard_url"
fi
echo ""
echo -e "${BLUE}다음 단계:${NC}"
echo "1. GitHub 저장소에 웹훅 추가"
echo "2. 테스트 PR로 Atlantis 및 모니터링 검증"
echo "3. CloudWatch 대시보드에서 메트릭 확인"
if [[ -n "$NOTIFICATION_EMAIL" ]]; then
    echo "4. 이메일($NOTIFICATION_EMAIL)로 알림 설정 확인"
fi
echo ""
echo -e "${GREEN}Happy DevOps! 🚀${NC}"