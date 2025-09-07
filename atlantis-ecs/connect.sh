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

# Parse arguments with safety checks
while [[ $# -gt 0 ]]; do
    case $1 in
        --atlantis-url)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--atlantis-url requires a value"
                show_help
                exit 1
            fi
            ATLANTIS_URL="$2"
            shift 2
            ;;
        --repo-name)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--repo-name requires a value"
                show_help
                exit 1
            fi
            REPO_NAME="$2"
            shift 2
            ;;
        --project-dir)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--project-dir requires a value"
                show_help
                exit 1
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --github-token)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--github-token requires a value"
                show_help
                exit 1
            fi
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --webhook-secret)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--webhook-secret requires a value"
                show_help
                exit 1
            fi
            WEBHOOK_SECRET="$2"
            shift 2
            ;;
        --secret-name)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--secret-name requires a value"
                show_help
                exit 1
            fi
            SECRET_NAME="$2"
            shift 2
            ;;
        --aws-region)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--aws-region requires a value"
                show_help
                exit 1
            fi
            AWS_REGION="$2"
            shift 2
            ;;
        --auto-plan) AUTO_PLAN=true; shift ;;
        --auto-merge) AUTO_MERGE=true; shift ;;
        --skip-webhook) SKIP_WEBHOOK=true; shift ;;
        --enable-slack-notifications) ENABLE_SLACK_NOTIFICATIONS=true; shift ;;
        --help) show_help; exit 0 ;;
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

if [[ -z "$REPO_NAME" ]]; then
    # GitHub remote에서 자동으로 repo 이름 추출 시도
    set +e
    git_available=$(command -v git >/dev/null 2>&1 && echo "true" || echo "false")
    if [[ "$git_available" == "true" ]]; then
        remote_available=$(git remote -v >/dev/null 2>&1 && echo "true" || echo "false")
        if [[ "$remote_available" == "true" ]]; then
            origin_url=$(git remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$origin_url" ]]; then
                REPO_NAME=$(echo "$origin_url" | sed 's|.*github.com[/:]||' | sed 's|\.git$||' 2>/dev/null || echo "")
                if [[ -n "$REPO_NAME" && "$REPO_NAME" != "$origin_url" ]]; then
                    log_info "GitHub remote에서 저장소 이름 자동 탐지: $REPO_NAME"
                fi
            fi
        fi
    fi
    set -e

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
        
        # StackKit 표준 경로들 검사 (참고용)
        # local candidates=(
        #     "terraform/stacks"
        #     "terraform"
        #     "."
        # )
        
        local found_stacks=()
        
        # terraform/stacks 구조 우선 검사
        if [[ -d "terraform/stacks" ]]; then
            log_info "terraform/stacks 디렉토리 발견, 스택 검사 중..."
            
            # backend.hcl이 있는 스택 디렉토리 찾기
            while IFS= read -r -d '' stack_dir; do
                found_stacks+=("$(dirname "$stack_dir")")
            done < <(find terraform/stacks -name "backend.hcl" -type f -print0 2>/dev/null || true)
            
            if [[ ${#found_stacks[@]} -gt 0 ]]; then
                # 첫 번째 스택을 기본값으로 사용
                PROJECT_DIR="${found_stacks[0]}"
                log_success "StackKit 스택 자동 감지: $PROJECT_DIR"
                
                if [[ ${#found_stacks[@]} -gt 1 ]]; then
                    log_info "추가 스택 발견:"
                    for ((i=1; i<${#found_stacks[@]}; i++)); do
                        echo "  - ${found_stacks[$i]}"
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

# Sync webhook secret with Atlantis Secrets Manager
sync_webhook_secret() {
    if [[ -z "$WEBHOOK_SECRET" ]]; then
        if [[ -n "$SECRET_NAME" ]]; then
            log_info "Atlantis Secrets Manager에서 웹훅 시크릿 조회 중..."

            # AWS CLI 사용 가능한지 확인
            if ! command -v aws >/dev/null 2>&1; then
                log_warning "AWS CLI가 설치되지 않았습니다. 새 시크릿을 생성합니다."
                WEBHOOK_SECRET=$(openssl rand -hex 20)
                return
            fi

            # 기존 시크릿에서 webhook_secret 조회
            local EXISTING_SECRET=""
            set +e
            local secret_response
            secret_response=$(aws secretsmanager get-secret-value \
                --region "$AWS_REGION" \
                --secret-id "$SECRET_NAME" \
                --query 'SecretString' \
                --output text 2>/dev/null)
            
            aws_result=$?
            if [[ $aws_result -eq 0 && -n "$secret_response" && "$secret_response" != "null" ]]; then
                EXISTING_SECRET=$(echo "$secret_response" | jq -r '.webhook_secret // empty' 2>/dev/null || echo "")
            fi
            set -e

            if [[ -n "$EXISTING_SECRET" && "$EXISTING_SECRET" != "null" && "$EXISTING_SECRET" != "empty" ]]; then
                WEBHOOK_SECRET="$EXISTING_SECRET"
                log_success "기존 Atlantis 웹훅 시크릿 사용: ${WEBHOOK_SECRET:0:8}..."
            else
                log_warning "기존 웹훅 시크릿을 찾을 수 없습니다. 새 시크릿을 생성합니다."
                set +e
                local rand_secret
                rand_secret=$(openssl rand -hex 20 2>/dev/null)
                if [[ $? -eq 0 && -n "$rand_secret" ]]; then
                    WEBHOOK_SECRET="$rand_secret"
                else
                    # openssl이 실패하면 fallback 방법 사용
                    WEBHOOK_SECRET=$(date +%s | sha256sum | head -c 40 2>/dev/null || echo "$(date +%s)$(whoami)" | sha256sum | head -c 40)
                fi
                set -e

                # Secrets Manager 업데이트
                update_secrets_manager
            fi
        else
            set +e
            local rand_secret
            rand_secret=$(openssl rand -hex 20 2>/dev/null)
            if [[ $? -eq 0 && -n "$rand_secret" ]]; then
                WEBHOOK_SECRET="$rand_secret"
            else
                # openssl이 실패하면 fallback 방법 사용
                WEBHOOK_SECRET=$(date +%s | sha256sum | head -c 40 2>/dev/null || echo "$(date +%s)$(whoami)" | sha256sum | head -c 40)
            fi
            set -e
            log_info "새 웹훅 시크릿 생성: ${WEBHOOK_SECRET:0:8}..."
        fi
    fi
}

# Update Atlantis Secrets Manager with new webhook secret
update_secrets_manager() {
    if [[ -n "$SECRET_NAME" ]] && command -v aws >/dev/null 2>&1; then
        log_info "Atlantis Secrets Manager에 웹훅 시크릿 업데이트 중..."

        # 현재 시크릿 값 조회
        CURRENT_SECRET=$(aws secretsmanager get-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$SECRET_NAME" \
            --query 'SecretString' \
            --output text 2>/dev/null)

        if [[ -n "$CURRENT_SECRET" ]]; then
            # 기존 시크릿에 webhook_secret 추가/업데이트
            UPDATED_SECRET=$(echo "$CURRENT_SECRET" | jq --arg secret "$WEBHOOK_SECRET" '. + {"webhook_secret": $secret}')

            aws secretsmanager update-secret \
                --region "$AWS_REGION" \
                --secret-id "$SECRET_NAME" \
                --secret-string "$UPDATED_SECRET" >/dev/null 2>&1

            if [[ $? -eq 0 ]]; then
                log_success "Atlantis Secrets Manager 웹훅 시크릿 업데이트 완료"
            else
                log_warning "Secrets Manager 업데이트 실패. 수동으로 webhook_secret 키를 추가하세요."
            fi
        fi
    fi
}

# StackKit 표준 호환 - 환경변수 우선 처리
if [[ -n "$ATLANTIS_GITHUB_TOKEN" ]]; then
    GITHUB_TOKEN="$ATLANTIS_GITHUB_TOKEN"
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

    # Check if curl/jq are available
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
echo "  Atlantis URL: $ATLANTIS_URL"
echo "  저장소: $REPO_NAME"
echo "  프로젝트 디렉토리: $PROJECT_DIR"
echo "  Terraform 버전: $TF_VERSION"
echo "  자동 Plan: $AUTO_PLAN"
echo "  자동 Merge: $AUTO_MERGE"
echo "  웹훅 자동 설정: $([ "$SKIP_WEBHOOK" == false ] && echo "활성화" || echo "비활성화")"
echo "  Slack 알림: $([ "$ENABLE_SLACK_NOTIFICATIONS" == true ] && echo "활성화" || echo "비활성화")"
if [[ -n "$SECRET_NAME" ]]; then
    echo "  Secrets Manager: $SECRET_NAME"
    echo "  AWS 리전 (TF_STACK_REGION): $AWS_REGION"
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

# Generate atlantis.yaml with Slack notifications
if [[ "$ENABLE_SLACK_NOTIFICATIONS" == true ]]; then
    cat > atlantis.yaml << YAML
version: 3
projects:
- name: $(basename "$PROJECT_DIR" | sed 's/.*-//')
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

          # Extract repo and PR info from environment
          REPO_ORG=\$(echo "\$BASE_REPO_OWNER" | tr '[:upper:]' '[:lower:]')
          REPO_NAME=\$(echo "\$BASE_REPO_NAME" | tr '[:upper:]' '[:lower:]')
          PR_NUM=\$PULL_NUM
          COMMIT_SHA=\$(echo "\$HEAD_COMMIT" | cut -c1-8)
          TIMESTAMP=\$(date -u +%Y%m%d%H%M%S)
          PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/pull/\${PR_NUM}"

          # Check if plan was successful
          if [ -f "\$PLANFILE" ]; then
            PLAN_STATUS="succeeded"
            PLAN_COLOR="good"
            echo "✅ Plan succeeded - sending Slack notification"
          else
            PLAN_STATUS="failed"
            PLAN_COLOR="danger"
            echo "❌ Plan failed - sending Slack notification"
          fi

          # Generate change analysis for bot consumption
          CHANGE_SUMMARY=""
          RESOURCE_COUNTS=""
          COST_INFO=""
          
          if [ -n "\$PLANFILE" ]; then
            echo "🔍 DEBUG - Plan 파일 분석:"
            echo "  PLANFILE 경로: \$PLANFILE"
            echo "  파일 존재 확인: \$([ -f "\$PLANFILE" ] && echo "Yes" || echo "No")"
            echo "  파일 크기: \$([ -f "\$PLANFILE" ] && ls -lh "\$PLANFILE" | awk '{print \$5}' || echo "N/A")"
            
            # Extract resource change counts from plan with enhanced debugging
            if terraform show -json "\$PLANFILE" > plan_analysis.json 2>/dev/null; then
              echo "  JSON 변환: 성공"
              
              # Debug: JSON 구조 분석
              echo "🔍 DEBUG - JSON 구조 분석:"
              JSON_SIZE=\$(wc -c < plan_analysis.json 2>/dev/null || echo "0")
              echo "  JSON 파일 크기: \${JSON_SIZE} bytes"
              
              # JSON 유효성 검사 먼저 수행 (안전장치)
              set +e
              JSON_VALID=\$(jq empty plan_analysis.json 2>/dev/null && echo "true" || echo "false")
              set -e
              JSON_VALID=\${JSON_VALID:-false}
              echo "  JSON 유효성: \$JSON_VALID"
              
              if [[ "\$JSON_VALID" == "false" ]]; then
                echo "  ⚠️  JSON 파싱 오류 감지 - 파일 내용 샘플:"
                head -c 200 plan_analysis.json || echo "  파일 읽기 실패"
                echo ""
                echo "  JSON 오류 확인:"
                jq empty plan_analysis.json 2>&1 | head -3 || echo "  jq 오류 확인 실패"
                echo ""
                echo "  대체 방법 시도 중..."
              else
                echo "  JSON 파싱: 성공"
              fi
              
              # Check for main structure keys (JSON이 유효한 경우에만, 안전장치)
              if [[ "\$JSON_VALID" == "true" ]]; then
                set +e
                HAS_RESOURCE_CHANGES=\$(jq 'has("resource_changes")' plan_analysis.json 2>/dev/null)
                HAS_PLANNED_VALUES=\$(jq 'has("planned_values")' plan_analysis.json 2>/dev/null)
                HAS_CONFIGURATION=\$(jq 'has("configuration")' plan_analysis.json 2>/dev/null)
                set -e
                
                # 안전한 기본값 설정
                HAS_RESOURCE_CHANGES=\${HAS_RESOURCE_CHANGES:-false}
                HAS_PLANNED_VALUES=\${HAS_PLANNED_VALUES:-false}
                HAS_CONFIGURATION=\${HAS_CONFIGURATION:-false}
                
                echo "  JSON 구조 확인:"
                echo "    - resource_changes: \$HAS_RESOURCE_CHANGES"
                echo "    - planned_values: \$HAS_PLANNED_VALUES"
                echo "    - configuration: \$HAS_CONFIGURATION"
              else
                echo "  JSON 파싱 실패로 구조 확인 불가"
                HAS_RESOURCE_CHANGES="false"
                HAS_PLANNED_VALUES="false"
                HAS_CONFIGURATION="false"
              fi
              
              if [[ "\$HAS_RESOURCE_CHANGES" == "true" ]]; then
                # Count resource_changes array length
                RESOURCE_CHANGES_COUNT=\$(jq '.resource_changes | length' plan_analysis.json 2>/dev/null || echo "0")
                echo "    - resource_changes 배열 길이: \$RESOURCE_CHANGES_COUNT"
                
                # Sample first resource change structure
                if [[ "\$RESOURCE_CHANGES_COUNT" -gt "0" ]]; then
                  echo "  첫 번째 resource_change 구조 샘플:"
                  jq -r '.resource_changes[0] | keys[]' plan_analysis.json 2>/dev/null | head -5 | while read key; do
                    echo "    - \$key"
                  done
                  
                  # Check if change.actions exists
                  FIRST_CHANGE_ACTIONS=\$(jq -r '.resource_changes[0].change.actions // "null"' plan_analysis.json 2>/dev/null)
                  echo "    - change.actions: \$FIRST_CHANGE_ACTIONS"
                fi
              else
                echo "  resource_changes 키가 없음 - 전체 JSON 구조 분석:"
                echo "  JSON 최상위 키들:"
                jq -r 'keys[]' plan_analysis.json 2>/dev/null | head -10 | while read key; do
                  echo "    - \$key"
                done
                
                # Try to find alternative structures (안전장치)
                set +e
                HAS_PRIOR_STATE=\$(jq 'has("prior_state")' plan_analysis.json 2>/dev/null)
                HAS_RESOURCE_DRIFT=\$(jq 'has("resource_drift")' plan_analysis.json 2>/dev/null)
                HAS_OUTPUT_CHANGES=\$(jq 'has("output_changes")' plan_analysis.json 2>/dev/null)
                set -e
                
                # 안전한 기본값
                HAS_PRIOR_STATE=\${HAS_PRIOR_STATE:-false}
                HAS_RESOURCE_DRIFT=\${HAS_RESOURCE_DRIFT:-false}
                HAS_OUTPUT_CHANGES=\${HAS_OUTPUT_CHANGES:-false}
                
                echo "  대체 구조 확인:"
                echo "    - prior_state: \$HAS_PRIOR_STATE"
                echo "    - resource_drift: \$HAS_RESOURCE_DRIFT"  
                echo "    - output_changes: \$HAS_OUTPUT_CHANGES"
                
                # Check if this is a different JSON format (안전장치)
                set +e
                HAS_DESTROY=\$(jq 'has("destroy")' plan_analysis.json 2>/dev/null)
                HAS_CREATE=\$(jq 'has("create")' plan_analysis.json 2>/dev/null)
                HAS_UPDATE=\$(jq 'has("update")' plan_analysis.json 2>/dev/null)
                set -e
                
                # 안전한 기본값
                HAS_DESTROY=\${HAS_DESTROY:-false}
                HAS_CREATE=\${HAS_CREATE:-false}
                HAS_UPDATE=\${HAS_UPDATE:-false}
                
                if [[ "\$HAS_DESTROY" == "true" || "\$HAS_CREATE" == "true" || "\$HAS_UPDATE" == "true" ]]; then
                  echo "  다른 형식의 plan JSON 감지됨:"
                  echo "    - create: \$HAS_CREATE"
                  echo "    - update: \$HAS_UPDATE" 
                  echo "    - destroy: \$HAS_DESTROY"
                fi
              fi
              
              # Try different jq queries for resource counting
              echo "🔍 DEBUG - 다양한 jq 쿼리 테스트:"
              
              # Strategy 1: Modern Terraform format (1.7.5+) with resource_changes array
              if [[ "\$JSON_VALID" == "true" && "\$HAS_RESOURCE_CHANGES" == "true" ]]; then
                echo "  🔄 전략 1: Modern Terraform 형식으로 파싱 시도"
                
                # Disable exit-on-error temporarily for safer jq execution
                set +e
                CREATE_COUNT=\$(jq -r '[.resource_changes[]? | select(.change.actions[]? == "create")] | length' plan_analysis.json 2>/dev/null)
                UPDATE_COUNT=\$(jq -r '[.resource_changes[]? | select(.change.actions[]? == "update")] | length' plan_analysis.json 2>/dev/null)
                DELETE_COUNT=\$(jq -r '[.resource_changes[]? | select(.change.actions[]? == "delete")] | length' plan_analysis.json 2>/dev/null)
                set -e
                
                # Ensure numeric values
                CREATE_COUNT=\${CREATE_COUNT:-0}
                UPDATE_COUNT=\${UPDATE_COUNT:-0}
                DELETE_COUNT=\${DELETE_COUNT:-0}
                
                echo "    원본 쿼리 결과: CREATE=\$CREATE_COUNT, UPDATE=\$UPDATE_COUNT, DELETE=\$DELETE_COUNT"
                
                # Alternative query for modern format
                set +e
                CREATE_COUNT_ALT1=\$(jq -r '[.resource_changes[] | select(.change.actions | contains(["create"]))] | length' plan_analysis.json 2>/dev/null)
                UPDATE_COUNT_ALT1=\$(jq -r '[.resource_changes[] | select(.change.actions | contains(["update"]))] | length' plan_analysis.json 2>/dev/null)
                DELETE_COUNT_ALT1=\$(jq -r '[.resource_changes[] | select(.change.actions | contains(["delete"]))] | length' plan_analysis.json 2>/dev/null)
                set -e
                
                # Ensure numeric values
                CREATE_COUNT_ALT1=\${CREATE_COUNT_ALT1:-0}
                UPDATE_COUNT_ALT1=\${UPDATE_COUNT_ALT1:-0}
                DELETE_COUNT_ALT1=\${DELETE_COUNT_ALT1:-0}
                
                echo "    대체 쿼리1 결과: CREATE=\$CREATE_COUNT_ALT1, UPDATE=\$UPDATE_COUNT_ALT1, DELETE=\$DELETE_COUNT_ALT1"
              else
                echo "  ⚠️  전략 1 실패: resource_changes 필드 없음"
                CREATE_COUNT=0
                UPDATE_COUNT=0
                DELETE_COUNT=0
                CREATE_COUNT_ALT1=0
                UPDATE_COUNT_ALT1=0
                DELETE_COUNT_ALT1=0
              fi
              
              # Strategy 2: Try legacy format or alternative structure
              echo "  🔄 전략 2: 레거시 형식 또는 대체 구조로 파싱 시도"
              set +e
              HAS_PLANNED_VALUES_RESOURCES=\$(jq 'has("planned_values") and (.planned_values | has("root_module")) and (.planned_values.root_module | has("resources"))' plan_analysis.json 2>/dev/null)
              set -e
              HAS_PLANNED_VALUES_RESOURCES=\${HAS_PLANNED_VALUES_RESOURCES:-false}
              
              if [[ "\$HAS_PLANNED_VALUES_RESOURCES" == "true" ]]; then
                # Try to count from planned_values structure (안전장치)
                set +e
                PLANNED_RESOURCES_COUNT=\$(jq '.planned_values.root_module.resources | length' plan_analysis.json 2>/dev/null)
                set -e
                PLANNED_RESOURCES_COUNT=\${PLANNED_RESOURCES_COUNT:-0}
                echo "    planned_values 리소스 개수: \$PLANNED_RESOURCES_COUNT"
                
                # For legacy format, assume all resources are creates if no resource_changes
                if [[ "\$CREATE_COUNT" == "0" && "\$PLANNED_RESOURCES_COUNT" != "0" ]]; then
                  CREATE_COUNT=\$PLANNED_RESOURCES_COUNT
                  echo "    레거시 추정: CREATE=\$CREATE_COUNT (planned_values 기반)"
                fi
              fi
              
              # Strategy 3: Try to parse from terraform plan text output as fallback
              echo "  🔄 전략 3: Plan 텍스트 출력에서 파싱 시도"
              if [[ -f "\$PLANFILE" ]]; then
                PLAN_TEXT=\$(terraform show "\$PLANFILE" 2>/dev/null || echo "")
                if [[ -n "\$PLAN_TEXT" ]]; then
                  # Extract numbers from plan summary like "Plan: 3 to add, 2 to change, 1 to destroy"
                  PLAN_SUMMARY=\$(echo "\$PLAN_TEXT" | grep -E "Plan: [0-9]+ to add" | tail -1)
                  if [[ -n "\$PLAN_SUMMARY" ]]; then
                    CREATE_COUNT_TEXT=\$(echo "\$PLAN_SUMMARY" | sed -n 's/.*Plan: \([0-9]\+\) to add.*/\1/p' || echo "0")
                    UPDATE_COUNT_TEXT=\$(echo "\$PLAN_SUMMARY" | sed -n 's/.* \([0-9]\+\) to change.*/\1/p' || echo "0")
                    DELETE_COUNT_TEXT=\$(echo "\$PLAN_SUMMARY" | sed -n 's/.* \([0-9]\+\) to destroy.*/\1/p' || echo "0")
                    
                    echo "    텍스트 파싱 결과: CREATE=\$CREATE_COUNT_TEXT, UPDATE=\$UPDATE_COUNT_TEXT, DELETE=\$DELETE_COUNT_TEXT"
                    
                    # Use text parsing if JSON parsing failed
                    if [[ "\$CREATE_COUNT" == "0" && "\$CREATE_COUNT_TEXT" != "0" ]]; then CREATE_COUNT=\$CREATE_COUNT_TEXT; fi
                    if [[ "\$UPDATE_COUNT" == "0" && "\$UPDATE_COUNT_TEXT" != "0" ]]; then UPDATE_COUNT=\$UPDATE_COUNT_TEXT; fi
                    if [[ "\$DELETE_COUNT" == "0" && "\$DELETE_COUNT_TEXT" != "0" ]]; then DELETE_COUNT=\$DELETE_COUNT_TEXT; fi
                  fi
                fi
              fi
              
              # Alternative query 2: Direct actions array check
              ALL_ACTIONS=\$(jq -r '[.resource_changes[].change.actions[]] | group_by(.) | map({action: .[0], count: length}) | .[]' plan_analysis.json 2>/dev/null || echo "[]")
              if [[ -n "\$ALL_ACTIONS" && "\$ALL_ACTIONS" != "[]" ]]; then
                echo "  모든 액션 통계:"
                echo "\$ALL_ACTIONS" | jq -r '"    - " + .action + ": " + (.count | tostring)' 2>/dev/null || true
                
                # Safe jq queries with explicit defaults - won't fail with set -e
                set +e  # Temporarily disable exit on error for jq queries
                CREATE_COUNT_ALT2=\$(echo "\$ALL_ACTIONS" | jq -r 'select(.action == "create") | .count // 0' 2>/dev/null)
                UPDATE_COUNT_ALT2=\$(echo "\$ALL_ACTIONS" | jq -r 'select(.action == "update") | .count // 0' 2>/dev/null)
                DELETE_COUNT_ALT2=\$(echo "\$ALL_ACTIONS" | jq -r 'select(.action == "delete") | .count // 0' 2>/dev/null)
                set -e  # Re-enable exit on error
                
                # Ensure we have numeric values
                CREATE_COUNT_ALT2=\${CREATE_COUNT_ALT2:-0}
                UPDATE_COUNT_ALT2=\${UPDATE_COUNT_ALT2:-0}
                DELETE_COUNT_ALT2=\${DELETE_COUNT_ALT2:-0}
                
                echo "  대체 쿼리2 결과: CREATE=\$CREATE_COUNT_ALT2, UPDATE=\$UPDATE_COUNT_ALT2, DELETE=\$DELETE_COUNT_ALT2"
              fi
              
              # Ensure all counts are numeric (fix empty values)
              CREATE_COUNT=\${CREATE_COUNT:-0}
              UPDATE_COUNT=\${UPDATE_COUNT:-0}
              DELETE_COUNT=\${DELETE_COUNT:-0}
              CREATE_COUNT_ALT1=\${CREATE_COUNT_ALT1:-0}
              UPDATE_COUNT_ALT1=\${UPDATE_COUNT_ALT1:-0}
              DELETE_COUNT_ALT1=\${DELETE_COUNT_ALT1:-0}
              CREATE_COUNT_ALT2=\${CREATE_COUNT_ALT2:-0}
              UPDATE_COUNT_ALT2=\${UPDATE_COUNT_ALT2:-0}
              DELETE_COUNT_ALT2=\${DELETE_COUNT_ALT2:-0}
              
              # Use the best available counts (prefer non-zero results)
              if [[ "\$CREATE_COUNT" == "0" && "\$CREATE_COUNT_ALT1" != "0" ]]; then CREATE_COUNT=\$CREATE_COUNT_ALT1; fi
              if [[ "\$UPDATE_COUNT" == "0" && "\$UPDATE_COUNT_ALT1" != "0" ]]; then UPDATE_COUNT=\$UPDATE_COUNT_ALT1; fi
              if [[ "\$DELETE_COUNT" == "0" && "\$DELETE_COUNT_ALT1" != "0" ]]; then DELETE_COUNT=\$DELETE_COUNT_ALT1; fi
              
              if [[ "\$CREATE_COUNT" == "0" && "\$CREATE_COUNT_ALT2" != "0" ]]; then CREATE_COUNT=\$CREATE_COUNT_ALT2; fi
              if [[ "\$UPDATE_COUNT" == "0" && "\$UPDATE_COUNT_ALT2" != "0" ]]; then UPDATE_COUNT=\$UPDATE_COUNT_ALT2; fi
              if [[ "\$DELETE_COUNT" == "0" && "\$DELETE_COUNT_ALT2" != "0" ]]; then DELETE_COUNT=\$DELETE_COUNT_ALT2; fi
              
              # Final safety check - ensure all values are numeric
              CREATE_COUNT=\${CREATE_COUNT:-0}
              UPDATE_COUNT=\${UPDATE_COUNT:-0}
              DELETE_COUNT=\${DELETE_COUNT:-0}
              
              echo "  최종 선택된 결과: CREATE=\$CREATE_COUNT, UPDATE=\$UPDATE_COUNT, DELETE=\$DELETE_COUNT"
              
              RESOURCE_COUNTS="create:\$CREATE_COUNT|update:\$UPDATE_COUNT|delete:\$DELETE_COUNT"
              
              # Extract top resource types being changed
              TOP_RESOURCES=\$(jq -r '[.resource_changes[]?.type] | group_by(.) | map({type: .[0], count: length}) | sort_by(.count) | reverse | .[0:3] | map(.type + ":" + (.count | tostring)) | join(",")' plan_analysis.json 2>/dev/null || echo "")
              
              if [[ -n "\$TOP_RESOURCES" ]]; then
                CHANGE_SUMMARY="resources:\$TOP_RESOURCES"
                echo "  리소스 유형 통계: \$TOP_RESOURCES"
              fi
              
              # Keep JSON file for debugging if needed
              echo "  plan_analysis.json 파일 보존 (디버깅용)"
            else
              echo "  JSON 변환: 실패"
              echo "  대체 방법으로 plan 텍스트 분석 시도..."
              
              # Fallback: parse plan text output directly
              echo "  Terraform 바이너리 위치: \$(which terraform)"
              echo "  Terraform 버전: \$(terraform version | head -n1)"
              
              PLAN_TEXT=\$(terraform show "\$PLANFILE" 2>&1)
              SHOW_EXIT_CODE=\$?
              
              echo "  terraform show 명령 종료 코드: \$SHOW_EXIT_CODE"
              
              if [[ \$SHOW_EXIT_CODE -eq 0 && -n "\$PLAN_TEXT" ]]; then
                # 더 정확한 패턴 매칭 사용
                CREATE_COUNT=\$(echo "\$PLAN_TEXT" | grep -E "will be created|Plan: .* to add" | grep -oE '[0-9]+' | head -n1 || echo "0")
                UPDATE_COUNT=\$(echo "\$PLAN_TEXT" | grep -E "will be updated|will be modified|Plan: .* to change" | grep -oE '[0-9]+' | head -n1 || echo "0") 
                DELETE_COUNT=\$(echo "\$PLAN_TEXT" | grep -E "will be destroyed|Plan: .* to destroy" | grep -oE '[0-9]+' | head -n1 || echo "0")
                
                # Plan summary에서 직접 추출 시도
                PLAN_SUMMARY_LINE=\$(echo "\$PLAN_TEXT" | grep "Plan:" | tail -n1)
                
                if [[ -n "\$PLAN_SUMMARY_LINE" ]]; then
                  echo "  Plan summary 발견: \$PLAN_SUMMARY_LINE"
                  CREATE_COUNT=\$(echo "\$PLAN_SUMMARY_LINE" | grep -oE '[0-9]+ to add' | grep -oE '[0-9]+' || echo "0")
                  UPDATE_COUNT=\$(echo "\$PLAN_SUMMARY_LINE" | grep -oE '[0-9]+ to change' | grep -oE '[0-9]+' || echo "0")
                  DELETE_COUNT=\$(echo "\$PLAN_SUMMARY_LINE" | grep -oE '[0-9]+ to destroy' | grep -oE '[0-9]+' || echo "0")
                fi
                
                echo "  텍스트 분석 결과: CREATE=\$CREATE_COUNT, UPDATE=\$UPDATE_COUNT, DELETE=\$DELETE_COUNT"
              else
                echo "  Plan 파일 읽기 실패 - terraform show 오류:"
                echo "  오류 메시지: \$PLAN_TEXT"
                CREATE_COUNT=0
                UPDATE_COUNT=0
                DELETE_COUNT=0
              fi
            fi
          else
            echo "⚠️ PLANFILE 변수가 설정되지 않음"
            CREATE_COUNT=0
            UPDATE_COUNT=0
            DELETE_COUNT=0
          fi

          # Infracost analysis for cost impact
          COST_INFO=""
          echo "🔍 DEBUG - Infracost 환경 확인:"
          echo "  INFRACOST_API_KEY 존재: \$([ -n "\$INFRACOST_API_KEY" ] && echo "Yes (\${#INFRACOST_API_KEY} chars)" || echo "No")"
          echo "  infracost 바이너리: \$(command -v infracost >/dev/null 2>&1 && echo "Found at \$(command -v infracost)" || echo "Not found")"
          echo "  PLANFILE 존재: \$([ -n "\$PLANFILE" ] && [ -f "\$PLANFILE" ] && echo "Yes" || echo "No")"
          echo "  PLANFILE 경로: \$PLANFILE"
          echo "  PLANFILE 크기: \$([ -f "\$PLANFILE" ] && stat -c%s "\$PLANFILE" 2>/dev/null || echo "N/A")"
          
          if [ -n "\$INFRACOST_API_KEY" ] && [ -n "\$PLANFILE" ] && [ -f "\$PLANFILE" ] && command -v infracost >/dev/null 2>&1; then
            echo "💰 Infracost 비용 분석 시작..."
            
            # Infracost는 디렉토리를 스캔하거나 terraform show -json 출력을 사용
            echo "📂 Infracost를 위한 plan 준비 중..."
            
            # Plan 파일 직접 사용 (Infracost가 이제 지원함)
            INFRACOST_INPUT="\$PLANFILE"
            echo "  📋 Plan 파일 직접 사용: \$INFRACOST_INPUT"
            
            # Configure Infracost (안전장치 추가)
            echo "🔧 Infracost 설정 중..."
            # 컨테이너 환경에서는 configure가 실패할 수 있지만 환경변수로 작동함
            # set -e 때문에 실패하면 스크립트 종료되므로 || true 추가
            if CONFIGURE_OUTPUT=\$(infracost configure set api_key "\$INFRACOST_API_KEY" 2>&1); then
              echo "  ✅ API 키 설정 성공 (파일에 저장됨)"
            else
              echo "  ⚠️ API 키 파일 설정 실패 (환경변수로 대체)"
              echo "  이유: \${CONFIGURE_OUTPUT:-Unknown error}"
              echo "  환경변수 INFRACOST_API_KEY는 설정되어 있으므로 계속 진행"
            fi || true
            
            # Get cost breakdown in JSON format for parsing
            echo "📊 비용 분석 실행 중..."
            echo "  사용 중인 API 키: \${INFRACOST_API_KEY:0:10}..."
            
            # infracost breakdown 실행 (안전하게 처리)
            # 디렉토리 스캔 모드 사용 (가장 안전)
            set +e
            echo "  🔍 디렉토리에서 Terraform 파일 분석 중..."
            COST_JSON=\$(infracost breakdown --path "\$INFRACOST_INPUT" --format json 2>&1)
            INFRACOST_EXIT_CODE=\$?
            set -e
            
            if [ \$INFRACOST_EXIT_CODE -eq 0 ]; then
              echo "  ✅ 비용 분석 성공"
              # JSON이 실제로 비용 정보를 포함하는지 확인
              if echo "\$COST_JSON" | jq -e '.totalMonthlyCost' >/dev/null 2>&1; then
                echo "  💰 실제 비용 데이터 포함"
              else
                echo "  ⚠️ JSON은 성공했지만 비용 데이터 없음"
              fi
            else
              echo "  ⚠️ 비용 분석 실패 (exit code: \$INFRACOST_EXIT_CODE)"
              echo "  오류 메시지: \$(echo "\$COST_JSON" | head -n 3)"
              COST_JSON='{}'
            fi
            
            # Extract monthly cost for Slack metadata (안전장치)
            set +e
            MONTHLY_COST=\$(echo "\$COST_JSON" | jq -r '.totalMonthlyCost // "0"' 2>/dev/null)
            set -e
            MONTHLY_COST=\${MONTHLY_COST:-0}
            
            # Check for cost difference if baseline exists
            if [ -f "infracost-base.json" ]; then
              COST_DIFF_JSON=\$(infracost diff --path "\$INFRACOST_INPUT" --compare-to infracost-base.json --format json 2>/dev/null || echo '{}')
              set +e
              COST_DIFF=\$(echo "\$COST_DIFF_JSON" | jq -r '.diffTotalMonthlyCost // "0"' 2>/dev/null)
              set -e
              COST_DIFF=\${COST_DIFF:-0}
              
              if [[ "\$COST_DIFF" != "0" ]]; then
                COST_INFO="💰 월간 비용: \$MONTHLY_COST USD (변화: \$COST_DIFF USD)"
              else
                COST_INFO="💰 월간 비용: \$MONTHLY_COST USD"
              fi
            else
              COST_INFO="💰 월간 비용: \$MONTHLY_COST USD"
            fi
            
            # Generate GitHub comment
            echo "💬 GitHub 댓글 생성 중..."
            # set -e 로 인한 스크립트 종료 방지
            set +e
            # 디렉토리 스캔 모드 사용
            COMMENT_OUTPUT=\$(infracost comment github \\
              --path "\$INFRACOST_INPUT" \\
              --repo "\$BASE_REPO_OWNER/\$BASE_REPO_NAME" \\
              --pull-request \$PULL_NUM \\
              --github-token "\$ATLANTIS_GH_TOKEN" \\
              --behavior update 2>&1)
            COMMENT_EXIT=\$?
            set -e
            
            if [ \$COMMENT_EXIT -eq 0 ]; then
              echo "  ✅ GitHub 댓글 생성 성공"
            else
              echo "  ⚠️ Infracost GitHub 댓글 건너뛰기"
              echo "  이유: \$(echo "\$COMMENT_OUTPUT" | head -n 1)"
            fi
            
            echo "✅ 비용 분석 완료: \$COST_INFO"
          else
            echo "⚠️ Infracost API 키 없음 또는 바이너리 없음 - 비용 분석 건너뛰기"
            if [ -z "\$INFRACOST_API_KEY" ]; then
              echo "  -> INFRACOST_API_KEY 환경변수가 설정되지 않음"
            fi
            if ! command -v infracost >/dev/null 2>&1; then
              echo "  -> infracost 바이너리를 찾을 수 없음"
            fi
          fi

          # Generate enhanced Slack message with plan summary and PR link
          # Debug: 변수 값들 확인
          echo "🔍 DEBUG - Plan 분석 변수들:"
          echo "  CREATE_COUNT=['\$CREATE_COUNT']"
          echo "  UPDATE_COUNT=['\$UPDATE_COUNT']"
          echo "  DELETE_COUNT=['\$DELETE_COUNT']"
          echo "  PLANFILE=['\$PLANFILE']"
          
          # Ensure variables are numeric (default to 0 if empty)
          CREATE_COUNT=\${CREATE_COUNT:-0}
          UPDATE_COUNT=\${UPDATE_COUNT:-0}
          DELETE_COUNT=\${DELETE_COUNT:-0}
          
          # Calculate total changes
          TOTAL_CHANGES=\$((CREATE_COUNT + UPDATE_COUNT + DELETE_COUNT))
          
          echo "  정리된 값들 - CREATE:\$CREATE_COUNT, UPDATE:\$UPDATE_COUNT, DELETE:\$DELETE_COUNT"
          echo "  TOTAL_CHANGES=\$TOTAL_CHANGES"
          
          if [ \$TOTAL_CHANGES -gt 0 ]; then
            PLAN_SUMMARY="Plan: \$CREATE_COUNT to add, \$UPDATE_COUNT to change, \$DELETE_COUNT to destroy"
          else
            PLAN_SUMMARY="No changes"
          fi
          
          # Create enhanced message with PR link and cost info (JSON-safe)
          SAFE_REPO_NAME=\$(echo "\$REPO_ORG-\$REPO_NAME" | sed 's/[\"\\\\]/\\\\&/g')
          SAFE_PLAN_SUMMARY=\$(echo "\$PLAN_SUMMARY" | sed 's/[\"\\\\]/\\\\&/g')
          SAFE_COST_INFO=\$(echo "\$COST_INFO" | sed 's/[\"\\\\]/\\\\&/g')
          
          # Build PR link safely
          if [ -n "\$PR_URL" ] && [ -n "\$PR_NUM" ]; then
            PR_LINK="<\$PR_URL|PR #\$PR_NUM>"
          else
            PR_LINK="PR info unavailable"
          fi
          
          if [ -n "\$COST_INFO" ]; then
            ENHANCED_MESSAGE="🏗️ Terraform Plan \$PLAN_STATUS for \$SAFE_REPO_NAME \$PR_LINK\\n\$SAFE_PLAN_SUMMARY\\n\$SAFE_COST_INFO"
          else
            ENHANCED_MESSAGE="🏗️ Terraform Plan \$PLAN_STATUS for \$SAFE_REPO_NAME \$PR_LINK\\n\$SAFE_PLAN_SUMMARY"
          fi
          
          # Create JSON payload with proper escaping
          JSON_PAYLOAD="{\"text\": \"\$ENHANCED_MESSAGE\"}"
          
          # Send to Slack with performance timing
          echo "📤 Slack 알림 전송 중..."
          START_TIME=\$(date +%s.%N)
          
          CURL_RESPONSE=\$(curl -s -w "\\nHTTP_CODE:%{http_code}\\nTOTAL_TIME:%{time_total}\\nSIZE:%{size_download}" \
            -X POST \
            -H 'Content-type: application/json' \
            -d "\$JSON_PAYLOAD" \
            "\$SLACK_WEBHOOK_URL" 2>/dev/null)
          
          END_TIME=\$(date +%s.%N)
          DURATION=\$(echo "\$END_TIME - \$START_TIME" | bc -l 2>/dev/null || echo "0")
          
          HTTP_CODE=\$(echo "\$CURL_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
          TOTAL_TIME=\$(echo "\$CURL_RESPONSE" | grep "TOTAL_TIME:" | cut -d: -f2)
          SIZE=\$(echo "\$CURL_RESPONSE" | grep "SIZE:" | cut -d: -f2)
          
          if [ "\$HTTP_CODE" = "200" ]; then
            echo "✅ Plan result sent to Slack (성능: \${TOTAL_TIME}s, \${SIZE}bytes)"
          else
            echo "⚠️ Slack 전송 응답 코드: \$HTTP_CODE"
          fi
          echo "🤖 AI will analyze Atlantis logs and comment on PR shortly..."
    apply:
      steps:
      - apply:
          extra_args: ["-lock-timeout=10m", "-input=false", "\$PLANFILE"]
      - run: |
          set -e

          # Extract repo and PR info from environment
          REPO_ORG=\$(echo "\$BASE_REPO_OWNER" | tr '[:upper:]' '[:lower:]')
          REPO_NAME=\$(echo "\$BASE_REPO_NAME" | tr '[:upper:]' '[:lower:]')
          PR_NUM=\$PULL_NUM
          COMMIT_SHA=\$(echo "\$HEAD_COMMIT" | cut -c1-8)
          TIMESTAMP=\$(date -u +%Y%m%d%H%M%S)
          PR_URL="https://github.com/\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/pull/\${PR_NUM}"

          # Check apply result by looking at exit code of previous step
          APPLY_EXIT_CODE=\${PIPESTATUS[0]:-0}

          if [ \$APPLY_EXIT_CODE -eq 0 ]; then
            APPLY_STATUS="succeeded"
            APPLY_COLOR="good"
            echo "✅ Apply succeeded - sending Slack notification"
          else
            APPLY_STATUS="failed"
            APPLY_COLOR="danger"
            echo "❌ Apply failed - sending Slack notification"
          fi

          # Generate enhanced Slack message with apply result and PR link (JSON-safe)
          if [ \$APPLY_EXIT_CODE -eq 0 ]; then
            APPLY_SUMMARY="Infrastructure deployed successfully"
          else
            APPLY_SUMMARY="Apply failed - check logs for details"
          fi
          
          # JSON-safe variables
          SAFE_REPO_NAME=\$(echo "\$REPO_ORG-\$REPO_NAME" | sed 's/[\"\\\\]/\\\\&/g')
          SAFE_APPLY_SUMMARY=\$(echo "\$APPLY_SUMMARY" | sed 's/[\"\\\\]/\\\\&/g')
          
          # Build PR link safely
          if [ -n "\$PR_URL" ] && [ -n "\$PR_NUM" ]; then
            PR_LINK="<\$PR_URL|PR #\$PR_NUM>"
          else
            PR_LINK="PR info unavailable"
          fi
          
          # Create enhanced message with PR link
          ENHANCED_MESSAGE="🚀 Terraform Apply \$APPLY_STATUS for \$SAFE_REPO_NAME \$PR_LINK\\n\$SAFE_APPLY_SUMMARY"
          
          # Create JSON payload with proper escaping
          JSON_PAYLOAD="{\"text\": \"\$ENHANCED_MESSAGE\"}"
          
          # Send to Slack with performance timing
          echo "📤 Slack 알림 전송 중..."
          START_TIME=\$(date +%s.%N)
          
          CURL_RESPONSE=\$(curl -s -w "\\nHTTP_CODE:%{http_code}\\nTOTAL_TIME:%{time_total}\\nSIZE:%{size_download}" \
            -X POST \
            -H 'Content-type: application/json' \
            -d "\$JSON_PAYLOAD" \
            "\$SLACK_WEBHOOK_URL" 2>/dev/null)
          
          END_TIME=\$(date +%s.%N)
          DURATION=\$(echo "\$END_TIME - \$START_TIME" | bc -l 2>/dev/null || echo "0")
          
          HTTP_CODE=\$(echo "\$CURL_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
          TOTAL_TIME=\$(echo "\$CURL_RESPONSE" | grep "TOTAL_TIME:" | cut -d: -f2)
          SIZE=\$(echo "\$CURL_RESPONSE" | grep "SIZE:" | cut -d: -f2)
          
          if [ "\$HTTP_CODE" = "200" ]; then
            echo "✅ Apply result sent to Slack (성능: \${TOTAL_TIME}s, \${SIZE}bytes)"
          else
            echo "⚠️ Slack 전송 응답 코드: \$HTTP_CODE"
          fi
          echo "🤖 AI will analyze Atlantis logs and comment on PR shortly..."
YAML
else
    cat > atlantis.yaml << YAML
version: 3
projects:
- name: $(basename "$PROJECT_DIR" | sed 's/.*-//')
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

# Update .gitignore
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
.vscode//
.idea/
*.swp
*.swo
*~
"

# Safely handle .gitignore updates
set +e
gitignore_exists=false
if [[ -f ".gitignore" ]]; then
    gitignore_exists=true
fi
set -e

if [[ "$gitignore_exists" == true ]]; then
    # Check if Terraform entries already exist
    set +e
    terraform_exists=$(grep -q "# Terraform" .gitignore && echo "true" || echo "false")
    set -e
    
    if [[ "$terraform_exists" != "true" ]]; then
        set +e
        echo "$GITIGNORE_CONTENT" >> .gitignore 2>/dev/null
        gitignore_append_result=$?
        set -e
        
        if [[ $gitignore_append_result -eq 0 ]]; then
            log_success ".gitignore에 Terraform 관련 항목 추가"
        else
            log_warning ".gitignore 업데이트 실패 - 권한 확인 필요"
        fi
    else
        log_info ".gitignore에 이미 Terraform 관련 항목 존재"
    fi
else
    set +e
    echo "$GITIGNORE_CONTENT" > .gitignore 2>/dev/null
    gitignore_create_result=$?
    set -e
    
    if [[ $gitignore_create_result -eq 0 ]]; then
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

# Safely handle README.md updates
set +e
readme_exists=false
if [[ -f "README.md" ]]; then
    readme_exists=true
fi
set -e

if [[ "$readme_exists" == true ]]; then
    # Check if Atlantis section already exists
    set +e
    atlantis_exists=$(grep -q "Atlantis를 통한 Terraform 자동화" README.md && echo "true" || echo "false")
    set -e
    
    if [[ "$atlantis_exists" != "true" ]]; then
        set +e
        echo "$ATLANTIS_SECTION" >> README.md 2>/dev/null
        append_result=$?
        set -e
        
        if [[ $append_result -eq 0 ]]; then
            log_success "README.md에 Atlantis 사용법 추가"
        else
            log_warning "README.md 업데이트 실패 - 권한 확인 필요"
        fi
    else
        log_info "README.md에 이미 Atlantis 관련 내용 존재"
    fi
else
    set +e
    echo "# $(basename "$PWD")" > README.md 2>/dev/null
    readme_create_result=$?
    append_result=1
    if [[ $readme_create_result -eq 0 ]]; then
        echo "$ATLANTIS_SECTION" >> README.md 2>/dev/null
        append_result=$?
    fi
    set -e
    
    if [[ $readme_create_result -eq 0 && $append_result -eq 0 ]]; then
        log_success "README.md 파일 생성 완료"
    else
        log_warning "README.md 생성 실패 - 권한 확인 필요"
    fi
fi

# GitHub webhook auto-setup function
setup_github_webhook() {
    if [[ "$SKIP_WEBHOOK" == true ]]; then
        return 0
    fi

    log_info "GitHub 웹훅 자동 설정 시작..."

    local webhook_url="$ATLANTIS_URL/events"
    local webhook_config
    webhook_config=$(cat << 'EOF'
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
    "url": "WEBHOOK_URL_PLACEHOLDER",
    "content_type": "json",
    "secret": "WEBHOOK_SECRET_PLACEHOLDER",
    "insecure_ssl": "0"
  }
}
EOF
)
    webhook_config=$(echo "$webhook_config" | sed "s|WEBHOOK_URL_PLACEHOLDER|$webhook_url|g" | sed "s|WEBHOOK_SECRET_PLACEHOLDER|$WEBHOOK_SECRET|g")

    # Check if webhook already exists
    log_info "기존 웹훅 존재 여부 확인 중..."
    local existing_webhook=""
    set +e
    local webhook_response
    webhook_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null)
    if [[ -n "$webhook_response" && "$webhook_response" != "null" ]]; then
        existing_webhook=$(echo "$webhook_response" | jq -r ".[] | select(.config.url == \"$webhook_url\") | .id" 2>/dev/null || echo "")
    fi
    set -e
    existing_webhook=${existing_webhook:-""}

    if [[ -n "$existing_webhook" ]]; then
        log_success "기존 웹훅 발견 (ID: $existing_webhook). 설정을 업데이트합니다."

        # Get current webhook details for comparison
        local current_webhook=""
        local current_active="false"
        local current_events=""
        local new_events=""
        
        set +e
        current_webhook=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_NAME/hooks/$existing_webhook" 2>/dev/null)
        
        if [[ -n "$current_webhook" && "$current_webhook" != "null" ]]; then
            current_active=$(echo "$current_webhook" | jq -r '.active // false' 2>/dev/null || echo "false")
            current_events=$(echo "$current_webhook" | jq -r '.events | sort | join(",")' 2>/dev/null || echo "")
            new_events=$(echo '["issue_comment","pull_request","pull_request_review","pull_request_review_comment","push"]' | jq -r 'sort | join(",")' 2>/dev/null || echo "")
        fi
        set -e
        
        current_active=${current_active:-"false"}
        current_events=${current_events:-""}
        new_events=${new_events:-""}

        log_info "웹훅 설정 비교:"
        echo "  - 활성화 상태: $current_active → true"
        echo "  - 이벤트: $(echo "$current_events" | cut -c1-50)..."
        echo "  - URL: $webhook_url"
        echo "  - 시크릿: 업데이트됨"

        # Update existing webhook with complete configuration
        local response=""
        set +e
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -X PATCH \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks/$existing_webhook" 2>/dev/null)
        set -e
    else
        log_info "새 웹훅을 생성합니다."

        # Create new webhook
        local response=""
        set +e
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$webhook_config" \
            "https://api.github.com/repos/$REPO_NAME/hooks" 2>/dev/null)
        set -e
    fi

    local http_status=""
    local response_body=""
    if [[ -n "$response" ]]; then
        http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null || echo "")
        response_body=$(echo "$response" | sed '/HTTP_STATUS:/d' 2>/dev/null || echo "")
    fi
    http_status=${http_status:-"000"}
    response_body=${response_body:-"{}"}

    case $http_status in
        200)
            log_success "기존 GitHub 웹훅이 성공적으로 업데이트되었습니다!"
            local webhook_id=""
            set +e
            if [[ -n "$response_body" && "$response_body" != "null" ]]; then
                webhook_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null || echo "")
            fi
            set -e
            webhook_id=${webhook_id:-"unknown"}
            echo "   - 웹훅 ID: $webhook_id"
            echo "   - URL: $webhook_url"
            echo "   - 상태: 활성화됨"
            ;;
        201)
            log_success "GitHub 웹훅이 성공적으로 생성되었습니다!"
            local webhook_id=""
            set +e
            if [[ -n "$response_body" && "$response_body" != "null" ]]; then
                webhook_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null || echo "")
            fi
            set -e
            webhook_id=${webhook_id:-"unknown"}
            echo "   - 웹훅 ID: $webhook_id"
            echo "   - URL: $webhook_url"
            ;;
        422)
            local error_message=""
            set +e
            if [[ -n "$response_body" && "$response_body" != "null" ]]; then
                error_message=$(echo "$response_body" | jq -r '.errors[0].message // .message' 2>/dev/null || echo "Unknown error")
            fi
            set -e
            error_message=${error_message:-"Unknown error"}
            
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
            log_error "웹훅 생성 실패 (HTTP $http_status): $response_body"
            return 1
            ;;
    esac

    return 0
}

# GitHub repository variables setup function
setup_github_variables() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_warning "GitHub 토큰이 없어서 레포 변수 설정을 건너뜁니다."
        return 0
    fi

    log_info "GitHub 레포 변수 자동 설정 시작..."

    # Set repository variables for Atlantis deployment
    local variables_config='[
        {"name": "ATLANTIS_REGION", "value": "'${AWS_REGION}'"},
        {"name": "ATLANTIS_ORG_NAME", "value": "'${REPO_NAME%/*}'"},
        {"name": "ATLANTIS_ENVIRONMENT", "value": "prod"}
    ]'

    log_info "필수 GitHub Variables 설정 중..."
    
    # Parse variables safely
    set +e
    local var_list=""
    if [[ -n "$variables_config" ]]; then
        var_list=$(echo "$variables_config" | jq -c '.[]' 2>/dev/null || echo "")
    fi
    set -e
    
    if [[ -z "$var_list" ]]; then
        log_warning "변수 설정 파싱 실패, 기본값 사용"
        var_list='[{"name":"ATLANTIS_REGION","value":"'${AWS_REGION}'"},{"name":"ATLANTIS_ORG_NAME","value":"'${REPO_NAME%/*}'"},{"name":"ATLANTIS_ENVIRONMENT","value":"prod"}]'
        var_list=$(echo "$var_list" | jq -c '.[]' 2>/dev/null || echo "")
    fi
    
    echo "$var_list" | while IFS= read -r var; do
        if [[ -z "$var" ]]; then
            continue
        fi
        
        local name=""
        local value=""
        set +e
        name=$(echo "$var" | jq -r '.name' 2>/dev/null || echo "")
        value=$(echo "$var" | jq -r '.value' 2>/dev/null || echo "")
        set -e
        
        name=${name:-"unknown"}
        value=${value:-""}

        log_info "변수 설정 중: $name = $value"

        # Set repository variable
        local response=""
        set +e
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "{\"name\":\"$name\",\"value\":\"$value\"}" \
            "https://api.github.com/repos/$REPO_NAME/actions/variables" 2>/dev/null)
        set -e

        local http_status=""
        if [[ -n "$response" ]]; then
            http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null || echo "")
        fi
        http_status=${http_status:-"000"}
        case $http_status in
            201)
                log_success "GitHub Variable '$name' 설정 완료"
                ;;
            409)
                # Variable already exists, try to update
                local update_response=""
                set +e
                update_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    -H "Content-Type: application/json" \
                    -X PATCH \
                    -d "{\"name\":\"$name\",\"value\":\"$value\"}" \
                    "https://api.github.com/repos/$REPO_NAME/actions/variables/$name" 2>/dev/null)
                set -e

                local update_status=""
                if [[ -n "$update_response" ]]; then
                    update_status=$(echo "$update_response" | grep "HTTP_STATUS:" | cut -d: -f2 2>/dev/null || echo "")
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
echo "1. Atlantis 서버에 이 저장소 추가:"
echo "   - repo_allowlist에 'github.com/$REPO_NAME' 추가"
echo ""

if [[ "$SKIP_WEBHOOK" == true ]]; then
echo "2. GitHub 웹훅 수동 설정:"
echo "   - URL: $ATLANTIS_URL/events"
echo "   - Events: Pull requests, Issue comments, Push"
echo "   - Content type: application/json"
echo "   - Secret: $WEBHOOK_SECRET"
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
echo "   - 📤 Plan/Apply 결과가 Slack으로 자동 전송 (AI 리뷰 트리거 포함)"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$SKIP_WEBHOOK" == false ]]; then
echo "🔐 보안 정보:"
echo "   - 웹훅 시크릿: $WEBHOOK_SECRET"
echo "   - 이 시크릿을 안전한 곳에 보관하세요"
echo ""
fi

log_success "Happy Infrastructure as Code! 🚀"