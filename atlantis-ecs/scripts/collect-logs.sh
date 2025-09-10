#!/bin/bash
set -euo pipefail

# 🔍 StackKit 로그 수집 스크립트
# 문제 해결을 위한 종합 진단 정보 수집

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

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               🔍 StackKit 진단 로그 수집기                     ║"
echo "║              문제 해결을 위한 시스템 정보 수집                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Basic system information
echo "📋 시스템 정보"
echo "=============================================================================="
echo "수집 시간: $(date)"
echo "운영체제: $(uname -a)"
echo "작업 디렉토리: $(pwd)"
echo "사용자: $(whoami)"
echo ""

# Environment variables
echo "🌍 환경 변수"
echo "=============================================================================="
echo "StackKit 관련 환경 변수:"
env | grep -E '^(TF_|ATLANTIS_|INFRACOST_|SLACK_|AWS_)' | while read -r var; do
    key=$(echo "$var" | cut -d'=' -f1)
    value=$(echo "$var" | cut -d'=' -f2-)
    
    # Mask sensitive values
    case $key in
        *TOKEN|*KEY|*SECRET|*WEBHOOK*)
            masked_value="${value:0:8}..."
            ;;
        *)
            masked_value="$value"
            ;;
    esac
    echo "  $key=$masked_value"
done
echo ""

# Tool versions
echo "🔧 도구 버전 정보"
echo "=============================================================================="
tools=(aws terraform jq curl git)
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -n "✅ $tool: "
        case $tool in
            aws) aws --version 2>&1 | head -1 ;;
            terraform) terraform version | head -1 ;;
            jq) jq --version ;;
            curl) curl --version | head -1 ;;
            git) git --version ;;
        esac
    else
        echo "❌ $tool: 설치되지 않음"
    fi
done
echo ""

# AWS information
echo "☁️  AWS 정보"
echo "=============================================================================="
if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo "✅ AWS 인증 상태: 정상"
        echo "계정 ID: $(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo '조회 실패')"
        echo "사용자/역할: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo '조회 실패')"
        echo "기본 리전: $(aws configure get region 2>/dev/null || echo '설정되지 않음')"
        
        # Current region from various sources
        if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
            echo "환경변수 리전: $AWS_DEFAULT_REGION"
        fi
        if [[ -n "${TF_STACK_REGION:-}" ]]; then
            echo "StackKit 리전: $TF_STACK_REGION"
        fi
    else
        echo "❌ AWS 인증 실패"
        echo "AWS CLI 설정을 확인하세요: aws configure"
    fi
else
    echo "❌ AWS CLI 설치되지 않음"
fi
echo ""

# Git information
echo "📚 Git 정보"
echo "=============================================================================="
if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "✅ Git 저장소: $(git rev-parse --show-toplevel)"
    echo "현재 브랜치: $(git branch --show-current 2>/dev/null || echo '확인 불가')"
    echo "최근 커밋: $(git log -1 --oneline 2>/dev/null || echo '확인 불가')"
    echo "리모트 URL: $(git remote get-url origin 2>/dev/null || echo '리모트 없음')"
    echo "Git 상태:"
    git status --porcelain 2>/dev/null | head -10 || echo "상태 확인 불가"
else
    echo "❌ Git 저장소가 아닙니다"
fi
echo ""

# Terraform information
echo "🏗️ Terraform 정보"
echo "=============================================================================="
if [[ -f "terraform.tfvars" ]]; then
    echo "✅ terraform.tfvars 존재"
    echo "설정 내용 (민감 정보 제외):"
    grep -E '^[^#]*=' terraform.tfvars | grep -v -E '(token|key|secret)' | head -10 || echo "내용 없음"
else
    echo "❌ terraform.tfvars 없음"
fi

if [[ -f "backend.hcl" ]]; then
    echo "✅ backend.hcl 존재"
    echo "백엔드 설정:"
    cat backend.hcl 2>/dev/null || echo "읽기 실패"
else
    echo "❌ backend.hcl 없음"
fi

if [[ -d ".terraform" ]]; then
    echo "✅ .terraform 디렉토리 존재"
    if [[ -f ".terraform/terraform.tfstate" ]]; then
        echo "백엔드 초기화 완료"
    fi
else
    echo "❌ Terraform 초기화 필요"
fi

if command -v terraform >/dev/null 2>&1; then
    echo ""
    echo "Terraform 상태 확인:"
    if terraform show >/dev/null 2>&1; then
        echo "✅ Terraform 상태 정상"
        echo "리소스 개수: $(terraform state list 2>/dev/null | wc -l || echo '0')"
    else
        echo "❌ Terraform 상태 오류 또는 초기화 필요"
    fi
fi
echo ""

# AWS infrastructure status
echo "🏢 AWS 인프라 상태"
echo "=============================================================================="
if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    
    # ECS clusters
    echo "ECS 클러스터:"
    if clusters=$(aws ecs list-clusters --query 'clusterArns[?contains(@, `atlantis`)]' --output text 2>/dev/null); then
        if [[ -n "$clusters" ]]; then
            echo "$clusters" | while read -r cluster; do
                cluster_name=$(basename "$cluster")
                echo "  ✅ $cluster_name"
                
                # Services in cluster
                if services=$(aws ecs list-services --cluster "$cluster" --query 'serviceArns' --output text 2>/dev/null); then
                    if [[ -n "$services" ]]; then
                        echo "$services" | while read -r service; do
                            service_name=$(basename "$service")
                            echo "    - 서비스: $service_name"
                        done
                    fi
                fi
            done
        else
            echo "  ❌ Atlantis 클러스터 없음"
        fi
    else
        echo "  ❌ ECS 정보 조회 실패"
    fi
    
    # Load balancers
    echo ""
    echo "로드 밸런서:"
    if albs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `atlantis`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' --output table 2>/dev/null); then
        if [[ -n "$albs" && "$albs" != *"None"* ]]; then
            echo "$albs"
        else
            echo "  ❌ Atlantis ALB 없음"
        fi
    else
        echo "  ❌ ALB 정보 조회 실패"
    fi
    
    # S3 buckets
    echo ""
    echo "S3 버킷 (atlantis 관련):"
    if buckets=$(aws s3 ls | grep atlantis 2>/dev/null); then
        if [[ -n "$buckets" ]]; then
            echo "$buckets" | while read -r line; do
                bucket_name=$(echo "$line" | awk '{print $3}')
                echo "  ✅ $bucket_name"
            done
        else
            echo "  ❌ Atlantis S3 버킷 없음"
        fi
    else
        echo "  ❌ S3 정보 조회 실패"
    fi
    
    # DynamoDB tables
    echo ""
    echo "DynamoDB 테이블 (atlantis 관련):"
    if tables=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `atlantis`)]' --output text 2>/dev/null); then
        if [[ -n "$tables" ]]; then
            echo "$tables" | while read -r table; do
                echo "  ✅ $table"
            done
        else
            echo "  ❌ Atlantis DynamoDB 테이블 없음"
        fi
    else
        echo "  ❌ DynamoDB 정보 조회 실패"
    fi
    
    # Secrets Manager
    echo ""
    echo "Secrets Manager (atlantis 관련):"
    if secrets=$(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `atlantis`)].Name' --output text 2>/dev/null); then
        if [[ -n "$secrets" ]]; then
            echo "$secrets" | while read -r secret; do
                echo "  ✅ $secret"
            done
        else
            echo "  ❌ Atlantis 시크릿 없음"
        fi
    else
        echo "  ❌ Secrets Manager 정보 조회 실패"
    fi
else
    echo "❌ AWS 접근 불가 - 인증 확인 필요"
fi
echo ""

# Network connectivity
echo "🌐 네트워크 연결 상태"
echo "=============================================================================="
endpoints=(
    "aws:https://sts.amazonaws.com"
    "github:https://api.github.com"
    "terraform:https://registry.terraform.io"
    "infracost:https://pricing.api.infracost.io"
)

for endpoint in "${endpoints[@]}"; do
    name=$(echo "$endpoint" | cut -d':' -f1)
    url=$(echo "$endpoint" | cut -d':' -f2-)
    
    if curl -s --max-time 10 "$url" >/dev/null 2>&1; then
        echo "✅ $name: 연결 정상"
    else
        echo "❌ $name: 연결 실패"
    fi
done
echo ""

# Recent logs if available
echo "📝 최근 로그 (사용 가능한 경우)"
echo "=============================================================================="

# CloudWatch logs for Atlantis
if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    if log_groups=$(aws logs describe-log-groups --log-group-name-prefix "/ecs/atlantis" --query 'logGroups[].logGroupName' --output text 2>/dev/null); then
        if [[ -n "$log_groups" ]]; then
            echo "Atlantis CloudWatch 로그:"
            echo "$log_groups" | while read -r log_group; do
                echo "  로그 그룹: $log_group"
                # Get recent log events (last 10 entries)
                if recent_logs=$(aws logs filter-log-events --log-group-name "$log_group" --max-items 5 --query 'events[].message' --output text 2>/dev/null); then
                    if [[ -n "$recent_logs" ]]; then
                        echo "  최근 로그 (최대 5개):"
                        echo "$recent_logs" | while read -r log_line; do
                            echo "    $(echo "$log_line" | cut -c1-100)"
                        done
                    fi
                fi
            done
        else
            echo "❌ Atlantis CloudWatch 로그 없음"
        fi
    else
        echo "❌ CloudWatch 로그 조회 실패"
    fi
else
    echo "❌ CloudWatch 로그 접근 불가"
fi

# Local log files
if [[ -f "terraform.log" ]]; then
    echo ""
    echo "로컬 Terraform 로그 (마지막 10줄):"
    tail -10 terraform.log || echo "로그 읽기 실패"
fi

if [[ -f "atlantis.log" ]]; then
    echo ""
    echo "로컬 Atlantis 로그 (마지막 10줄):"
    tail -10 atlantis.log || echo "로그 읽기 실패"
fi

echo ""
echo "=============================================================================="
echo "🔍 로그 수집 완료"
echo ""
echo "💡 이 정보를 문제 해결에 사용하세요:"
echo "  1. GitHub Issues에 문제 보고 시 이 출력을 첨부"
echo "  2. AWS 콘솔에서 리소스 상태 확인"
echo "  3. Terraform 상태 및 로그 분석"
echo ""
echo "📚 추가 도움말:"
echo "  • docs/troubleshooting.md"
echo "  • https://github.com/ryu-qqq/stackkit/issues"
echo "=============================================================================="