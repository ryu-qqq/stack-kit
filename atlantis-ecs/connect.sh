#!/bin/bash
set -euo pipefail

# 🔗 Connect Repository to Atlantis
# 저장소에 Atlantis 설정을 자동으로 추가하는 스크립트

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Input validation functions
validate_github_token() {
    local token="$1"
    if [[ ! "$token" =~ ^ghp_[A-Za-z0-9_]{36}$ ]]; then
        log_error "Invalid GitHub token format. Must be 'ghp_' followed by 36 characters."
        return 1
    fi
    return 0
}

validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+[^/]*/?$ ]]; then
        log_error "Invalid URL format: $url"
        return 1
    fi
    return 0
}

validate_repo_name() {
    local repo="$1"
    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid repo name format. Must be 'owner/repo': $repo"
        return 1
    fi
    return 0
}

validate_aws_region() {
    local region="$1"
    if [[ ! "$region" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid AWS region format: $region"
        return 1
    fi
    return 0
}

validate_secret_name() {
    local secret="$1"
    if [[ ! "$secret" =~ ^[a-zA-Z0-9/_+=.@-]+$ ]] || [[ ${#secret} -gt 512 ]]; then
        log_error "Invalid secret name: $secret"
        return 1
    fi
    return 0
}

validate_project_dir() {
    local dir="$1"
    # Prevent path traversal attacks
    if [[ "$dir" =~ \.\./|\.\.\\ ]] || [[ "$dir" =~ ^/ ]]; then
        log_error "Invalid project directory (path traversal detected): $dir"
        return 1
    fi
    return 0
}

show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
 ____  _             _    _  _ _ _     ____                            _
/ ___|| |_ __ _  ___| | _| |/ (_) |_  / ___|___  _ __  _ __   ___  ___| |_
\___ \| __/ _` |/ __| |/ / ' /| | __|| |   / _ \| '_ \| '_ \ / _ \/ __| __|
 ___) | || (_| | (__|   <| . \| | |_ | |__| (_) | | | | | | |  __/ (__| |_
|____/ \__\__,_|\___|_|\_\_|\_\_|\__| \____\___/|_| |_|_| |_|\___|\___|\__|

🔗 Connect Repository to Atlantis
자동으로 저장소에 Atlantis 설정 추가
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

🏗️  StackKit 표준 호환 - Atlantis 저장소 연결 스크립트

이 스크립트를 Terraform 프로젝트 루트에서 실행하세요.

StackKit 표준 변수 지원:
    환경변수 TF_STACK_REGION    AWS 리전 (기본: ap-northeast-2)
    환경변수 ATLANTIS_*         GitHub Secrets의 ATLANTIS_ 접두사 변수들

Options:
    --atlantis-url URL      Atlantis 서버 URL (필수)
    --repo-name NAME        저장소 이름 (예: myorg/myrepo)
    --project-dir DIR       Terraform 프로젝트 디렉토리 (기본: .)
    --github-token TOKEN    GitHub Personal Access Token (ATLANTIS_GITHUB_TOKEN 우선)
    --webhook-secret SECRET GitHub 웹훅 시크릿 (기존 시크릿 사용 또는 자동 생성)
    --secret-name NAME      Atlantis Secrets Manager 이름 (시크릿 동기화용)
    --aws-region REGION     AWS 리전 (TF_STACK_REGION 우선, 기본: ap-northeast-2)
    --auto-plan            자동 plan 활성화 (기본: false)
    --auto-merge           자동 merge 활성화 (기본: false)
    --skip-webhook         웹훅 설정 건너뛰기
    --help                 이 도움말 표시

Examples:
    # GitHub 웹훅 자동 설정 포함 (Atlantis 시크릿과 동기화)
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name myorg/myrepo \\
       --github-token ghp_xxxxxxxxxxxx \\
       --secret-name prod-atlantis-secrets

    # 웹훅 설정 없이 설정 파일만 생성
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name myorg/myrepo \\
       --skip-webhook

    # Slack 알림과 함께 설정
    $0 --atlantis-url https://atlantis.company.com \\
       --repo-name myorg/myrepo \\
       --github-token ghp_xxxxxxxxxxxx \\
       --secret-name prod-atlantis-secrets \\
       --enable-slack-notifications

    # 참고: Slack 웹훅 URL은 Atlantis Secrets Manager에서 설정됨
EOF
}

# Default values (StackKit 표준 호환)
ATLANTIS_URL=""
REPO_NAME=""
PROJECT_DIR=""  # 자동 감지하도록 빈 값으로 설정
GITHUB_TOKEN=""
WEBHOOK_SECRET=""
SECRET_NAME=""
TF_VERSION="1.7.5"
TF_STACK_REGION="${TF_STACK_REGION:-ap-northeast-2}"
AWS_REGION="${TF_STACK_REGION}"
AUTO_PLAN=false
AUTO_MERGE=false
SKIP_WEBHOOK=false
ENABLE_SLACK_NOTIFICATIONS=false

# StackKit 호환 - 환경변수에서 값 읽기 (GitHub Actions/Secrets용)
ATLANTIS_GITHUB_TOKEN="${ATLANTIS_GITHUB_TOKEN:-$GITHUB_TOKEN}"

# Parse arguments with enhanced validation
while [[ $# -gt 0 ]]; do
    case $1 in
        --atlantis-url)
            if [[ -z "${2:-}" ]]; then
                log_error "--atlantis-url requires a value"
                show_help
                exit 1
            fi
            ATLANTIS_URL="$2"
            validate_url "$ATLANTIS_URL" || exit 1
            shift 2
            ;;
        --repo-name)
            if [[ -z "${2:-}" ]]; then
                log_error "--repo-name requires a value"
                show_help
                exit 1
            fi
            REPO_NAME="$2"
            validate_repo_name "$REPO_NAME" || exit 1
            shift 2
            ;;
        --project-dir)
            if [[ -z "${2:-}" ]]; then
                log_error "--project-dir requires a value"
                show_help
                exit 1
            fi
            PROJECT_DIR="$2"
            validate_project_dir "$PROJECT_DIR" || exit 1
            shift 2
            ;;
        --github-token)
            if [[ -z "${2:-}" ]]; then
                log_error "--github-token requires a value"
                show_help
                exit 1
            fi
            GITHUB_TOKEN="$2"
            validate_github_token "$GITHUB_TOKEN" || exit 1
            shift 2
            ;;
        --webhook-secret)
            if [[ -z "${2:-}" ]]; then
                log_error "--webhook-secret requires a value"
                show_help
                exit 1
            fi
            WEBHOOK_SECRET="$2"
            shift 2
            ;;
        --secret-name)
            if [[ -z "${2:-}" ]]; then
                log_error "--secret-name requires a value"
                show_help
                exit 1
            fi
            SECRET_NAME="$2"
            validate_secret_name "$SECRET_NAME" || exit 1
            shift 2
            ;;
        --aws-region)
            if [[ -z "${2:-}" ]]; then
                log_error "--aws-region requires a value"
                show_help
                exit 1
            fi
            AWS_REGION="$2"
            validate_aws_region "$AWS_REGION" || exit 1
            shift 2
            ;;
        --auto-plan) 
            AUTO_PLAN=true
            shift
            ;;
        --auto-merge) 
            AUTO_MERGE=true
            shift
            ;;
        --skip-webhook) 
            SKIP_WEBHOOK=true
            shift
            ;;
        --enable-slack-notifications) 
            ENABLE_SLACK_NOTIFICATIONS=true
            shift
            ;;
        --help) 
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "$ATLANTIS_URL" ]]; then
    log_error "Atlantis URL이 필요합니다."
    show_help
    exit 1
fi

# Auto-detect repo name from git remote (safely)
if [[ -z "$REPO_NAME" ]]; then
    if command -v git >/dev/null 2>&1; then
        if git remote -v >/dev/null 2>&1; then
            origin_url=$(git remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$origin_url" ]]; then
                # Extract repo name safely from various GitHub URL formats
                repo_extracted=""
                if [[ "$origin_url" =~ github\.com[/:]([^/]+/[^/]+)\.git$ ]]; then
                    repo_extracted="${BASH_REMATCH[1]}"
                elif [[ "$origin_url" =~ github\.com[/:]([^/]+/[^/]+)$ ]]; then
                    repo_extracted="${BASH_REMATCH[1]}"
                fi
                
                if [[ -n "$repo_extracted" ]] && validate_repo_name "$repo_extracted"; then
                    REPO_NAME="$repo_extracted"
                    log_info "GitHub remote에서 저장소 이름 자동 탐지: $REPO_NAME"
                fi
            fi
        fi
    fi

    if [[ -z "$REPO_NAME" ]]; then
        log_error "저장소 이름이 필요합니다."
        log_info "다음 중 하나를 수행하세요:"
        echo "  1. --repo-name myorg/myrepo 형식으로 직접 지정"
        echo "  2. Git repository의 origin remote가 GitHub URL인지 확인"
        show_help
        exit 1
    fi
fi

show_banner

# StackKit 표준 구조 자동 감지
detect_terraform_structure() {
    if [[ -z "$PROJECT_DIR" ]]; then
        log_info "🔍 StackKit 표준 Terraform 구조 자동 감지 중..."
        
        local found_stacks=()
        
        # terraform/stacks 구조 우선 검사
        if [[ -d "terraform/stacks" ]]; then
            log_info "terraform/stacks 디렉토리 발견, 스택 검사 중..."
            
            # backend.hcl이 있는 스택 디렉토리 찾기 (안전하게)
            while IFS= read -r -d '' stack_file; do
                stack_dir=$(dirname "$stack_file" 2>/dev/null || echo "")
                if [[ -n "$stack_dir" ]] && validate_project_dir "$stack_dir"; then
                    found_stacks+=("$stack_dir")
                fi
            done < <(find terraform/stacks -maxdepth 3 -name "backend.hcl" -type f -print0 2>/dev/null || true)
            
            if [[ ${#found_stacks[@]} -gt 0 ]]; then
                # 첫 번째 스택을 기본값으로 사용
                PROJECT_DIR="${found_stacks[0]}"
                log_success "StackKit 스택 자동 감지: $PROJECT_DIR"
                
                if [[ ${#found_stacks[@]} -gt 1 ]]; then
                    log_info "추가 스택 발견:"
                    for ((i=1; i<${#found_stacks[@]} && i<5; i++)); do
                        printf "  - %s\n" "${found_stacks[$i]}"
                    done
                    log_warning "첫 번째 스택을 사용합니다. 다른 스택은 --project-dir로 지정하세요."
                fi
                return 0
            fi
        fi
        
        # 일반 terraform 디렉토리 검사
        if [[ -d "terraform" ]] && [[ -f "terraform/main.tf" || -f "terraform/versions.tf" ]]; then
            PROJECT_DIR="terraform"
            log_success "일반 Terraform 구조 감지: $PROJECT_DIR"
            return 0
        fi
        
        # 루트 디렉토리에서 Terraform 파일 검사
        if [[ -f "main.tf" || -f "versions.tf" ]]; then
            PROJECT_DIR="."
            log_success "루트 Terraform 구조 감지: $PROJECT_DIR"
            return 0
        fi
        
        # 아무것도 찾지 못한 경우
        log_warning "Terraform 파일을 찾을 수 없습니다."
        log_info "다음 중 하나를 수행하세요:"
        echo "  1. --project-dir로 Terraform 디렉토리 직접 지정"
        echo "  2. terraform/stacks/프로젝트명/ 구조로 파일 정리"
        echo "  3. 루트에 main.tf 파일 생성"
        
        PROJECT_DIR="."
        return 1
    fi
}

# Generate secure webhook secret
generate_secure_webhook_secret() {
    # Try multiple methods for generating secure random string
    local secret=""
    
    # Method 1: OpenSSL (most common)
    if command -v openssl >/dev/null 2>&1; then
        secret=$(openssl rand -hex 32 2>/dev/null || echo "")
        if [[ -n "$secret" ]]; then
            echo "$secret"
            return 0
        fi
    fi
    
    # Method 2: /dev/urandom with hexdump
    if [[ -r /dev/urandom ]] && command -v hexdump >/dev/null 2>&1; then
        secret=$(head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"' 2>/dev/null || echo "")
        if [[ -n "$secret" ]]; then
            echo "$secret"
            return 0
        fi
    fi
    
    # Method 3: Base64 fallback with /dev/urandom
    if [[ -r /dev/urandom ]] && command -v base64 >/dev/null 2>&1; then
        secret=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 64 2>/dev/null || echo "")
        if [[ -n "$secret" ]]; then
            echo "$secret"
            return 0
        fi
    fi
    
    # Method 4: Fallback using system time and process info (less secure but functional)
    local timestamp=$(date +%s%N 2>/dev/null || date +%s)
    local random_data="${timestamp}$(whoami)$(hostname)$$"
    if command -v sha256sum >/dev/null 2>&1; then
        secret=$(echo "$random_data" | sha256sum | head -c 64 2>/dev/null || echo "")
    elif command -v shasum >/dev/null 2>&1; then
        secret=$(echo "$random_data" | shasum -a 256 | head -c 64 2>/dev/null || echo "")
    fi
    
    if [[ -n "$secret" && ${#secret} -ge 40 ]]; then
        echo "$secret"
        return 0
    fi
    
    log_error "Failed to generate secure webhook secret"
    return 1
}

# Sync webhook secret with Atlantis Secrets Manager
sync_webhook_secret() {
    if [[ -z "$WEBHOOK_SECRET" ]]; then
        if [[ -n "$SECRET_NAME" ]]; then
            log_info "Atlantis Secrets Manager에서 웹훅 시크릿 조회 중..."

            # AWS CLI 사용 가능한지 확인
            if ! command -v aws >/dev/null 2>&1; then
                log_warning "AWS CLI가 설치되지 않았습니다. 새 시크릿을 생성합니다."
                WEBHOOK_SECRET=$(generate_secure_webhook_secret) || {
                    log_error "웹훅 시크릿 생성 실패"
                    exit 1
                }
                return
            fi

            # 기존 시크릿에서 webhook_secret 조회 (안전하게)
            local existing_secret=""
            local secret_response=""
            
            secret_response=$(aws secretsmanager get-secret-value \
                --region "$AWS_REGION" \
                --secret-id "$SECRET_NAME" \
                --query 'SecretString' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$secret_response" && "$secret_response" != "null" ]]; then
                if command -v jq >/dev/null 2>&1; then
                    existing_secret=$(echo "$secret_response" | jq -r '.webhook_secret // empty' 2>/dev/null || echo "")
                fi
            fi

            if [[ -n "$existing_secret" && "$existing_secret" != "null" && "$existing_secret" != "empty" ]]; then
                WEBHOOK_SECRET="$existing_secret"
                log_success "기존 Atlantis 웹훅 시크릿 사용: ${WEBHOOK_SECRET:0:8}..."
            else
                log_warning "기존 웹훅 시크릿을 찾을 수 없습니다. 새 시크릿을 생성합니다."
                WEBHOOK_SECRET=$(generate_secure_webhook_secret) || {
                    log_error "웹훅 시크릿 생성 실패"
                    exit 1
                }

                # Secrets Manager 업데이트
                update_secrets_manager
            fi
        else
            WEBHOOK_SECRET=$(generate_secure_webhook_secret) || {
                log_error "웹훅 시크릿 생성 실패"
                exit 1
            }
            log_info "새 웹훅 시크릿 생성: ${WEBHOOK_SECRET:0:8}..."
        fi
    fi
}

# Update Atlantis Secrets Manager with new webhook secret
update_secrets_manager() {
    if [[ -n "$SECRET_NAME" ]] && command -v aws >/dev/null 2>&1; then
        log_info "Atlantis Secrets Manager에 웹훅 시크릿 업데이트 중..."

        # 현재 시크릿 값 조회
        local current_secret=""
        current_secret=$(aws secretsmanager get-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$SECRET_NAME" \
            --query 'SecretString' \
            --output text 2>/dev/null || echo "")

        if [[ -n "$current_secret" && "$current_secret" != "null" ]] && command -v jq >/dev/null 2>&1; then
            # 기존 시크릿에 webhook_secret 추가/업데이트 (안전하게)
            local updated_secret=""
            updated_secret=$(echo "$current_secret" | jq --arg secret "$WEBHOOK_SECRET" '. + {"webhook_secret": $secret}' 2>/dev/null || echo "")

            if [[ -n "$updated_secret" ]]; then
                if aws secretsmanager update-secret \
                    --region "$AWS_REGION" \
                    --secret-id "$SECRET_NAME" \
                    --secret-string "$updated_secret" >/dev/null 2>&1; then
                    log_success "Atlantis Secrets Manager 웹훅 시크릿 업데이트 완료"
                else
                    log_warning "Secrets Manager 업데이트 실패. 수동으로 webhook_secret 키를 추가하세요."
                fi
            else
                log_warning "시크릿 JSON 생성 실패. 수동으로 webhook_secret 키를 추가하세요."
            fi
        else
            log_warning "기존 시크릿을 읽을 수 없습니다. 수동으로 webhook_secret 키를 추가하세요."
        fi
    fi
}

# StackKit 표준 호환 - 환경변수 우선 처리
if [[ -n "$ATLANTIS_GITHUB_TOKEN" ]]; then
    GITHUB_TOKEN="$ATLANTIS_GITHUB_TOKEN"
    validate_github_token "$GITHUB_TOKEN" || {
        log_error "ATLANTIS_GITHUB_TOKEN 형식이 잘못되었습니다"
        exit 1
    }
    log_info "ATLANTIS_GITHUB_TOKEN 환경변수 사용"
fi

# StackKit 표준 구조 자동 감지 실행
detect_terraform_structure

sync_webhook_secret

# Webhook setup validation
if [[ "$SKIP_WEBHOOK" == false ]]; then
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_warning "GitHub 토큰이 제공되지 않았습니다. 웹훅을 자동 설정하려면 --github-token을 사용하세요."
        log_info "웹훅 설정을 건너뛰려면 --skip-webhook을 사용하세요."
        SKIP_WEBHOOK=true
    fi

    # Check if required tools are available
    if ! command -v curl >/dev/null 2>&1; then
        log_warning "curl이 설치되지 않았습니다. 웹훅 설정을 건너뜁니다."
        SKIP_WEBHOOK=true
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq가 설치되지 않았습니다. 웹훅 설정을 건너뜁니다."
        SKIP_WEBHOOK=true
    fi
fi

log_info "🏗️  StackKit 표준 호환 설정 확인:"
printf "  Atlantis URL: %s\n" "$ATLANTIS_URL"
printf "  저장소: %s\n" "$REPO_NAME"
printf "  프로젝트 디렉토리: %s\n" "$PROJECT_DIR"
printf "  Terraform 버전: %s\n" "$TF_VERSION"
printf "  자동 Plan: %s\n" "$AUTO_PLAN"
printf "  자동 Merge: %s\n" "$AUTO_MERGE"
printf "  웹훅 자동 설정: %s\n" "$(if [[ "$SKIP_WEBHOOK" == false ]]; then echo "활성화"; else echo "비활성화"; fi)"
printf "  Slack 알림: %s\n" "$(if [[ "$ENABLE_SLACK_NOTIFICATIONS" == true ]]; then echo "활성화"; else echo "비활성화"; fi)"
if [[ -n "$SECRET_NAME" ]]; then
    printf "  Secrets Manager: %s\n" "$SECRET_NAME"
    printf "  AWS 리전 (TF_STACK_REGION): %s\n" "$AWS_REGION"
fi
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Git 저장소가 아닙니다."
    exit 1
fi

# Check if project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "프로젝트 디렉토리가 존재하지 않습니다: $PROJECT_DIR"
    exit 1
fi

# Check if project directory has Terraform files
if [[ ! -f "$PROJECT_DIR/main.tf" && ! -f "$PROJECT_DIR/versions.tf" ]]; then
    log_warning "프로젝트 디렉토리에 Terraform 파일이 없습니다: $PROJECT_DIR"
fi

log_info "1/4 atlantis.yaml 설정 파일 생성 중..."

# Safe project name extraction for atlantis config
SAFE_PROJECT_NAME=$(basename "$PROJECT_DIR" 2>/dev/null | sed 's/.*-//' | tr -cd '[:alnum:]-' | head -c 32)
if [[ -z "$SAFE_PROJECT_NAME" ]]; then
    SAFE_PROJECT_NAME="default"
fi

# Generate atlantis.yaml with Slack notifications (if enabled)
if [[ "$ENABLE_SLACK_NOTIFICATIONS" == true ]]; then
    cat > atlantis.yaml << YAML
version: 3
projects:
- name: $SAFE_PROJECT_NAME
  dir: $PROJECT_DIR
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars"]
    enabled: $AUTO_PLAN
  apply_requirements: ["approved", "mergeable"]
  delete_source_branch_on_merge: $AUTO_MERGE
  workflow: slack-notification

workflows:
  slack-notification:
    plan:
      steps:
      - init
      - plan:
          extra_args: ["-lock-timeout=10m"]
      - run: |
          set -e
          
          # Safe environment variable extraction with validation
          REPO_ORG=\$(echo "\${BASE_REPO_OWNER:-unknown}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | head -c 64)
          REPO_NAME=\$(echo "\${BASE_REPO_NAME:-unknown}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | head -c 64)
          PR_NUM=\$(echo "\${PULL_NUM:-0}" | tr -cd '[:digit:]' | head -c 8)
          COMMIT_SHA=\$(echo "\${HEAD_COMMIT:-unknown}" | head -c 8 | tr -cd '[:alnum:]')
          TIMESTAMP=\$(date -u +%Y%m%d%H%M%S)
          
          # Validate PR number
          if [[ "\$PR_NUM" =~ ^[0-9]+\$ ]] && [[ \$PR_NUM -gt 0 ]]; then
            PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/pull/\${PR_NUM}"
          else
            PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}"
          fi
          
          # Check if plan was successful by examining planfile
          PLAN_STATUS="unknown"
          PLAN_COLOR="warning"
          if [[ -n "\$PLANFILE" && -f "\$PLANFILE" ]]; then
            PLAN_STATUS="succeeded"
            PLAN_COLOR="good"
            echo "✅ Plan succeeded - sending Slack notification"
          else
            PLAN_STATUS="failed"
            PLAN_COLOR="danger"
            echo "❌ Plan failed - sending Slack notification"
          fi
          
          # Extract resource change counts safely
          CREATE_COUNT=0
          UPDATE_COUNT=0
          DELETE_COUNT=0
          
          if [[ -n "\$PLANFILE" && -f "\$PLANFILE" ]]; then
            # Try to parse terraform show output for resource counts
            PLAN_TEXT=\$(terraform show "\$PLANFILE" 2>/dev/null || echo "")
            if [[ -n "\$PLAN_TEXT" ]]; then
              # Extract from plan summary line like "Plan: 3 to add, 2 to change, 1 to destroy"
              PLAN_SUMMARY=\$(echo "\$PLAN_TEXT" | grep -E "Plan: [0-9]+ to add" | tail -1 || echo "")
              if [[ -n "\$PLAN_SUMMARY" ]]; then
                CREATE_COUNT=\$(echo "\$PLAN_SUMMARY" | grep -oE '[0-9]+ to add' | grep -oE '[0-9]+' | head -1 || echo "0")
                UPDATE_COUNT=\$(echo "\$PLAN_SUMMARY" | grep -oE '[0-9]+ to change' | grep -oE '[0-9]+' | head -1 || echo "0") 
                DELETE_COUNT=\$(echo "\$PLAN_SUMMARY" | grep -oE '[0-9]+ to destroy' | grep -oE '[0-9]+' | head -1 || echo "0")
              fi
            fi
          fi
          
          # Ensure counts are numeric
          CREATE_COUNT=\${CREATE_COUNT:-0}
          UPDATE_COUNT=\${UPDATE_COUNT:-0}
          DELETE_COUNT=\${DELETE_COUNT:-0}
          
          # Calculate total changes
          TOTAL_CHANGES=\$((CREATE_COUNT + UPDATE_COUNT + DELETE_COUNT))
          
          if [[ \$TOTAL_CHANGES -gt 0 ]]; then
            PLAN_SUMMARY="Plan: \$CREATE_COUNT to add, \$UPDATE_COUNT to change, \$DELETE_COUNT to destroy"
          else
            PLAN_SUMMARY="No changes"
          fi
          
          # Create safe message for Slack (prevent injection)
          SAFE_REPO_NAME=\$(echo "\$REPO_ORG-\$REPO_NAME" | tr -cd '[:alnum:]-')
          SAFE_PLAN_SUMMARY=\$(echo "\$PLAN_SUMMARY" | tr -cd '[:alnum:] ,:-')
          
          # Build PR link safely  
          if [[ "\$PR_NUM" =~ ^[0-9]+\$ ]] && [[ \$PR_NUM -gt 0 ]]; then
            PR_LINK="<\$PR_URL|PR #\$PR_NUM>"
          else
            PR_LINK="Repository"
          fi
          
          ENHANCED_MESSAGE="🏗️ Terraform Plan \$PLAN_STATUS for \$SAFE_REPO_NAME \$PR_LINK\\n\$SAFE_PLAN_SUMMARY"
          
          # Create JSON payload with proper escaping using jq
          if command -v jq >/dev/null 2>&1; then
            JSON_PAYLOAD=\$(jq -n --arg msg "\$ENHANCED_MESSAGE" '{text: \$msg}')
          else
            # Fallback without jq (basic escaping)
            ESCAPED_MESSAGE=\$(echo "\$ENHANCED_MESSAGE" | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g')
            JSON_PAYLOAD="{\"text\": \"\$ESCAPED_MESSAGE\"}"
          fi
          
          # Validate Slack webhook URL
          if [[ -n "\$SLACK_WEBHOOK_URL" && "\$SLACK_WEBHOOK_URL" =~ ^https://hooks\.slack\.com/services/.+ ]]; then
            echo "📤 Slack 알림 전송 중..."
            
            # Send to Slack with timeout and error handling
            CURL_RESPONSE=\$(timeout 30 curl -s -w "\\nHTTP_CODE:%{http_code}" \
              -X POST \
              -H 'Content-type: application/json' \
              -d "\$JSON_PAYLOAD" \
              "\$SLACK_WEBHOOK_URL" 2>/dev/null || echo "CURL_FAILED")
            
            HTTP_CODE=\$(echo "\$CURL_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2 || echo "000")
            
            if [[ "\$HTTP_CODE" = "200" ]]; then
              echo "✅ Plan result sent to Slack"
            else
              echo "⚠️ Slack 전송 실패 (HTTP \$HTTP_CODE)"
            fi
          else
            echo "⚠️ 유효하지 않은 Slack webhook URL"
          fi
    apply:
      steps:
      - apply:
          extra_args: ["-lock-timeout=10m", "-input=false", "\$PLANFILE"]
      - run: |
          set -e
          
          # Safe environment variable extraction
          REPO_ORG=\$(echo "\${BASE_REPO_OWNER:-unknown}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | head -c 64)
          REPO_NAME=\$(echo "\${BASE_REPO_NAME:-unknown}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | head -c 64)
          PR_NUM=\$(echo "\${PULL_NUM:-0}" | tr -cd '[:digit:]' | head -c 8)
          
          # Validate PR number  
          if [[ "\$PR_NUM" =~ ^[0-9]+\$ ]] && [[ \$PR_NUM -gt 0 ]]; then
            PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/pull/\${PR_NUM}"
          else
            PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}"
          fi
          
          # Check apply result (this is run after apply step)
          APPLY_STATUS="succeeded"  # If we reach here, apply succeeded
          APPLY_SUMMARY="Infrastructure deployed successfully"
          
          # Create safe message
          SAFE_REPO_NAME=\$(echo "\$REPO_ORG-\$REPO_NAME" | tr -cd '[:alnum:]-')
          SAFE_APPLY_SUMMARY=\$(echo "\$APPLY_SUMMARY" | tr -cd '[:alnum:] ,:-')
          
          # Build PR link safely
          if [[ "\$PR_NUM" =~ ^[0-9]+\$ ]] && [[ \$PR_NUM -gt 0 ]]; then
            PR_LINK="<\$PR_URL|PR #\$PR_NUM>"
          else
            PR_LINK="Repository"
          fi
          
          ENHANCED_MESSAGE="🚀 Terraform Apply \$APPLY_STATUS for \$SAFE_REPO_NAME \$PR_LINK\\n\$SAFE_APPLY_SUMMARY"
          
          # Create JSON payload safely
          if command -v jq >/dev/null 2>&1; then
            JSON_PAYLOAD=\$(jq -n --arg msg "\$ENHANCED_MESSAGE" '{text: \$msg}')
          else
            ESCAPED_MESSAGE=\$(echo "\$ENHANCED_MESSAGE" | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g')
            JSON_PAYLOAD="{\"text\": \"\$ESCAPED_MESSAGE\"}"
          fi
          
          # Send to Slack with validation
          if [[ -n "\$SLACK_WEBHOOK_URL" && "\$SLACK_WEBHOOK_URL" =~ ^https://hooks\.slack\.com/services/.+ ]]; then
            echo "📤 Slack 알림 전송 중..."
            
            CURL_RESPONSE=\$(timeout 30 curl -s -w "\\nHTTP_CODE:%{http_code}" \
              -X POST \
              -H 'Content-type: application/json' \
              -d "\$JSON_PAYLOAD" \
              "\$SLACK_WEBHOOK_URL" 2>/dev/null || echo "CURL_FAILED")
            
            HTTP_CODE=\$(echo "\$CURL_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2 || echo "000")
            
            if [[ "\$HTTP_CODE" = "200" ]]; then
              echo "✅ Apply result sent to Slack"
            else
              echo "⚠️ Slack 전송 실패 (HTTP \$HTTP_CODE)"
            fi
          else
            echo "⚠️ 유효하지 않은 Slack webhook URL"
          fi
YAML
else
    cat > atlantis.yaml << YAML
version: 3
projects:
- name: $SAFE_PROJECT_NAME
  dir: $PROJECT_DIR
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars"]
    enabled: $AUTO_PLAN
  apply_requirements: ["approved", "mergeable"]
  delete_source_branch_on_merge: $AUTO_MERGE
  workflow: default

workflows:
  default:
    plan:
      steps:
      - init
      - plan:
          extra_args: ["-lock-timeout=10m"]
    apply:
      steps:
      - apply:
          extra_args: ["-lock-timeout=10m", "-input=false", "\$PLANFILE"]
YAML
fi

log_success "atlantis.yaml 파일 생성 완료"

log_info "2/4 .gitignore 업데이트 중..."

# Update .gitignore safely
GITIGNORE_CONTENT="
# Terraform
*.tfplan
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
!terraform.tfvars.example

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
"

# Handle .gitignore updates safely
gitignore_exists=false
if [[ -f ".gitignore" ]]; then
    gitignore_exists=true
fi

if [[ "$gitignore_exists" == true ]]; then
    # Check if Terraform entries already exist
    terraform_exists=false
    if grep -q "# Terraform" .gitignore 2>/dev/null; then
        terraform_exists=true
    fi
    
    if [[ "$terraform_exists" != true ]]; then
        if echo "$GITIGNORE_CONTENT" >> .gitignore 2>/dev/null; then
            log_success ".gitignore에 Terraform 관련 항목 추가"
        else
            log_warning ".gitignore 업데이트 실패 - 권한 확인 필요"
        fi
    else
        log_info ".gitignore에 이미 Terraform 관련 항목 존재"
    fi
else
    if echo "$GITIGNORE_CONTENT" > .gitignore 2>/dev/null; then
        log_success ".gitignore 파일 생성 완료"
    else
        log_warning ".gitignore 생성 실패 - 권한 확인 필요"
    fi
fi

log_info "3/4 README.md 업데이트 중..."

# Add Atlantis usage to README
ATLANTIS_SECTION="
## 🤖 Atlantis를 통한 Terraform 자동화

이 저장소는 [Atlantis](${ATLANTIS_URL})를 통해 Terraform을 자동화합니다.

### 사용법

1. **Plan 실행**: PR에서 \`atlantis plan\` 댓글 작성
2. **Apply 실행**: PR 승인 후 \`atlantis apply\` 댓글 작성

### 명령어

- \`atlantis plan\` - Terraform plan 실행
- \`atlantis apply\` - Terraform apply 실행 (승인 필요)
- \`atlantis plan -d ${PROJECT_DIR}\` - 특정 디렉토리만 plan
- \`atlantis unlock\` - 잠금 해제 (필요시)

### 자동 Plan

$(if [[ "$AUTO_PLAN" == true ]]; then
echo "✅ 자동 Plan 활성화됨 - .tf 파일 변경 시 자동으로 plan 실행"
else
echo "❌ 수동 Plan 모드 - 댓글로 직접 실행 필요"
fi)
"

# Handle README.md updates safely
readme_exists=false
if [[ -f "README.md" ]]; then
    readme_exists=true
fi

if [[ "$readme_exists" == true ]]; then
    # Check if Atlantis section already exists
    atlantis_exists=false
    if grep -q "Atlantis를 통한 Terraform 자동화" README.md 2>/dev/null; then
        atlantis_exists=true
    fi
    
    if [[ "$atlantis_exists" != true ]]; then
        if echo "$ATLANTIS_SECTION" >> README.md 2>/dev/null; then
            log_success "README.md에 Atlantis 사용법 추가"
        else
            log_warning "README.md 업데이트 실패 - 권한 확인 필요"
        fi
    else
        log_info "README.md에 이미 Atlantis 관련 내용 존재"
    fi
else
    # Create new README.md safely
    local current_dir_name=""
    current_dir_name=$(basename "$PWD" 2>/dev/null | head -c 64 | tr -cd '[:alnum:]-_.')
    if [[ -z "$current_dir_name" ]]; then
        current_dir_name="Project"
    fi
    
    if { echo "# $current_dir_name" && echo "$ATLANTIS_SECTION"; } > README.md 2>/dev/null; then
        log_success "README.md 파일 생성 완료"
    else
        log_warning "README.md 생성 실패 - 권한 확인 필요"
    fi
fi

# GitHub webhook auto-setup function with enhanced security
setup_github_webhook() {
    if [[ "$SKIP_WEBHOOK" == true ]]; then
        return 0
    fi

    log_info "GitHub 웹훅 자동 설정 시작..."

    local webhook_url="${ATLANTIS_URL}/events"
    
    # Create webhook configuration using jq for safety
    local webhook_config=""
    if command -v jq >/dev/null 2>&1; then
        webhook_config=$(jq -n \
            --arg url "$webhook_url" \
            --arg secret "$WEBHOOK_SECRET" \
            '{
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
                    "url": $url,
                    "content_type": "json", 
                    "secret": $secret,
                    "insecure_ssl": "0"
                }
            }' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$webhook_config" ]]; then
        log_error "웹훅 설정 JSON 생성 실패"
        return 1
    fi

    # Check if webhook already exists
    log_info "기존 웹훅 존재 여부 확인 중..."
    local existing_webhook=""
    local webhook_response=""
    
    webhook_response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "User-Agent: stackkit-atlantis-connect/1.0" \
        "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null || echo "")
        
    if [[ -n "$webhook_response" && "$webhook_response" != "null" ]] && command -v jq >/dev/null 2>&1; then
        existing_webhook=$(echo "$webhook_response" | jq -r ".[] | select(.config.url == \"$webhook_url\") | .id" 2>/dev/null || echo "")
    fi

    local response=""
    if [[ -n "$existing_webhook" ]]; then
        log_success "기존 웹훅 발견 (ID: $existing_webhook). 설정을 업데이트합니다."

        # Update existing webhook
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -H "User-Agent: stackkit-atlantis-connect/1.0" \
            -X PATCH \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks/$existing_webhook" 2>/dev/null || echo "")
    else
        log_info "새 웹훅을 생성합니다."

        # Create new webhook
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -H "User-Agent: stackkit-atlantis-connect/1.0" \
            -X POST \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null || echo "")
    fi

    # Parse response safely
    local http_status=""
    local response_body=""
    if [[ -n "$response" ]]; then
        http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null | tr -cd '[:digit:]')
        response_body=$(echo "$response" | sed '/HTTP_STATUS:/d' 2>/dev/null || echo "")
    fi
    http_status=${http_status:-"000"}

    case $http_status in
        200)
            log_success "기존 GitHub 웹훅이 성공적으로 업데이트되었습니다!"
            local webhook_id=""
            if [[ -n "$response_body" ]] && command -v jq >/dev/null 2>&1; then
                webhook_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null | tr -cd '[:digit:]')
            fi
            printf "   - 웹훅 ID: %s\n" "${webhook_id:-unknown}"
            printf "   - URL: %s\n" "$webhook_url"
            echo "   - 상태: 활성화됨"
            ;;
        201)
            log_success "GitHub 웹훅이 성공적으로 생성되었습니다!"
            local webhook_id=""
            if [[ -n "$response_body" ]] && command -v jq >/dev/null 2>&1; then
                webhook_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null | tr -cd '[:digit:]')
            fi
            printf "   - 웹훅 ID: %s\n" "${webhook_id:-unknown}"
            printf "   - URL: %s\n" "$webhook_url"
            ;;
        422)
            local error_message="Unknown error"
            if [[ -n "$response_body" ]] && command -v jq >/dev/null 2>&1; then
                error_message=$(echo "$response_body" | jq -r '.errors[0].message // .message // "Unknown error"' 2>/dev/null)
            fi
            
            if [[ "$error_message" == *"Hook already exists"* ]]; then
                log_warning "웹훅이 이미 존재합니다. 기존 웹훅을 사용합니다."
            else
                log_error "웹훅 생성 실패: $error_message"
                return 1
            fi
            ;;
        401)
            log_error "GitHub 토큰이 잘못되었거나 권한이 없습니다."
            return 1
            ;;
        404)
            log_error "저장소를 찾을 수 없습니다: $REPO_NAME"
            return 1
            ;;
        *)
            log_error "웹훅 생성 실패 (HTTP $http_status)"
            return 1
            ;;
    esac

    return 0
}

# GitHub repository variables setup function with security
setup_github_variables() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_warning "GitHub 토큰이 없어서 레포 변수 설정을 건너뜁니다."
        return 0
    fi

    log_info "GitHub 레포 변수 자동 설정 시작..."

    # Extract safe org name from repo
    local org_name=""
    org_name=$(echo "$REPO_NAME" | cut -d'/' -f1 | tr -cd '[:alnum:]-_' | head -c 64)
    
    # Create variables configuration safely using jq
    local variables_config=""
    if command -v jq >/dev/null 2>&1; then
        variables_config=$(jq -n \
            --arg region "$AWS_REGION" \
            --arg org "$org_name" \
            '[
                {"name": "ATLANTIS_REGION", "value": $region},
                {"name": "ATLANTIS_ORG_NAME", "value": $org},
                {"name": "ATLANTIS_ENVIRONMENT", "value": "prod"}
            ]' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$variables_config" ]]; then
        log_warning "변수 설정 생성 실패"
        return 1
    fi

    log_info "필수 GitHub Variables 설정 중..."
    
    # Process each variable safely
    echo "$variables_config" | jq -c '.[]' 2>/dev/null | while IFS= read -r var; do
        if [[ -z "$var" ]]; then
            continue
        fi
        
        local name=""
        local value=""
        name=$(echo "$var" | jq -r '.name' 2>/dev/null | tr -cd '[:alnum:]_' | head -c 64)
        value=$(echo "$var" | jq -r '.value' 2>/dev/null | head -c 256)
        
        if [[ -z "$name" ]]; then
            continue
        fi

        log_info "변수 설정 중: $name = $value"

        # Create variable JSON safely
        local var_json=""
        if command -v jq >/dev/null 2>&1; then
            var_json=$(jq -n --arg name "$name" --arg value "$value" '{name: $name, value: $value}' 2>/dev/null || echo "")
        fi
        
        if [[ -z "$var_json" ]]; then
            log_warning "변수 JSON 생성 실패: $name"
            continue
        fi

        # Set repository variable
        local response=""
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Content-Type: application/json" \
            -H "User-Agent: stackkit-atlantis-connect/1.0" \
            -X POST \
            -d "$var_json" \
            "https://api.github.com/repos/$REPO_NAME/actions/variables" 2>/dev/null || echo "")

        local http_status=""
        if [[ -n "$response" ]]; then
            http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null | tr -cd '[:digit:]')
        fi
        http_status=${http_status:-"000"}
        
        case $http_status in
            201)
                log_success "GitHub Variable '$name' 설정 완료"
                ;;
            409)
                # Variable already exists, try to update
                local update_response=""
                update_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    -H "Content-Type: application/json" \
                    -H "User-Agent: stackkit-atlantis-connect/1.0" \
                    -X PATCH \
                    -d "$var_json" \
                    "https://api.github.com/repos/$REPO_NAME/actions/variables/$name" 2>/dev/null || echo "")

                local update_status=""
                if [[ -n "$update_response" ]]; then
                    update_status=$(echo "$update_response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null | tr -cd '[:digit:]')
                fi
                update_status=${update_status:-"000"}
                
                if [[ "$update_status" == "204" ]]; then
                    log_success "GitHub Variable '$name' 업데이트 완료"
                else
                    log_warning "Variable '$name' 업데이트 실패 (Status: $update_status)"
                fi
                ;;
            *)
                log_warning "Variable '$name' 설정 실패 (Status: $http_status)"
                ;;
        esac
    done

    log_success "GitHub 레포 변수 설정 완료"
}

log_info "4/6 GitHub 웹훅 자동 설정 중..."
setup_github_webhook

log_info "5/6 GitHub 레포 변수 자동 설정 중..."  
setup_github_variables

log_info "6/6 설정 요약 출력 중..."

log_success "저장소 Atlantis 연결 설정 완료!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 다음 단계:"
echo ""
printf "1. Atlantis 서버에 이 저장소 추가:\n"
printf "   - repo_allowlist에 'github.com/%s' 추가\n" "$REPO_NAME"
echo ""

if [[ "$SKIP_WEBHOOK" == true ]]; then
    echo "2. GitHub 웹훅 수동 설정:"
    printf "   - URL: %s/events\n" "$ATLANTIS_URL"
    echo "   - Events: Pull requests, Issue comments, Push"
    echo "   - Content type: application/json"
    printf "   - Secret: %s\n" "${WEBHOOK_SECRET:0:8}..."
    echo ""
else
    echo "2. ✅ GitHub 웹훅 자동 설정 완료"
    echo ""
fi

echo "3. 변경사항 커밋 및 푸시:"
echo "   git add atlantis.yaml .gitignore README.md"
echo "   git commit -m 'feat: add Atlantis configuration'"
echo "   git push origin main"
echo ""
echo "4. PR 생성하여 테스트:"
echo "   - Terraform 파일 수정 후 PR 생성"
echo "   - 'atlantis plan' 댓글로 테스트"
if [[ "$ENABLE_SLACK_NOTIFICATIONS" == true ]]; then
    echo "   - 📤 Plan/Apply 결과가 Slack으로 자동 전송"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$SKIP_WEBHOOK" == false ]]; then
    echo "🔐 보안 정보:"
    printf "   - 웹훅 시크릿: %s...\n" "${WEBHOOK_SECRET:0:8}"
    echo "   - 이 시크릿을 안전한 곳에 보관하세요"
    echo ""
fi

log_success "Happy Infrastructure as Code! 🚀"