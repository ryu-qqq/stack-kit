#!/bin/bash
set -euo pipefail

# 🧪 Local Infracost Testing Script
# 로컬에서 Infracost 동작을 테스트하는 스크립트

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

show_help() {
    cat << EOF
🧪 Infracost Local Testing Script

Usage: $0 [OPTIONS]

Options:
    --plan-file FILE        기존 plan 파일 사용 (기본: 새로 생성)
    --api-key KEY          Infracost API 키 (환경변수 우선)
    --test-dir DIR         테스트할 Terraform 디렉토리 (기본: .)
    --keep-files           임시 파일 삭제하지 않음 (디버깅용)
    --verbose              상세한 출력
    --help                 이 도움말 표시

Examples:
    # 현재 디렉토리에서 테스트
    $0
    
    # 특정 디렉토리 테스트
    $0 --test-dir ./terraform/stacks/my-stack
    
    # 기존 plan 파일로 테스트
    $0 --plan-file ./my.tfplan
    
    # 임시 파일 보존하여 디버깅
    $0 --keep-files --verbose

Environment Variables:
    INFRACOST_API_KEY      Infracost API 키
EOF
}

# Default values
PLAN_FILE=""
API_KEY="${INFRACOST_API_KEY:-}"
TEST_DIR="."
KEEP_FILES=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --plan-file)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--plan-file requires a value"
                exit 1
            fi
            PLAN_FILE="$2"
            shift 2
            ;;
        --api-key)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--api-key requires a value"
                exit 1
            fi
            API_KEY="$2"
            shift 2
            ;;
        --test-dir)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                log_error "--test-dir requires a value"
                exit 1
            fi
            TEST_DIR="$2"
            shift 2
            ;;
        --keep-files) KEEP_FILES=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --help) show_help; exit 0 ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "$API_KEY" ]]; then
    log_error "Infracost API 키가 필요합니다."
    echo "  환경변수 INFRACOST_API_KEY를 설정하거나 --api-key 옵션을 사용하세요."
    exit 1
fi

if [[ ! -d "$TEST_DIR" ]]; then
    log_error "테스트 디렉토리가 존재하지 않습니다: $TEST_DIR"
    exit 1
fi

# Change to test directory
cd "$TEST_DIR"
log_info "테스트 디렉토리: $(pwd)"

# Check prerequisites
log_info "🔧 환경 확인 중..."

if ! command -v terraform >/dev/null 2>&1; then
    log_error "terraform 명령어를 찾을 수 없습니다"
    exit 1
fi

if ! command -v infracost >/dev/null 2>&1; then
    log_error "infracost 명령어를 찾을 수 없습니다"
    echo "  설치: https://www.infracost.io/docs/#quick-start"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "jq 명령어를 찾을 수 없습니다"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
INFRACOST_VERSION=$(infracost --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

log_success "환경 확인 완료"
echo "  Terraform: $TERRAFORM_VERSION"
echo "  Infracost: $INFRACOST_VERSION"

# Configure Infracost
log_info "🔧 Infracost 설정 중..."
export INFRACOST_API_KEY="$API_KEY"

set +e
if infracost configure set api_key "$API_KEY" 2>/dev/null; then
    log_success "API 키 설정 완료"
else
    log_warning "API 키 파일 설정 실패 (환경변수로 대체)"
fi
set -e

# Initialize Terraform if needed
if [[ ! -d ".terraform" ]]; then
    log_info "🚀 Terraform 초기화 중..."
    terraform init
    log_success "Terraform 초기화 완료"
fi

# Create or use existing plan
TIMESTAMP=$(date +%s)
if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    log_info "📋 기존 plan 파일 사용: $PLAN_FILE"
    PLAN_PATH="$PLAN_FILE"
else
    log_info "📋 새로운 plan 생성 중..."
    PLAN_PATH="test-plan-${TIMESTAMP}.tfplan"
    
    if terraform plan -out="$PLAN_PATH" -input=false; then
        log_success "Plan 생성 완료: $PLAN_PATH"
    else
        log_error "Plan 생성 실패"
        exit 1
    fi
fi

# Analyze plan file
log_info "🔍 Plan 파일 분석..."
echo "  파일 경로: $PLAN_PATH"
echo "  파일 크기: $(du -h "$PLAN_PATH" | cut -f1)"
echo "  파일 타입: $(file "$PLAN_PATH" 2>/dev/null || echo "Unknown")"

# Test different Infracost approaches
log_info "🧪 Infracost 테스트 시작..."

# Approach 1: Directory scanning (most reliable)
echo ""
log_info "📁 방법 1: 디렉토리 스캔"
set +e
COST_JSON_DIR=$(infracost breakdown --path . --format json 2>&1)
DIR_EXIT_CODE=$?
set -e

if [[ $DIR_EXIT_CODE -eq 0 ]]; then
    log_success "디렉토리 스캔 성공"
    if [[ "$VERBOSE" == true ]]; then
        echo "  출력 샘플: $(echo "$COST_JSON_DIR" | head -c 200)..."
    fi
    
    # Extract cost
    MONTHLY_COST_DIR=$(echo "$COST_JSON_DIR" | jq -r '.totalMonthlyCost // "N/A"' 2>/dev/null || echo "N/A")
    echo "  월간 비용: $MONTHLY_COST_DIR USD"
else
    log_error "디렉토리 스캔 실패 (exit code: $DIR_EXIT_CODE)"
    echo "  오류: $(echo "$COST_JSON_DIR" | head -n 3)"
fi

# Approach 2: Plan file conversion to JSON
echo ""
log_info "📄 방법 2: Plan JSON 변환"
PLAN_JSON_FILE="test-plan-${TIMESTAMP}.json"

set +e
terraform show -json "$PLAN_PATH" > "$PLAN_JSON_FILE" 2>/dev/null
JSON_EXIT_CODE=$?
set -e

if [[ $JSON_EXIT_CODE -eq 0 && -s "$PLAN_JSON_FILE" ]]; then
    log_success "JSON 변환 성공"
    
    # Validate JSON
    set +e
    JSON_VALID=$(jq empty "$PLAN_JSON_FILE" 2>/dev/null && echo "true" || echo "false")
    set -e
    
    if [[ "$JSON_VALID" == "true" ]]; then
        log_success "JSON 유효성 검사 통과"
        
        JSON_SIZE=$(wc -c < "$PLAN_JSON_FILE" 2>/dev/null || echo "0")
        echo "  JSON 파일 크기: $JSON_SIZE bytes"
        
        # Check JSON structure
        if [[ "$VERBOSE" == true ]]; then
            echo "  JSON 최상위 키들:"
            jq -r 'keys[]' "$PLAN_JSON_FILE" 2>/dev/null | head -10 | while read key; do
                echo "    - $key"
            done
        fi
        
        # Test Infracost with JSON
        set +e
        COST_JSON_PLAN=$(infracost breakdown --path "$PLAN_JSON_FILE" --format json 2>&1)
        JSON_INFRACOST_EXIT=$?
        set -e
        
        if [[ $JSON_INFRACOST_EXIT -eq 0 ]]; then
            log_success "JSON 기반 Infracost 분석 성공"
            MONTHLY_COST_PLAN=$(echo "$COST_JSON_PLAN" | jq -r '.totalMonthlyCost // "N/A"' 2>/dev/null || echo "N/A")
            echo "  월간 비용: $MONTHLY_COST_PLAN USD"
        else
            log_error "JSON 기반 Infracost 분석 실패 (exit code: $JSON_INFRACOST_EXIT)"
            echo "  오류: $(echo "$COST_JSON_PLAN" | head -n 3)"
            
            # Check for version issue
            if echo "$COST_JSON_PLAN" | grep -q "invalid Infracost JSON file version"; then
                log_warning "JSON 버전 호환성 문제 감지"
                
                # Try to identify the format version
                FORMAT_VERSION=$(jq -r '.format_version // "unknown"' "$PLAN_JSON_FILE" 2>/dev/null || echo "unknown")
                TERRAFORM_VERSION_JSON=$(jq -r '.terraform_version // "unknown"' "$PLAN_JSON_FILE" 2>/dev/null || echo "unknown")
                
                echo "  감지된 format_version: $FORMAT_VERSION"
                echo "  감지된 terraform_version: $TERRAFORM_VERSION_JSON"
                echo "  Infracost 지원 버전: 0.2"
                
                if [[ "$FORMAT_VERSION" != "unknown" && "$FORMAT_VERSION" != "0.2" ]]; then
                    log_warning "JSON 형식 버전이 Infracost와 호환되지 않음"
                    echo "  현재: $FORMAT_VERSION, 지원: 0.2"
                fi
            fi
        fi
    else
        log_error "JSON 유효성 검사 실패"
        echo "  파일 내용 샘플: $(head -c 200 "$PLAN_JSON_FILE" 2>/dev/null || echo "읽기 실패")"
    fi
else
    log_error "JSON 변환 실패"
fi

# Approach 3: Direct plan file (should fail)
echo ""
log_info "📋 방법 3: Plan 파일 직접 사용 (예상 실패)"
set +e
COST_JSON_DIRECT=$(infracost breakdown --path "$PLAN_PATH" --format json 2>&1)
DIRECT_EXIT_CODE=$?
set -e

if [[ $DIRECT_EXIT_CODE -eq 0 ]]; then
    log_success "직접 plan 파일 사용 성공 (예상외)"
    MONTHLY_COST_DIRECT=$(echo "$COST_JSON_DIRECT" | jq -r '.totalMonthlyCost // "N/A"' 2>/dev/null || echo "N/A")
    echo "  월간 비용: $MONTHLY_COST_DIRECT USD"
else
    log_error "직접 plan 파일 사용 실패 (예상됨) (exit code: $DIRECT_EXIT_CODE)"
    echo "  오류: $(echo "$COST_JSON_DIRECT" | head -n 3)"
fi

# Summary
echo ""
log_info "📊 테스트 결과 요약"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "방법 1 (디렉토리): $([ $DIR_EXIT_CODE -eq 0 ] && echo "✅ 성공" || echo "❌ 실패") | 비용: ${MONTHLY_COST_DIR:-N/A} USD"
echo "방법 2 (JSON 변환): $([ $JSON_INFRACOST_EXIT -eq 0 ] 2>/dev/null && echo "✅ 성공" || echo "❌ 실패") | 비용: ${MONTHLY_COST_PLAN:-N/A} USD"
echo "방법 3 (직접 사용): $([ $DIRECT_EXIT_CODE -eq 0 ] && echo "✅ 성공" || echo "❌ 실패") | 비용: ${MONTHLY_COST_DIRECT:-N/A} USD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Recommendations
echo ""
log_info "💡 권장사항"

if [[ $DIR_EXIT_CODE -eq 0 ]]; then
    log_success "디렉토리 스캔 방법 사용을 권장합니다"
    echo "  connect.sh에서 INFRACOST_INPUT=\".\" 사용"
elif [[ $JSON_INFRACOST_EXIT -eq 0 ]] 2>/dev/null; then
    log_success "JSON 변환 방법 사용을 권장합니다"
    echo "  connect.sh에서 terraform show -json을 사용한 변환 방법 유지"
else
    log_warning "모든 방법이 실패했습니다"
    echo "  가능한 해결책:"
    echo "    1. Infracost API 키 확인"
    echo "    2. Terraform 파일에 cost 관련 리소스 추가"
    echo "    3. Infracost 버전 업데이트"
fi

# Cleanup
if [[ "$KEEP_FILES" == false ]]; then
    log_info "🧹 임시 파일 정리 중..."
    
    # Remove generated plan file (but not user-provided one)
    if [[ -z "$PLAN_FILE" && -f "test-plan-${TIMESTAMP}.tfplan" ]]; then
        rm -f "test-plan-${TIMESTAMP}.tfplan"
    fi
    
    # Remove JSON file
    if [[ -f "$PLAN_JSON_FILE" ]]; then
        rm -f "$PLAN_JSON_FILE"
    fi
    
    log_success "정리 완료"
else
    log_info "🔍 디버깅을 위해 임시 파일 보존됨"
    echo "  Plan 파일: $PLAN_PATH"
    if [[ -f "$PLAN_JSON_FILE" ]]; then
        echo "  JSON 파일: $PLAN_JSON_FILE"
    fi
fi

log_success "테스트 완료! 🚀"