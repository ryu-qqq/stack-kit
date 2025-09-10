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

# Input validation functions
validate_aws_region() {
    local region="$1"
    if [[ ! "$region" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid AWS region format: $region"
        return 1
    fi
    return 0
}

validate_github_token() {
    local token="$1"
    if [[ ! "$token" =~ ^ghp_[A-Za-z0-9_]{36}$ ]]; then
        log_error "Invalid GitHub token format. Must be 'ghp_' followed by 36 characters."
        return 1
    fi
    return 0
}

validate_org_name() {
    local org="$1"
    if [[ ! "$org" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] || [[ ${#org} -gt 63 ]]; then
        log_error "Invalid organization name. Must be 2-63 alphanumeric characters with hyphens."
        return 1
    fi
    return 0
}

validate_vpc_id() {
    local vpc_id="$1"
    if [[ -n "$vpc_id" ]] && [[ ! "$vpc_id" =~ ^vpc-[0-9a-f]{8,17}$ ]]; then
        log_error "Invalid VPC ID format: $vpc_id"
        return 1
    fi
    return 0
}

# Interactive setup wizard
run_interactive_setup() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                 🧙‍♂️ StackKit 대화형 설정 마법사                ║"
    echo "║                     5분 안에 Atlantis 구축하기                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log_info "이 마법사가 단계별로 안내해드립니다. [Enter]를 누르면 기본값이 사용됩니다."
    echo ""
    
    # Step 1: Organization name
    while [[ -z "$ORG" ]]; do
        read -p "🏢 조직/회사 이름을 입력하세요 (예: mycompany): " input_org
        if [[ -n "$input_org" ]]; then
            if validate_org_name "$input_org"; then
                ORG="$input_org"
                log_success "조직명 설정: $ORG"
            else
                log_warning "올바른 조직명을 입력해주세요 (영숫자, 하이픈만 허용, 2-63자)"
            fi
        else
            log_warning "조직명은 필수입니다."
        fi
    done
    echo ""
    
    # Step 2: GitHub token
    while [[ -z "$GITHUB_TOKEN" ]]; do
        echo "🔑 GitHub Personal Access Token이 필요합니다."
        echo "   💡 https://github.com/settings/tokens 에서 생성 (repo, admin:repo_hook 권한 필요)"
        read -s -p "   GitHub 토큰을 입력하세요 (ghp_로 시작): " input_token
        echo ""
        if [[ -n "$input_token" ]]; then
            if validate_github_token "$input_token"; then
                GITHUB_TOKEN="$input_token"
                log_success "GitHub 토큰 설정 완료"
            else
                log_warning "올바른 GitHub 토큰 형식이 아닙니다 (ghp_ + 36자)"
            fi
        else
            log_warning "GitHub 토큰은 필수입니다."
        fi
    done
    echo ""
    
    # Step 3: AWS Region
    echo "🌏 AWS 리전을 선택하세요:"
    echo "   1) ap-northeast-2 (서울) [기본값]"
    echo "   2) us-east-1 (버지니아)"
    echo "   3) us-west-2 (오레곤)"
    echo "   4) eu-west-1 (아일랜드)"
    echo "   5) 직접 입력"
    read -p "   선택 (1-5): " region_choice
    
    case $region_choice in
        2) AWS_REGION="us-east-1" ;;
        3) AWS_REGION="us-west-2" ;;
        4) AWS_REGION="eu-west-1" ;;
        5)
            read -p "   AWS 리전을 입력하세요: " custom_region
            if [[ -n "$custom_region" ]] && validate_aws_region "$custom_region"; then
                AWS_REGION="$custom_region"
            else
                log_warning "잘못된 리전입니다. 기본값(ap-northeast-2)을 사용합니다."
                AWS_REGION="ap-northeast-2"
            fi
            ;;
        *) AWS_REGION="ap-northeast-2" ;;
    esac
    log_success "AWS 리전 설정: $AWS_REGION"
    echo ""
    
    # Step 4: Infrastructure options
    echo "🏗️ 인프라 옵션을 선택하세요:"
    echo "   1) 모든 인프라 신규 생성 (간단함, 4-5분 소요) [기본값]"
    echo "   2) 기존 VPC 활용 (빠름, 2-3분 소요)"
    read -p "   선택 (1-2): " infra_choice
    
    if [[ "$infra_choice" == "2" ]]; then
        # List available VPCs
        log_info "사용 가능한 VPC 목록을 조회 중..."
        if command -v aws >/dev/null 2>&1; then
            vpcs=$(aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}' --output table 2>/dev/null || echo "")
            if [[ -n "$vpcs" ]]; then
                echo "$vpcs"
                echo ""
                read -p "   사용할 VPC ID를 입력하세요 (vpc-xxxxx): " input_vpc
                if [[ -n "$input_vpc" ]] && validate_vpc_id "$input_vpc"; then
                    VPC_ID="$input_vpc"
                    log_success "기존 VPC 사용: $VPC_ID"
                else
                    log_warning "잘못된 VPC ID입니다. 신규 VPC를 생성합니다."
                fi
            else
                log_warning "VPC 목록을 가져올 수 없습니다. 신규 VPC를 생성합니다."
            fi
        else
            log_warning "AWS CLI가 설정되지 않았습니다. 신규 VPC를 생성합니다."
        fi
    fi
    echo ""
    
    # Step 5: Advanced features
    echo "🚀 고급 기능을 설정하시겠습니까? (선택사항)"
    echo ""
    
    # Infracost
    echo "💰 Infracost 비용 분석 (PR에서 인프라 비용 변화 확인):"
    read -p "   활성화하시겠습니까? (y/N): " enable_infracost
    if [[ "$enable_infracost" =~ ^[Yy]$ ]]; then
        echo "   💡 https://infracost.io 에서 무료 API 키를 생성하세요"
        read -p "   Infracost API 키를 입력하세요 (ico-xxxxx): " input_infracost
        if [[ -n "$input_infracost" ]]; then
            INFRACOST_KEY="$input_infracost"
            log_success "Infracost 비용 분석 활성화"
        fi
    fi
    echo ""
    
    # Slack notifications
    echo "📢 Slack 알림 (Plan/Apply 결과를 Slack으로 전송):"
    read -p "   활성화하시겠습니까? (y/N): " enable_slack
    if [[ "$enable_slack" =~ ^[Yy]$ ]]; then
        echo "   💡 Slack → Apps → Incoming Webhooks 에서 웹훅 URL을 생성하세요"
        read -p "   Slack 웹훅 URL을 입력하세요: " input_slack
        if [[ -n "$input_slack" ]]; then
            SLACK_WEBHOOK="$input_slack"
            log_success "Slack 알림 활성화"
        fi
    fi
    echo ""
    
    # HTTPS/Custom domain
    echo "🔒 HTTPS 커스텀 도메인 (선택사항, 고급 사용자용):"
    read -p "   설정하시겠습니까? (y/N): " enable_https
    if [[ "$enable_https" =~ ^[Yy]$ ]]; then
        read -p "   도메인을 입력하세요 (예: atlantis.company.com): " input_domain
        read -p "   SSL 인증서 ARN을 입력하세요: " input_cert
        if [[ -n "$input_domain" ]]; then
            CUSTOM_DOMAIN="$input_domain"
        fi
        if [[ -n "$input_cert" ]]; then
            CERTIFICATE_ARN="$input_cert"
        fi
        log_success "HTTPS 설정 완료"
    fi
    echo ""
    
    # Step 6: Summary and confirmation
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗"
    echo "║                        📋 설정 요약                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🏢 조직명: $ORG"
    echo "🌏 AWS 리전: $AWS_REGION"
    echo "🔑 GitHub 토큰: ${GITHUB_TOKEN:0:8}..."
    echo "🏗️ VPC: $([ -n "$VPC_ID" ] && echo "기존 ($VPC_ID)" || echo "신규 생성")"
    echo "💰 Infracost: $([ -n "$INFRACOST_KEY" ] && echo "활성화" || echo "비활성화")"
    echo "📢 Slack: $([ -n "$SLACK_WEBHOOK" ] && echo "활성화" || echo "비활성화")"
    echo "🔒 HTTPS: $([ -n "$CUSTOM_DOMAIN" ] && echo "$CUSTOM_DOMAIN" || echo "기본 ALB DNS")"
    echo ""
    echo "⏱️  예상 배포 시간: $([ -n "$VPC_ID" ] && echo "2-3분" || echo "4-5분")"
    echo ""
    
    read -p "📋 위 설정으로 배포를 시작하시겠습니까? (Y/n): " confirm
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        log_success "대화형 설정이 완료되었습니다. 배포를 시작합니다..."
        echo ""
        return 0
    else
        log_info "배포가 취소되었습니다."
        exit 0
    fi
}

# Progress indicator function
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=50
    local progress=$((current * width / total))
    local percentage=$((current * 100 / total))
    
    printf "\r${BLUE}["
    printf "%*s" $progress | tr ' ' '█'
    printf "%*s" $((width - progress)) | tr ' ' '░'
    printf "] %d%% - %s${NC}" $percentage "$message"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

validate_subnet_list() {
    local subnet_list="$1"
    if [[ -n "$subnet_list" ]]; then
        IFS=',' read -ra subnets <<< "$subnet_list"
        for subnet in "${subnets[@]}"; do
            if [[ ! "$subnet" =~ ^subnet-[0-9a-f]{8,17}$ ]]; then
                log_error "Invalid subnet ID format: $subnet"
                return 1
            fi
        done
    fi
    return 0
}

validate_s3_bucket_name() {
    local bucket="$1"
    if [[ -n "$bucket" ]] && [[ ! "$bucket" =~ ^[a-z0-9.-]+$ ]] || [[ ${#bucket} -gt 63 ]] || [[ ${#bucket} -lt 3 ]]; then
        log_error "Invalid S3 bucket name: $bucket"
        return 1
    fi
    return 0
}

validate_domain_name() {
    local domain="$1"
    if [[ -n "$domain" ]] && [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain name: $domain"
        return 1
    fi
    return 0
}

validate_arn() {
    local arn="$1"
    if [[ -n "$arn" ]] && [[ ! "$arn" =~ ^arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]*:.+ ]]; then
        log_error "Invalid ARN format: $arn"
        return 1
    fi
    return 0
}

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
    
    # 대화형 설정 마법사 (초보자 권장)
    $0 --interactive
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
INTERACTIVE=false

# Parse arguments with enhanced validation
while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            if [[ -z "${2:-}" ]]; then
                log_error "--org requires a value"
                exit 1
            fi
            ORG="$2"
            validate_org_name "$ORG" || exit 1
            shift 2
            ;;
        --github-token)
            if [[ -z "${2:-}" ]]; then
                log_error "--github-token requires a value"
                exit 1
            fi
            GITHUB_TOKEN="$2"
            validate_github_token "$GITHUB_TOKEN" || exit 1
            shift 2
            ;;
        --aws-region)
            if [[ -z "${2:-}" ]]; then
                log_error "--aws-region requires a value"
                exit 1
            fi
            AWS_REGION="$2"
            validate_aws_region "$AWS_REGION" || exit 1
            shift 2
            ;;
        --environment)
            if [[ -z "${2:-}" ]]; then
                log_error "--environment requires a value"
                exit 1
            fi
            ENVIRONMENT="$2"
            validate_org_name "$ENVIRONMENT" || exit 1
            shift 2
            ;;
        --git-username)
            if [[ -z "${2:-}" ]]; then
                log_error "--git-username requires a value"
                exit 1
            fi
            GIT_USERNAME="$2"
            validate_org_name "$GIT_USERNAME" || exit 1
            shift 2
            ;;
        --vpc-id)
            if [[ -z "${2:-}" ]]; then
                log_error "--vpc-id requires a value"
                exit 1
            fi
            VPC_ID="$2"
            validate_vpc_id "$VPC_ID" || exit 1
            shift 2
            ;;
        --public-subnets)
            if [[ -z "${2:-}" ]]; then
                log_error "--public-subnets requires a value"
                exit 1
            fi
            PUBLIC_SUBNETS="$2"
            validate_subnet_list "$PUBLIC_SUBNETS" || exit 1
            shift 2
            ;;
        --private-subnets)
            if [[ -z "${2:-}" ]]; then
                log_error "--private-subnets requires a value"
                exit 1
            fi
            PRIVATE_SUBNETS="$2"
            validate_subnet_list "$PRIVATE_SUBNETS" || exit 1
            shift 2
            ;;
        --state-bucket)
            if [[ -z "${2:-}" ]]; then
                log_error "--state-bucket requires a value"
                exit 1
            fi
            STATE_BUCKET="$2"
            validate_s3_bucket_name "$STATE_BUCKET" || exit 1
            shift 2
            ;;
        --lock-table)
            if [[ -z "${2:-}" ]]; then
                log_error "--lock-table requires a value"
                exit 1
            fi
            LOCK_TABLE="$2"
            validate_org_name "$LOCK_TABLE" || exit 1
            shift 2
            ;;
        --custom-domain)
            if [[ -z "${2:-}" ]]; then
                log_error "--custom-domain requires a value"
                exit 1
            fi
            CUSTOM_DOMAIN="$2"
            validate_domain_name "$CUSTOM_DOMAIN" || exit 1
            shift 2
            ;;
        --certificate-arn)
            if [[ -z "${2:-}" ]]; then
                log_error "--certificate-arn requires a value"
                exit 1
            fi
            CERTIFICATE_ARN="$2"
            validate_arn "$CERTIFICATE_ARN" || exit 1
            shift 2
            ;;
        --infracost-key)
            if [[ -z "${2:-}" ]]; then
                log_error "--infracost-key requires a value"
                exit 1
            fi
            INFRACOST_KEY="$2"
            shift 2
            ;;
        --slack-webhook)
            if [[ -z "${2:-}" ]]; then
                log_error "--slack-webhook requires a value"
                exit 1
            fi
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# StackKit 표준 호환 - 환경변수 우선 사용
if [[ -n "$TF_STACK_NAME" && -z "$ORG" ]]; then
    ORG="$TF_STACK_NAME"
    validate_org_name "$ORG" || exit 1
    log_info "TF_STACK_NAME 환경변수 사용: $ORG"
fi

if [[ -n "$ATLANTIS_GITHUB_TOKEN" ]]; then
    GITHUB_TOKEN="$ATLANTIS_GITHUB_TOKEN"
    validate_github_token "$GITHUB_TOKEN" || exit 1
    log_info "ATLANTIS_GITHUB_TOKEN 환경변수 사용"
fi

# Interactive mode execution
if [[ "$INTERACTIVE" == true ]]; then
    run_interactive_setup
fi

# Validation
if [[ -z "$ORG" || -z "$GITHUB_TOKEN" ]]; then
    if [[ "$INTERACTIVE" == true ]]; then
        log_error "대화형 설정에서 필수 정보가 누락되었습니다."
    else
        log_error "필수 인수가 누락되었습니다."
        echo "💡 StackKit 표준: TF_STACK_NAME, ATLANTIS_GITHUB_TOKEN 환경변수도 사용 가능"
        echo "💡 대화형 모드: --interactive 플래그를 사용하세요"
    fi
    show_help
    exit 1
fi

# 기본값 설정 - STS에서 사용자명 가져오기 (안전하게)
if [[ -z "$GIT_USERNAME" ]]; then
    if command -v aws >/dev/null 2>&1; then
        AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | sed 's/.*\///g' | sed 's/:.*//g' || echo "")
        if [[ -n "$AWS_USER" && "$AWS_USER" != "None" ]]; then
            if validate_org_name "$AWS_USER"; then
                GIT_USERNAME="$AWS_USER"
                log_info "AWS STS에서 사용자명 자동 탐지: $GIT_USERNAME"
            else
                log_warning "AWS STS 사용자명이 유효하지 않음, 기본값 사용"
                GIT_USERNAME="${ORG}-atlantis"
            fi
        else
            GIT_USERNAME="${ORG}-atlantis"
            log_info "기본 사용자명 사용: $GIT_USERNAME"
        fi
    else
        GIT_USERNAME="${ORG}-atlantis"
        log_info "AWS CLI 없음, 기본 사용자명 사용: $GIT_USERNAME"
    fi
fi

# VPC ID가 있으면 기존 VPC 사용으로 간주
if [[ -n "$VPC_ID" ]]; then
    log_info "기존 VPC 사용: $VPC_ID"
fi

show_banner

log_info "🏗️  StackKit 표준 호환 배포 설정 확인:"
printf "  조직/스택명: %s\n" "$ORG"
printf "  환경: %s\n" "$ENVIRONMENT"
printf "  AWS 리전 (TF_STACK_REGION): %s\n" "$AWS_REGION"
printf "  Git 사용자: %s\n" "$GIT_USERNAME"
printf "  Terraform 버전: %s\n" "$TF_VERSION"

if [[ -n "$INFRACOST_API_KEY" || -n "$INFRACOST_KEY" ]]; then
    echo "  Infracost: 활성화"
fi
if [[ -n "$SLACK_WEBHOOK_URL" || -n "$SLACK_WEBHOOK" ]]; then
    echo "  Slack 알림: 활성화"
fi
echo ""
echo "기존 인프라 활용:"
printf "  VPC: %s\n" "${VPC_ID:-"신규 생성"}"
printf "  퍼블릭 서브넷: %s\n" "${PUBLIC_SUBNETS:-"신규 생성"}"
printf "  프라이빗 서브넷: %s\n" "${PRIVATE_SUBNETS:-"신규 생성"}"
printf "  S3 버킷: %s\n" "${STATE_BUCKET:-"자동 생성"}"
printf "  DynamoDB: %s\n" "${LOCK_TABLE:-"자동 생성"}"
echo ""
echo "HTTPS 설정:"
printf "  커스텀 도메인: %s\n" "${CUSTOM_DOMAIN:-"없음 (ALB DNS 사용)"}"
if [[ -n "$CERTIFICATE_ARN" ]]; then
    echo "  SSL 인증서: 설정됨"
else
    echo "  SSL 인증서: 없음"
fi
echo ""
echo "고급 기능:"
if [[ -n "$INFRACOST_KEY" ]] || [[ -n "$INFRACOST_API_KEY" ]]; then
    echo "  Infracost: 활성화"
else
    echo "  Infracost: 비활성화"
fi
if [[ -n "$SLACK_WEBHOOK" ]] || [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    echo "  Slack 알림: 활성화"
else
    echo "  Slack 알림: 비활성화"
fi
printf "  Dry Run: %s\n" "$DRY_RUN"
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
cd "$SCRIPT_DIR/prod" || { log_error "prod 디렉토리를 찾을 수 없습니다"; exit 1; }

# Step 1: Check prerequisites
show_progress 1 6 "사전 요구사항 확인 중..."

missing_tools=()
for tool in aws terraform jq; do
    if ! command -v "$tool" &> /dev/null; then
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
    show_progress 2 6 "기존 VPC 검증 중..."
    
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
                --output text --region "$AWS_REGION" | tr '\t' ',' || echo "")
        fi
        
        # 프라이빗 서브넷 검색
        if [[ -z "$PRIVATE_SUBNETS" ]]; then
            PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
                --output text --region "$AWS_REGION" | tr '\t' ',' || echo "")
        fi
        
        validate_subnet_list "$PUBLIC_SUBNETS" || { log_error "유효하지 않은 퍼블릭 서브넷 ID"; exit 1; }
        validate_subnet_list "$PRIVATE_SUBNETS" || { log_error "유효하지 않은 프라이빗 서브넷 ID"; exit 1; }
        
        log_info "검색된 퍼블릭 서브넷: $PUBLIC_SUBNETS"
        log_info "검색된 프라이빗 서브넷: $PRIVATE_SUBNETS"
    fi
    
    log_success "기존 VPC 검증 완료"
else
    show_progress 2 6 "신규 VPC 생성 예정"
fi

# Step 3: Setup S3 bucket for state
show_progress 3 6 "Terraform 상태 저장 설정 중..."

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
    validate_s3_bucket_name "$STATE_BUCKET" || { log_error "생성된 S3 버킷 이름이 유효하지 않음"; exit 1; }
    
    if ! aws s3 ls "s3://$STATE_BUCKET" --region "$AWS_REGION" >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == false ]]; then
            aws s3 mb "s3://$STATE_BUCKET" --region "$AWS_REGION" || { log_error "S3 버킷 생성 실패"; exit 1; }
            aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled || log_warning "버킷 버저닝 설정 실패"
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
                --region "$AWS_REGION" >/dev/null || { log_error "DynamoDB 테이블 생성 실패"; exit 1; }
            
            aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION" || log_warning "테이블 생성 대기 실패"
            log_success "새 DynamoDB 테이블 생성: $LOCK_TABLE"
        else
            log_info "[DRY RUN] DynamoDB 테이블 생성 예정: $LOCK_TABLE"
        fi
    else
        log_success "기존 DynamoDB 테이블 사용: $LOCK_TABLE"
    fi
fi

# Step 4: Generate backend config
show_progress 4 6 "Terraform 설정 생성 중..."

# Safely create backend.hcl with proper escaping
{
    printf 'bucket         = "%s"\n' "$STATE_BUCKET"
    printf 'key            = "atlantis-%s.tfstate"\n' "$ENVIRONMENT"
    printf 'region         = "%s"\n' "$AWS_REGION"
    printf 'dynamodb_table = "%s"\n' "$LOCK_TABLE"
    printf 'encrypt        = true\n'
} > backend.hcl

# Step 5: Store secrets
show_progress 5 6 "비밀 정보 저장 중..."

SECRET_NAME="${ENVIRONMENT}-atlantis-secrets"
WEBHOOK_SECRET=$(openssl rand -hex 32 2>/dev/null || { log_error "웹훅 시크릿 생성 실패"; exit 1; })

# Create JSON safely with proper escaping
SECRET_JSON=$(jq -n \
    --arg github_token "$GITHUB_TOKEN" \
    --arg webhook_secret "$WEBHOOK_SECRET" \
    --arg infracost_key "${INFRACOST_API_KEY:-$INFRACOST_KEY}" \
    --arg slack_webhook "${SLACK_WEBHOOK_URL:-$SLACK_WEBHOOK}" \
    '{
        "github_token": $github_token,
        "webhook_secret": $webhook_secret
    } +
    (if $infracost_key != "" then {"infracost_api_key": $infracost_key} else {} end) +
    (if $slack_webhook != "" then {"slack_webhook_url": $slack_webhook} else {} end)' || { log_error "시크릿 JSON 생성 실패"; exit 1; })

if [[ "$DRY_RUN" == false ]]; then
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws secretsmanager update-secret --secret-id "$SECRET_NAME" --secret-string "$SECRET_JSON" --region "$AWS_REGION" >/dev/null || { log_error "시크릿 업데이트 실패"; exit 1; }
    else
        aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$SECRET_JSON" --region "$AWS_REGION" >/dev/null || { log_error "시크릿 생성 실패"; exit 1; }
    fi
    log_success "시크릿 저장 완료: $SECRET_NAME"
else
    log_info "[DRY RUN] 시크릿 저장 예정: $SECRET_NAME"
fi

# Generate terraform.tfvars safely
{
    printf '# 기본 설정\n'
    printf 'org_name     = "%s"\n' "$ORG"
    printf 'environment  = "%s"\n' "$ENVIRONMENT"
    printf 'aws_region   = "%s"\n' "$AWS_REGION"
    printf 'stack_name   = "%s-atlantis-stack"\n' "$ENVIRONMENT"
    printf 'secret_name  = "%s"\n' "$SECRET_NAME"
    printf '\n# GitHub 설정\n'
    printf 'git_username   = "%s"\n' "$GIT_USERNAME"
    printf 'repo_allowlist = [\n'
    printf '    "github.com/%s/*"\n' "$ORG"
    printf ']\n'
    printf '\n# 기존 인프라 사용 설정\n'
    printf 'use_existing_vpc             = %s\n' "$(if [[ -n "$VPC_ID" ]]; then echo "true"; else echo "false"; fi)"
    printf 'existing_vpc_id              = "%s"\n' "$VPC_ID"
    printf 'existing_public_subnet_ids   = ['
    if [[ -n "$PUBLIC_SUBNETS" ]]; then
        printf '"%s"' "${PUBLIC_SUBNETS//,/\", \"}"
    fi
    printf ']\n'
    printf 'existing_private_subnet_ids  = ['
    if [[ -n "$PRIVATE_SUBNETS" ]]; then
        printf '"%s"' "${PRIVATE_SUBNETS//,/\", \"}"
    fi
    printf ']\n'
    printf 'existing_state_bucket        = "%s"\n' "$STATE_BUCKET"
    printf 'existing_lock_table          = "%s"\n' "$LOCK_TABLE"
    printf '\n# HTTPS 설정\n'
    printf 'custom_domain   = "%s"\n' "$CUSTOM_DOMAIN"
    printf 'certificate_arn = "%s"\n' "$CERTIFICATE_ARN"
    printf '\n# 고급 기능\n'
    if [[ -n "$INFRACOST_KEY" ]] || [[ -n "$INFRACOST_API_KEY" ]]; then
        printf 'enable_infracost = true\n'
    else
        printf 'enable_infracost = false\n'
    fi
} > terraform.tfvars

log_success "Terraform 설정 파일 생성 완료"

# Step 6: Deploy infrastructure  
show_progress 6 6 "Atlantis 인프라 배포 중..."

if [[ "$DRY_RUN" == false ]]; then
    terraform init -backend-config=backend.hcl >/dev/null || { log_error "Terraform 초기화 실패"; exit 1; }
    terraform plan -out=tfplan >/dev/null || { log_error "Terraform 계획 실패"; exit 1; }

    if terraform apply -auto-approve tfplan; then
        log_success "배포 완료!"
    else
        log_error "배포 실패"
        exit 1
    fi

    # Get outputs safely
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
printf "%s🌐 Atlantis URL:%s %s\n" "$GREEN" "$NC" "$ATLANTIS_URL"
if [[ -n "$CUSTOM_DOMAIN" ]]; then
    printf "%s📋 DNS 설정 필요:%s %s → %s\n" "$BLUE" "$NC" "$CUSTOM_DOMAIN" "$ALB_DNS"
fi
echo ""
printf "%s📋 GitHub 웹훅 설정:%s\n" "$BLUE" "$NC"
printf "  URL: %s\n" "$WEBHOOK_ENDPOINT"
printf "  시크릿: AWS Secrets Manager '%s'에서 webhook_secret 확인\n" "$SECRET_NAME"
echo ""
printf "%s다음 단계:%s\n" "$BLUE" "$NC"
echo "1. GitHub 레포지토리에 웹훅 추가"
echo "2. Atlantis 웹 UI 접속 확인"
echo "3. PR 생성하여 'atlantis plan' 테스트"
if [[ -n "$INFRACOST_KEY" ]]; then
    echo "4. PR에서 Infracost 비용 분석 결과 확인"
fi
echo ""
printf "%sHappy Infrastructure as Code! 🚀%s\n" "$GREEN" "$NC"