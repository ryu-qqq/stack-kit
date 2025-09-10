#!/bin/bash
set -euo pipefail

# 🔧 StackKit 사전 준비 체크 스크립트
# 5분 배포를 위한 환경 확인

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
╔════════════════════════════════════════════════════════════════╗
║                    🔧 사전 준비 체크리스트                     ║
║                   StackKit 5분 배포 준비 완료!                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_status=0
warnings=0

# Check 1: Required tools
echo ""
log_info "1/5 필수 도구 설치 확인 중..."
echo ""

tools_missing=()
declare -A tool_descriptions=(
    ["aws"]="AWS CLI - AWS 리소스 관리"
    ["terraform"]="Terraform - 인프라 자동화"
    ["jq"]="jq - JSON 처리"
    ["curl"]="curl - HTTP 요청"
    ["git"]="Git - 버전 관리"
)

for tool in aws terraform jq curl git; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$(
            case $tool in
                aws) aws --version 2>&1 | head -1 | cut -d' ' -f1-2 ;;
                terraform) terraform version | head -1 | cut -d' ' -f2 ;;
                jq) jq --version ;;
                curl) curl --version | head -1 | cut -d' ' -f1-2 ;;
                git) git --version | cut -d' ' -f3 ;;
            esac
        )
        log_success "$tool ($version) - ${tool_descriptions[$tool]}"
    else
        tools_missing+=("$tool")
        log_error "$tool 없음 - ${tool_descriptions[$tool]}"
    fi
done

if [[ ${#tools_missing[@]} -gt 0 ]]; then
    echo ""
    log_error "누락된 도구들을 설치해야 합니다:"
    for tool in "${tools_missing[@]}"; do
        case $tool in
            aws) echo "  • AWS CLI: https://aws.amazon.com/cli/" ;;
            terraform) echo "  • Terraform: https://terraform.io/downloads" ;;
            jq) echo "  • jq: brew install jq (macOS) 또는 apt install jq (Ubuntu)" ;;
            curl) echo "  • curl: 시스템 패키지 매니저로 설치" ;;
            git) echo "  • Git: https://git-scm.com/downloads" ;;
        esac
    done
    echo ""
    echo "🍺 macOS 사용자: brew install awscli terraform jq"
    echo "🐧 Ubuntu 사용자: apt install awscli terraform jq curl git"
    check_status=1
fi

# Check 2: AWS Configuration
echo ""
log_info "2/5 AWS 설정 확인 중..."
echo ""

if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        aws_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
        aws_user=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | sed 's/.*\///g' | sed 's/:.*//g')
        aws_region=$(aws configure get region 2>/dev/null || echo "환경변수에서 설정")
        
        log_success "AWS 인증 완료"
        echo "  • 계정 ID: $aws_account"
        echo "  • 사용자: $aws_user"
        echo "  • 기본 리전: ${aws_region:-"설정되지 않음 (환경변수 AWS_DEFAULT_REGION 확인)"}"
        
        # Check permissions
        log_info "AWS 권한 확인 중..."
        permission_issues=()
        
        # Test basic permissions
        if ! aws iam list-attached-user-policies --user-name "$aws_user" >/dev/null 2>&1; then
            if ! aws sts get-caller-identity --query 'Arn' | grep -q 'role'; then
                permission_issues+=("IAM 사용자 정보 조회 권한 부족")
            fi
        fi
        
        if ! aws ec2 describe-vpcs --max-items 1 >/dev/null 2>&1; then
            permission_issues+=("EC2 조회 권한 부족")
        fi
        
        if ! aws s3 ls >/dev/null 2>&1; then
            permission_issues+=("S3 접근 권한 부족")
        fi
        
        if [[ ${#permission_issues[@]} -gt 0 ]]; then
            log_warning "일부 AWS 권한이 부족할 수 있습니다:"
            for issue in "${permission_issues[@]}"; do
                echo "  • $issue"
            done
            echo ""
            echo "💡 권한 해결 방법:"
            echo "  • AdministratorAccess 정책 연결 (권장)"
            echo "  • 또는 최소 권한: EC2, ECS, VPC, ALB, Secrets Manager, S3, DynamoDB, CloudWatch"
            warnings=$((warnings + 1))
        else
            log_success "AWS 권한 확인 완료"
        fi
    else
        log_error "AWS 자격 증명이 설정되지 않았습니다"
        echo ""
        echo "💡 AWS 설정 방법:"
        echo "  1. aws configure (권장)"
        echo "  2. 환경변수: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        echo "  3. IAM 역할 (EC2에서 실행 시)"
        check_status=1
    fi
else
    log_error "AWS CLI가 설치되지 않았습니다"
    check_status=1
fi

# Check 3: Terraform version
echo ""
log_info "3/5 Terraform 버전 확인 중..."
echo ""

if command -v terraform >/dev/null 2>&1; then
    tf_version=$(terraform version | head -1 | cut -d'v' -f2 | cut -d' ' -f1)
    required_version="1.7.0"
    
    # Simple version comparison
    if [[ "$(printf '%s\n' "$required_version" "$tf_version" | sort -V | head -n1)" == "$required_version" ]]; then
        log_success "Terraform $tf_version (요구사항: ≥$required_version)"
    else
        log_warning "Terraform $tf_version (권장: ≥$required_version)"
        echo "  💡 최신 버전으로 업그레이드 권장: https://terraform.io/downloads"
        warnings=$((warnings + 1))
    fi
else
    log_error "Terraform이 설치되지 않았습니다"
    check_status=1
fi

# Check 4: Environment variables
echo ""
log_info "4/5 환경변수 확인 중..."
echo ""

env_vars_found=()
env_vars_missing=()

# Check StackKit standard variables
declare -A stackkit_vars=(
    ["TF_STACK_REGION"]="AWS 리전 설정"
    ["TF_STACK_NAME"]="스택 이름 설정"
    ["ATLANTIS_GITHUB_TOKEN"]="GitHub 토큰"
    ["INFRACOST_API_KEY"]="비용 분석 (선택사항)"
    ["SLACK_WEBHOOK_URL"]="Slack 알림 (선택사항)"
)

for var in "${!stackkit_vars[@]}"; do
    if [[ -n "${!var:-}" ]]; then
        case $var in
            *TOKEN|*KEY|*WEBHOOK*)
                masked_value="${!var:0:8}..."
                ;;
            *)
                masked_value="${!var}"
                ;;
        esac
        log_success "$var: $masked_value - ${stackkit_vars[$var]}"
        env_vars_found+=("$var")
    else
        env_vars_missing+=("$var")
    fi
done

if [[ ${#env_vars_found[@]} -gt 0 ]]; then
    echo ""
    log_success "StackKit 환경변수 활용 가능: ${#env_vars_found[@]}개 설정됨"
else
    echo ""
    log_info "StackKit 환경변수 없음 (대화형 모드 또는 명령행 인수 사용)"
fi

# Check 5: Network connectivity
echo ""
log_info "5/5 네트워크 연결 확인 중..."
echo ""

connectivity_issues=()

# Test AWS API
if ! curl -s --max-time 10 https://sts.amazonaws.com >/dev/null 2>&1; then
    connectivity_issues+=("AWS API 연결 불가")
fi

# Test GitHub API
if ! curl -s --max-time 10 https://api.github.com >/dev/null 2>&1; then
    connectivity_issues+=("GitHub API 연결 불가")
fi

# Test Terraform registry
if ! curl -s --max-time 10 https://registry.terraform.io >/dev/null 2>&1; then
    connectivity_issues+=("Terraform Registry 연결 불가")
fi

if [[ ${#connectivity_issues[@]} -eq 0 ]]; then
    log_success "네트워크 연결 정상"
else
    for issue in "${connectivity_issues[@]}"; do
        log_warning "$issue"
    done
    warnings=$((warnings + 1))
fi

# Summary
echo ""
echo "══════════════════════════════════════════════════════════════════════════════"

if [[ $check_status -eq 0 ]]; then
    if [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}🎉 모든 사전 준비가 완료되었습니다!${NC}"
        echo ""
        echo "🚀 이제 5분 배포를 시작할 수 있습니다:"
        echo ""
        echo "  # 기본 배포"
        echo "  ./quick-deploy.sh --org mycompany --github-token ghp_xxxxx"
        echo ""
        echo "  # 대화형 설정 마법사"
        echo "  ./quick-deploy.sh --interactive"
        echo ""
        echo "  # 기존 VPC 활용 (더 빠름)"
        echo "  ./quick-deploy.sh --org mycompany --github-token ghp_xxxxx --vpc-id vpc-xxxxx"
    else
        echo -e "${YELLOW}⚠️  사전 준비가 대부분 완료되었습니다 (경고 ${warnings}개)${NC}"
        echo ""
        echo "🚀 배포를 진행할 수 있지만, 위의 경고사항을 확인해주세요."
        echo ""
        echo "💡 대화형 모드로 설정을 검토하세요:"
        echo "  ./quick-deploy.sh --interactive"
    fi
else
    echo -e "${RED}❌ 사전 준비가 완료되지 않았습니다${NC}"
    echo ""
    echo "🔧 위의 문제들을 해결한 후 다시 실행해주세요:"
    echo "  $0"
    echo ""
    echo "📖 자세한 정보: docs/prerequisites.md"
fi

echo "══════════════════════════════════════════════════════════════════════════════"

exit $check_status