#!/bin/bash
set -euo pipefail

# 🔗 StackKit GitOps Atlantis Repository Connector
# 저장소에 Atlantis 설정을 자동으로 추가하고 GitHub 웹훅을 설정하는 스크립트

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_header() { echo -e "${PURPLE}🚀 $1${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
 ____  _             _    _  _ _ _     ____                            _
/ ___|| |_ __ _  ___| | _| |/ (_) |_  / ___|___  _ __  _ __   ___  ___| |_
\___ \| __/ _` |/ __| |/ / ' /| | __|| |   / _ \| '_ \| '_ \ / _ \/ __| __|
 ___) | || (_| | (__|   <| . \| | |_ | |__| (_) | | | | | | |  __/ (__| |_
|____/ \__\__,_|\___|_|\_\_|\_\_|\__| \____\___/|_| |_|_| |_|\___|\___|\__|

🔗 StackKit GitOps Atlantis Repository Connector
저장소를 Atlantis에 자동 연결하고 GitHub 웹훅 설정
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

🏗️  StackKit GitOps Atlantis Repository Connector

이 스크립트를 StackKit 프로젝트 루트에서 실행하세요.

Required Options:
    --atlantis-url URL      Atlantis 서버 URL (필수)
    --repo-name NAME        저장소 이름 (예: connectly/shared-infra)
    --github-token TOKEN    GitHub Personal Access Token (repo 권한 필요)

Optional Options:
    --webhook-secret SECRET GitHub 웹훅 시크릿 (자동 생성됨)
    --aws-region REGION     AWS 리전 (기본: ap-northeast-2)
    --slack-webhook URL     Slack 웹훅 URL (알림용)
    --infracost-key KEY     Infracost API 키 (비용 분석용)
    --project-name NAME     프로젝트 이름 (기본: 디렉토리명)
    --environment ENV       환경 (dev/staging/prod, 기본: prod)
    --skip-webhook         웹훅 설정 건너뛰기
    --help                 이 도움말 표시

Environment Variables:
    ATLANTIS_URL           Atlantis 서버 URL
    GITHUB_TOKEN           GitHub Personal Access Token
    SLACK_WEBHOOK_URL      Slack 웹훅 URL
    INFRACOST_API_KEY      Infracost API 키

Examples:
    # 기본 설정
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name connectly/shared-infra \\
       --github-token ghp_xxxxx

    # 슬랙 알림 및 Infracost 포함
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name connectly/shared-infra \\
       --github-token ghp_xxxxx \\
       --slack-webhook https://hooks.slack.com/services/xxx \\
       --infracost-key ico-xxxxx

    # 개발 환경용 설정
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name connectly/my-service \\
       --github-token ghp_xxxxx \\
       --environment dev

EOF
}

# Default values
ATLANTIS_URL=""
REPO_NAME=""
GITHUB_TOKEN=""
WEBHOOK_SECRET=""
AWS_REGION="ap-northeast-2"
SLACK_WEBHOOK_URL=""
INFRACOST_API_KEY=""
PROJECT_NAME=""
ENVIRONMENT="prod"
SKIP_WEBHOOK=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --atlantis-url)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--atlantis-url requires a value"
            fi
            ATLANTIS_URL="$2"
            shift 2
            ;;
        --repo-name)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--repo-name requires a value"
            fi
            REPO_NAME="$2"
            shift 2
            ;;
        --github-token)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--github-token requires a value"
            fi
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --webhook-secret)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--webhook-secret requires a value"
            fi
            WEBHOOK_SECRET="$2"
            shift 2
            ;;
        --aws-region)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--aws-region requires a value"
            fi
            AWS_REGION="$2"
            shift 2
            ;;
        --slack-webhook)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--slack-webhook requires a value"
            fi
            SLACK_WEBHOOK_URL="$2"
            shift 2
            ;;
        --infracost-key)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--infracost-key requires a value"
            fi
            INFRACOST_API_KEY="$2"
            shift 2
            ;;
        --project-name)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--project-name requires a value"
            fi
            PROJECT_NAME="$2"
            shift 2
            ;;
        --environment)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--environment requires a value"
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        --skip-webhook)
            SKIP_WEBHOOK=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            ;;
        *)
            log_error "Unexpected argument: $1"
            ;;
    esac
done

# Check for environment variables if not provided
ATLANTIS_URL=${ATLANTIS_URL:-${ATLANTIS_URL_ENV:-}}
GITHUB_TOKEN=${GITHUB_TOKEN:-${GITHUB_TOKEN_ENV:-}}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-${SLACK_WEBHOOK_URL_ENV:-}}
INFRACOST_API_KEY=${INFRACOST_API_KEY:-${INFRACOST_API_KEY_ENV:-}}

# Set project name to directory name if not provided
if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME=$(basename "$(pwd)")
fi

# Validation
if [[ -z "$ATLANTIS_URL" ]]; then
    log_error "Atlantis URL is required. Use --atlantis-url or set ATLANTIS_URL environment variable."
fi

if [[ -z "$REPO_NAME" ]]; then
    log_error "Repository name is required. Use --repo-name (e.g., connectly/shared-infra)."
fi

if [[ -z "$GITHUB_TOKEN" && "$SKIP_WEBHOOK" == false ]]; then
    log_error "GitHub token is required for webhook setup. Use --github-token or set GITHUB_TOKEN environment variable, or use --skip-webhook."
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Environment must be dev, staging, or prod. Got: $ENVIRONMENT"
fi

# Generate webhook secret if not provided
if [[ -z "$WEBHOOK_SECRET" ]]; then
    WEBHOOK_SECRET=$(openssl rand -hex 20 2>/dev/null || date +%s | sha256sum | head -c 40)
fi

# Ensure required tools are available
for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool '$tool' is not installed"
    fi
done

show_banner

log_header "StackKit GitOps Atlantis Repository Connection"
log_info "Project: $PROJECT_NAME"
log_info "Environment: $ENVIRONMENT"
log_info "Repository: $REPO_NAME"
log_info "Atlantis URL: $ATLANTIS_URL"

# Step 1: Verify current directory is a StackKit project
log_header "1/5 StackKit 프로젝트 검증 중..."

if [[ ! -f "atlantis.yaml" ]]; then
    log_error "atlantis.yaml not found. Please run this script from a StackKit GitOps project root."
fi

if [[ ! -f "terraform.tfvars.example" ]]; then
    log_warning "terraform.tfvars.example not found. This might not be a StackKit project."
fi

log_success "StackKit 프로젝트 확인됨"

# Step 2: Update atlantis.yaml with project-specific configuration
log_header "2/5 Atlantis 설정 업데이트 중..."

# Update project name in atlantis.yaml
if command -v sed >/dev/null 2>&1; then
    # Update project name
    if grep -q "name: shared-infra" atlantis.yaml; then
        sed -i.bak "s/name: shared-infra/name: $PROJECT_NAME/" atlantis.yaml
        log_info "프로젝트 이름을 '$PROJECT_NAME'으로 업데이트"
    fi

    # Update environment if not prod
    if [[ "$ENVIRONMENT" != "prod" ]]; then
        sed -i.bak "s/workspace: prod/workspace: $ENVIRONMENT/" atlantis.yaml
        log_info "환경을 '$ENVIRONMENT'로 업데이트"
    fi

    # Clean up backup file
    rm -f atlantis.yaml.bak

    log_success "Atlantis 설정 업데이트 완료"
else
    log_warning "sed not available. Please manually update project name in atlantis.yaml"
fi

# Step 3: Setup GitHub webhook
log_header "3/5 GitHub 웹훅 설정 중..."

setup_github_webhook() {
    if [[ "$SKIP_WEBHOOK" == true ]]; then
        log_info "웹훅 설정을 건너뜁니다"
        return 0
    fi

    local webhook_url="$ATLANTIS_URL/events"
    local webhook_config=$(cat << EOF
{
  "name": "web",
  "active": true,
  "events": [
    "issue_comment",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "push"
  ],
  "config": {
    "url": "$webhook_url",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET",
    "insecure_ssl": "0"
  }
}
EOF
)

    log_info "GitHub 웹훅 확인 중..."

    # Check if webhook already exists
    local existing_webhook=""
    local webhook_response
    webhook_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null || echo "")

    if [[ -n "$webhook_response" && "$webhook_response" != "null" ]]; then
        existing_webhook=$(echo "$webhook_response" | jq -r ".[] | select(.config.url == \"$webhook_url\") | .id" 2>/dev/null || echo "")
    fi

    if [[ -n "$existing_webhook" ]]; then
        log_info "기존 웹훅 발견 (ID: $existing_webhook). 업데이트합니다."

        local response
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -X PATCH \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks/$existing_webhook" 2>/dev/null || echo "")
    else
        log_info "새 웹훅을 생성합니다."

        local response
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null || echo "")
    fi

    local response_body=$(echo "$response" | sed '$d')
    local http_status=$(echo "$response" | tail -n1 | sed 's/.*://')

    case $http_status in
        200)
            log_success "GitHub 웹훅이 성공적으로 업데이트되었습니다!"
            ;;
        201)
            log_success "GitHub 웹훅이 성공적으로 생성되었습니다!"
            ;;
        *)
            log_warning "웹훅 설정에 문제가 발생했습니다 (HTTP $http_status)"
            if [[ -n "$response_body" ]]; then
                echo "응답: $response_body" | head -3
            fi
            ;;
    esac
}

setup_github_webhook

# Step 4: Setup GitHub repository variables
log_header "4/5 GitHub 리포지토리 변수 설정 중..."

setup_github_variables() {
    log_info "리포지토리 변수 설정 중..."

    # Variables to set
    declare -A variables=(
        ["ATLANTIS_WEBHOOK_SECRET"]="$WEBHOOK_SECRET"
        ["AWS_REGION"]="$AWS_REGION"
        ["PROJECT_NAME"]="$PROJECT_NAME"
        ["ENVIRONMENT"]="$ENVIRONMENT"
    )

    # Optional variables
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        variables["SLACK_WEBHOOK_URL"]="$SLACK_WEBHOOK_URL"
    fi

    if [[ -n "$INFRACOST_API_KEY" ]]; then
        variables["INFRACOST_API_KEY"]="$INFRACOST_API_KEY"
    fi

    # Set each variable
    for var_name in "${!variables[@]}"; do
        local var_value="${variables[$var_name]}"

        # Create or update repository variable
        local response
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "{\"name\":\"$var_name\",\"value\":\"$var_value\"}" \
            "https://api.github.com/repos/$REPO_NAME/actions/variables" 2>/dev/null || echo "")

        local http_status=$(echo "$response" | tail -n1 | sed 's/.*://')

        case $http_status in
            201)
                log_success "변수 $var_name 생성됨"
                ;;
            409)
                # Variable already exists, update it
                response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Content-Type: application/json" \
                    -X PATCH \
                    -d "{\"name\":\"$var_name\",\"value\":\"$var_value\"}" \
                    "https://api.github.com/repos/$REPO_NAME/actions/variables/$var_name" 2>/dev/null || echo "")

                local update_status=$(echo "$response" | tail -n1 | sed 's/.*://')
                if [[ "$update_status" == "204" ]]; then
                    log_success "변수 $var_name 업데이트됨"
                else
                    log_warning "변수 $var_name 업데이트 실패"
                fi
                ;;
            *)
                log_warning "변수 $var_name 설정 실패 (HTTP $http_status)"
                ;;
        esac
    done
}

setup_github_variables

# Step 5: Final verification and instructions
log_header "5/5 설정 완료 및 다음 단계 안내"

log_success "StackKit GitOps Atlantis 연결 완료!"

echo ""
echo "🎉 설정이 성공적으로 완료되었습니다!"
echo ""
echo "설정된 내용:"
echo "  ✅ Atlantis 설정 파일: atlantis.yaml"
echo "  ✅ GitHub 웹훅: $ATLANTIS_URL/events"
echo "  ✅ 웹훅 시크릿: 설정됨"
echo "  ✅ 리포지토리 변수: 설정됨"

if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    echo "  ✅ Slack 알림: 활성화됨"
fi

if [[ -n "$INFRACOST_API_KEY" ]]; then
    echo "  ✅ Infracost 분석: 활성화됨"
fi

echo ""
echo "다음 단계:"
echo "1. 변경사항을 커밋하고 푸시하세요:"
echo "   git add atlantis.yaml"
echo "   git commit -m 'feat: configure Atlantis GitOps integration'"
echo "   git push origin main"
echo ""
echo "2. PR을 생성하여 Atlantis를 테스트하세요:"
echo "   - Terraform 파일을 수정하고 PR 생성"
echo "   - Atlantis가 자동으로 plan을 실행함"
echo "   - PR 승인 후 'atlantis apply' 명령으로 배포"
echo ""

if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    echo "3. Slack에서 알림을 확인하세요:"
    echo "   - Plan 결과 및 비용 분석 알림"
    echo "   - Apply 완료 알림"
    echo ""
fi

echo "🔗 Atlantis 서버: $ATLANTIS_URL"
echo "📚 StackKit 문서: https://github.com/company/stackkit-terraform-modules"
echo ""
echo "문제가 발생하면 다음을 확인하세요:"
echo "- Atlantis 서버가 실행 중인지"
echo "- GitHub 토큰에 repo 권한이 있는지"
echo "- 웹훅 URL이 올바른지"

log_success "StackKit GitOps Atlantis 연결이 완료되었습니다! 🚀"
