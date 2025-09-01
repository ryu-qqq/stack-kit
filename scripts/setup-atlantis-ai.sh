#!/usr/bin/env bash
set -euo pipefail

# StackKit Atlantis AI Reviewer 원클릭 셋업 스크립트
# 사용법: ./setup-atlantis-ai.sh --github-token=ghp_xxx --slack-webhook=https://... --openai-key=sk-xxx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 기본값 설정
STACK_NAME="atlantis-ai-reviewer"
ENVIRONMENT="dev"
REGION="ap-northeast-2"
GITHUB_TOKEN=""
SLACK_WEBHOOK=""
OPENAI_API_KEY=""
INFRACOST_API_KEY=""
WEBHOOK_SECRET=""
REPO_ALLOWLIST=""
GIT_USERNAME=""
S3_BUCKET=""
DYNAMODB_TABLE=""
AUTO_DETECT=false
EXISTING_VPC_ID=""
EXISTING_ALB_NAME=""
SKIP_BUILD=false
SKIP_DEPLOY=false
DRY_RUN=false

show_usage() {
    cat << 'EOF'
🚀 StackKit Atlantis AI Reviewer 원클릭 셋업

사용법:
    ./setup-atlantis-ai.sh [OPTIONS]

필수 옵션:
    --github-token=TOKEN        GitHub Personal Access Token (repo, admin:repo_hook 권한 필요)
    --slack-webhook=URL         Slack Webhook URL
    --openai-key=KEY           OpenAI API Key
    --infracost-key=KEY        Infracost API Key (정확한 비용 추정용)

선택 옵션:
    --s3-bucket=BUCKET         Terraform 상태 저장용 S3 버킷 (기본: stackkit-tfstate)
    --dynamodb-table=TABLE     Terraform 잠금용 DynamoDB 테이블 (기본: 환경-stackkit-tf-lock)
    --stack-name=NAME          스택 이름 (기본: atlantis-ai-reviewer)
    --environment=ENV          환경 (기본: dev)
    --auto-detect              기존 AWS 리소스 자동 감지 및 재사용
    --vpc-id=VPC_ID           사용할 기존 VPC ID (자동 감지 무시)
    --alb-name=ALB_NAME       사용할 기존 ALB 이름 (자동 감지 무시)
    --region=REGION            AWS 리전 (기본: us-east-1)
    --webhook-secret=SECRET    GitHub Webhook Secret (자동 생성됨)
    --repo-allowlist=LIST      허용할 Repository 패턴 (예: github.com/myorg/*)
    --git-username=USER        Git 사용자명
    --skip-build              AI Reviewer 빌드 건너뛰기
    --skip-deploy             Terraform 배포 건너뛰기
    --dry-run                 실제 실행 없이 계획만 출력

예시:
    ./setup-atlantis-ai.sh \
        --github-token=ghp_xxxxxxxxxxxx \
        --slack-webhook=https://hooks.slack.com/services/T00/B00/xxx \
        --openai-key=sk-xxxxxxxxxxxxxxxx \
        --infracost-key=ico-xxxxxxxxxxxxxxxx \
        --s3-bucket=connectly-prod \
        --dynamodb-table=dev-connectly-tf-lock \
        --repo-allowlist="github.com/myorg/*" \
        --git-username=myusername

GitHub Token 권한:
    - repo (전체 저장소 접근)
    - admin:repo_hook (웹훅 관리)

EOF
}

# 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --github-token=*)
            GITHUB_TOKEN="${1#*=}"
            shift
            ;;
        --slack-webhook=*)
            SLACK_WEBHOOK="${1#*=}"
            shift
            ;;
        --openai-key=*)
            OPENAI_API_KEY="${1#*=}"
            shift
            ;;
        --infracost-key=*)
            INFRACOST_API_KEY="${1#*=}"
            shift
            ;;
        --stack-name=*)
            STACK_NAME="${1#*=}"
            shift
            ;;
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --region=*)
            REGION="${1#*=}"
            shift
            ;;
        --webhook-secret=*)
            WEBHOOK_SECRET="${1#*=}"
            shift
            ;;
        --repo-allowlist=*)
            REPO_ALLOWLIST="${1#*=}"
            shift
            ;;
        --git-username=*)
            GIT_USERNAME="${1#*=}"
            shift
            ;;
        --s3-bucket=*)
            S3_BUCKET="${1#*=}"
            shift
            ;;
        --dynamodb-table=*)
            DYNAMODB_TABLE="${1#*=}"
            shift
            ;;
        --auto-detect)
            AUTO_DETECT=true
            shift
            ;;
        --vpc-id=*)
            EXISTING_VPC_ID="${1#*=}"
            shift
            ;;
        --alb-name=*)
            EXISTING_ALB_NAME="${1#*=}"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ 알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 필수 인수 검증
if [[ -z "$GITHUB_TOKEN" || -z "$SLACK_WEBHOOK" || -z "$OPENAI_API_KEY" ]]; then
    echo "❌ 필수 인수가 누락되었습니다."
    show_usage
    exit 1
fi

# Webhook secret 자동 생성
if [[ -z "$WEBHOOK_SECRET" ]]; then
    WEBHOOK_SECRET=$(openssl rand -hex 32)
fi

# 기본값 설정
if [[ -z "$REPO_ALLOWLIST" ]]; then
    REPO_ALLOWLIST="github.com/*/*"
fi

if [[ -z "$GIT_USERNAME" ]]; then
    GIT_USERNAME=$(git config user.name 2>/dev/null || echo "atlantis")
fi

echo "🚀 StackKit Atlantis AI Reviewer 셋업 시작"
echo "=================================="
echo "스택 이름: $STACK_NAME"
echo "환경: $ENVIRONMENT"
echo "리전: $REGION"
echo "Repository 허용 패턴: $REPO_ALLOWLIST"
echo "Git 사용자명: $GIT_USERNAME"
echo "Webhook Secret: ${WEBHOOK_SECRET:0:8}..."
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN 모드 - 실제 실행하지 않음"
    echo ""
fi

# 기존 리소스 자동 감지 함수들
detect_existing_resources() {
    echo "🔍 기존 AWS 리소스 자동 감지 중..."
    
    # VPC 감지
    if [[ -z "$EXISTING_VPC_ID" ]]; then
        echo "   VPC 검색 중..."
        local vpcs=$(aws ec2 describe-vpcs --query 'Vpcs[?State==`available`].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null)
        if [[ -n "$vpcs" && "$vpcs" != *"None"* ]]; then
            echo "   📋 발견된 VPC 목록:"
            echo "$vpcs"
            echo ""
            read -p "   사용할 VPC ID를 입력하세요 (새로 생성하려면 Enter): " vpc_choice
            if [[ -n "$vpc_choice" ]]; then
                EXISTING_VPC_ID="$vpc_choice"
                echo "   ✅ VPC $EXISTING_VPC_ID 선택됨"
            fi
        fi
    fi
    
    # 선택된 VPC의 서브넷 감지
    if [[ -n "${EXISTING_VPC_ID}" ]]; then
        echo "   VPC ${EXISTING_VPC_ID}의 서브넷 검색 중..."
        local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$EXISTING_VPC_ID" --query 'Subnets[].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Public:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value|[0]}' --output table 2>/dev/null)
        if [[ -n "$subnets" ]]; then
            echo "   📋 VPC의 서브넷 목록:"
            echo "$subnets"
        fi
    fi
    
    # ALB 감지
    if [[ -z "$EXISTING_ALB_NAME" ]]; then
        echo "   Application Load Balancer 검색 중..."
        local albs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].[LoadBalancerName,DNSName,VpcId]' --output table 2>/dev/null)
        if [[ -n "$albs" && "$albs" != *"None"* ]]; then
            echo "   📋 발견된 ALB 목록:"
            echo "$albs"
            echo ""
            read -p "   사용할 ALB 이름을 입력하세요 (새로 생성하려면 Enter): " alb_choice
            if [[ -n "$alb_choice" ]]; then
                EXISTING_ALB_NAME="$alb_choice"
                echo "   ✅ ALB $EXISTING_ALB_NAME 선택됨"
            fi
        fi
    fi
    
    echo ""
}

# 기존 리소스 정보 수집
collect_existing_resource_info() {
    if [[ -n "${EXISTING_VPC_ID}" ]]; then
        echo "🔍 기존 VPC 정보 수집 중..."
        
        # Public 서브넷 수집
        EXISTING_PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=${EXISTING_VPC_ID}" "Name=map-public-ip-on-launch,Values=true" \
            --query 'Subnets[].SubnetId' --output text 2>/dev/null | tr '\t' ',')
        
        # Private 서브넷 수집
        EXISTING_PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=${EXISTING_VPC_ID}" "Name=map-public-ip-on-launch,Values=false" \
            --query 'Subnets[].SubnetId' --output text 2>/dev/null | tr '\t' ',')
        
        echo "   ✅ Public 서브넷: ${EXISTING_PUBLIC_SUBNETS}"
        echo "   ✅ Private 서브넷: ${EXISTING_PRIVATE_SUBNETS}"
    fi
    
    if [[ -n "${EXISTING_ALB_NAME}" ]]; then
        echo "🔍 기존 ALB 정보 수집 중..."
        
        # ALB ARN 및 DNS 이름 수집
        EXISTING_ALB_ARN=$(aws elbv2 describe-load-balancers \
            --names "${EXISTING_ALB_NAME}" \
            --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
        
        EXISTING_ALB_DNS=$(aws elbv2 describe-load-balancers \
            --names "${EXISTING_ALB_NAME}" \
            --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null)
        
        echo "   ✅ ALB ARN: ${EXISTING_ALB_ARN}"
        echo "   ✅ ALB DNS: ${EXISTING_ALB_DNS}"
    fi
    
    echo ""
}

# 사전 요구사항 검증
echo "🔍 사전 요구사항 검증 중..."

# AWS CLI 확인
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되지 않았습니다."
    exit 1
fi

# AWS 자격증명 확인
if [[ "$DRY_RUN" != "true" ]]; then
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS 자격증명이 설정되지 않았습니다."
        echo "   aws configure를 실행하여 설정하세요."
        exit 1
    fi
fi

# Terraform 확인
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform이 설치되지 않았습니다."
    exit 1
fi

# Java 확인 (AI Reviewer 빌드용)
if [[ "$SKIP_BUILD" != "true" ]] && ! command -v java &> /dev/null; then
    echo "❌ Java가 설치되지 않았습니다. (AI Reviewer 빌드 필요)"
    exit 1
fi

echo "✅ 사전 요구사항 검증 완료"
echo ""

# 기존 리소스 자동 감지 실행
if [[ "$AUTO_DETECT" == "true" ]] || [[ -n "$EXISTING_VPC_ID" ]] || [[ -n "$EXISTING_ALB_NAME" ]]; then
    detect_existing_resources
    collect_existing_resource_info
fi

# Step 1: AI Reviewer 빌드
if [[ "$SKIP_BUILD" != "true" ]]; then
    echo "🔨 Step 1: AI Reviewer Lambda 빌드 중..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        cd "$PROJECT_ROOT/ai-reviewer"
        ./build.sh
        echo "✅ AI Reviewer 빌드 완료"
    else
        echo "   [DRY RUN] cd $PROJECT_ROOT/ai-reviewer && ./build.sh"
    fi
    echo ""
else
    echo "⏭️  Step 1: AI Reviewer 빌드 건너뛰기"
    echo ""
fi

# Step 2: AWS Secrets Manager 설정
echo "🔐 Step 2: AWS Secrets Manager 시크릿 생성 중..."

create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "   [DRY RUN] aws secretsmanager create-secret --name '$secret_name' --description '$description'"
        return 0
    fi
    
    # 기존 시크릿 확인
    if aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
        echo "   ⚠️  시크릿 '$secret_name'이 이미 존재합니다. 업데이트 중..."
        aws secretsmanager update-secret --secret-id "$secret_name" --secret-string "$secret_value"
    else
        echo "   📝 시크릿 '$secret_name' 생성 중..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value"
    fi
}

create_secret "atlantis/github-token" "$GITHUB_TOKEN" "GitHub Personal Access Token for Atlantis"
create_secret "atlantis/webhook-secret" "$WEBHOOK_SECRET" "GitHub Webhook Secret for Atlantis"
create_secret "atlantis/slack-webhook" "$SLACK_WEBHOOK" "Slack Webhook URL for AI Review notifications"
create_secret "atlantis/openai-api-key" "$OPENAI_API_KEY" "OpenAI API Key for AI Reviews"

# Infracost API Key (선택사항)
if [[ -n "$INFRACOST_API_KEY" ]]; then
    create_secret "atlantis/infracost-api-key" "$INFRACOST_API_KEY" "Infracost API Key for cost estimation"
    echo "   💰 Infracost API Key가 설정되어 정확한 비용 추정이 가능합니다."
else
    echo "   ⚠️  Infracost API Key가 설정되지 않음. 기본 비용 추정만 제공됩니다."
fi

echo "✅ AWS Secrets Manager 설정 완료"
echo ""

# 기본값 설정
if [[ -z "$S3_BUCKET" ]]; then
    S3_BUCKET="stackkit-tfstate"
fi

if [[ -z "$DYNAMODB_TABLE" ]]; then
    DYNAMODB_TABLE="$ENVIRONMENT-stackkit-tf-lock"
fi

# VPC 설정 기본값
USE_EXISTING_VPC="false"
EXISTING_VPC_ID=""
EXISTING_PUBLIC_SUBNET_IDS="[]"
EXISTING_PRIVATE_SUBNET_IDS="[]"

# Step 3: Terraform 스택 생성
STACK_DIR="$PROJECT_ROOT/terraform/stacks/$STACK_NAME/$ENVIRONMENT"

echo "🏗️  Step 3: Terraform 스택 생성 중..."

if [[ "$DRY_RUN" != "true" ]]; then
    cd "$PROJECT_ROOT/terraform/scripts"
    
    if [[ ! -d "$STACK_DIR" ]]; then
        echo "   📁 새 스택 생성: $STACK_NAME-$ENVIRONMENT-$REGION"
        # 백엔드 설정 파일 업데이트
        BACKEND_FILE="$STACK_DIR/backend.hcl"
        if [[ -f "$BACKEND_FILE" ]]; then
            echo "   🔧 Backend 설정 업데이트 중..."
            sed -i "s/bucket.*=.*/bucket = \"$S3_BUCKET\"/" "$BACKEND_FILE"
            sed -i "s/dynamodb_table.*=.*/dynamodb_table = \"$DYNAMODB_TABLE\"/" "$BACKEND_FILE"
            sed -i "s/region.*=.*/region = \"$REGION\"/" "$BACKEND_FILE"
        fi
        
        ./new-stack.sh "$STACK_NAME" "$ENVIRONMENT" --template=atlantis-ai-reviewer --region="$REGION" --bucket="$S3_BUCKET" --table="$DYNAMODB_TABLE"
    else
        echo "   ⚠️  스택 디렉토리가 이미 존재합니다: $STACK_DIR"
    fi
else
    echo "   [DRY RUN] Backend 설정 업데이트: $S3_BUCKET, $DYNAMODB_TABLE"
    echo "   [DRY RUN] ./new-stack.sh $STACK_NAME $ENVIRONMENT --template=atlantis-ai-reviewer --region=$REGION --bucket=$S3_BUCKET --table=$DYNAMODB_TABLE"
fi

echo "✅ Terraform 스택 생성 완료"
echo ""

# Step 4: Terraform 변수 설정
echo "⚙️  Step 4: Terraform 변수 설정 중..."

TFVARS_FILE="$STACK_DIR/terraform.tfvars"

if [[ "$DRY_RUN" != "true" ]]; then
    # AWS 계정 ID 가져오기
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # terraform.tfvars 파일이 없으면 생성
    if [[ ! -f "$TFVARS_FILE" ]]; then
        echo "   📝 terraform.tfvars 파일 생성 중..."
        cat > "$TFVARS_FILE" << EOF
# StackKit Atlantis AI Reviewer Configuration
# Generated by setup-atlantis-ai.sh at $(date)

# 기본 설정
stack_name     = "$STACK_NAME"
env            = "$ENVIRONMENT"
region         = "$REGION"
git_username   = "$GIT_USERNAME"
repo_allowlist = "$REPO_ALLOWLIST"

# Git 및 Webhook 설정
webhook_secret = "$WEBHOOK_SECRET"
slack_webhook_url = "$SLACK_WEBHOOK"
openai_api_key = "$OPENAI_API_KEY"

# AWS Secrets Manager ARNs (자동 생성됨)
git_token_secret_arn        = "arn:aws:secretsmanager:$REGION:$AWS_ACCOUNT_ID:secret:atlantis/github-token"
aws_access_key_secret_arn   = "arn:aws:secretsmanager:$REGION:$AWS_ACCOUNT_ID:secret:atlantis/aws-access-key"
aws_secret_key_secret_arn   = "arn:aws:secretsmanager:$REGION:$AWS_ACCOUNT_ID:secret:atlantis/aws-secret-key"

# 기존 VPC 사용 여부 (기본값: false - 새 VPC 생성)
use_existing_vpc = false
# existing_vpc_id = "vpc-0123456789abcdef0"
# existing_public_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0abcdef123456789"]
# existing_private_subnet_ids = ["subnet-0fedcba987654321", "subnet-0987654321fedcba"]

# 기존 S3 버킷 사용 여부 (기본값: false - 새 버킷 생성)
use_existing_s3_bucket = false
# existing_s3_bucket_name = "my-existing-bucket"

# 기존 ECS 클러스터 사용 여부 (기본값: false - 새 클러스터 생성)
use_existing_ecs_cluster = false
# existing_ecs_cluster_name = "my-existing-cluster"

# 기존 ALB 사용 여부 (기본값: false - 새 ALB 생성)
use_existing_alb = false
# existing_alb_arn = "arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id"
# existing_alb_dns_name = "alb-name-123456789.region.elb.amazonaws.com"
EOF
        
        # Infracost API Key 추가 (있는 경우)
        if [[ -n "$INFRACOST_API_KEY" ]]; then
            echo "" >> "$TFVARS_FILE"
            echo "# Infracost Configuration" >> "$TFVARS_FILE"
            echo "infracost_api_key = \"$INFRACOST_API_KEY\"" >> "$TFVARS_FILE"
        fi
    fi
    
    
    # 기존 VPC 사용 설정
    if [[ -n "$EXISTING_VPC_ID" ]]; then
        echo "   🔄 기존 VPC 사용 설정: $EXISTING_VPC_ID"
        sed -i '' "s/use_existing_vpc = false/use_existing_vpc = true/" "$TFVARS_FILE"
        sed -i '' "s/# existing_vpc_id = \"vpc-0123456789abcdef0\"/existing_vpc_id = \"$EXISTING_VPC_ID\"/" "$TFVARS_FILE"
        
        # 서브넷 배열 형식으로 변환
        if [[ -n "$EXISTING_PUBLIC_SUBNETS" ]]; then
            PUBLIC_SUBNET_ARRAY="[\"$(echo "$EXISTING_PUBLIC_SUBNETS" | sed 's/,/", "/g')\"]"
            sed -i '' "s/# existing_public_subnet_ids = \[\"subnet-0123456789abcdef0\", \"subnet-0abcdef123456789\"\]/existing_public_subnet_ids = $PUBLIC_SUBNET_ARRAY/" "$TFVARS_FILE"
        fi
        
        if [[ -n "$EXISTING_PRIVATE_SUBNETS" ]]; then
            PRIVATE_SUBNET_ARRAY="[\"$(echo "$EXISTING_PRIVATE_SUBNETS" | sed 's/,/", "/g')\"]"
            sed -i '' "s/# existing_private_subnet_ids = \[\"subnet-0fedcba987654321\", \"subnet-0987654321fedcba\"\]/existing_private_subnet_ids = $PRIVATE_SUBNET_ARRAY/" "$TFVARS_FILE"
        fi
    fi
    
    # 기존 ALB 사용 설정
    if [[ -n "$EXISTING_ALB_NAME" ]]; then
        echo "   🔄 기존 ALB 사용 설정: $EXISTING_ALB_NAME"
        sed -i '' "s/use_existing_alb = false/use_existing_alb = true/" "$TFVARS_FILE"
        sed -i '' "s|# existing_alb_arn = \"arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id\"|existing_alb_arn = \"$EXISTING_ALB_ARN\"|" "$TFVARS_FILE"
        sed -i '' "s/# existing_alb_dns_name = \"alb-name-123456789.region.elb.amazonaws.com\"/existing_alb_dns_name = \"$EXISTING_ALB_DNS\"/" "$TFVARS_FILE"
    fi

    echo "   📝 Terraform 변수 파일 업데이트: $TFVARS_FILE"
    echo "   🔑 AWS 계정 ID: $AWS_ACCOUNT_ID"
    echo "   👤 Git 사용자: $GIT_USERNAME"
    echo "   📋 Repository 허용 목록: $REPO_ALLOWLIST"
else
    echo "   [DRY RUN] Terraform 변수 파일 생성: $TFVARS_FILE"
fi

echo "✅ Terraform 변수 설정 완료"
echo ""

# Step 5: Terraform 구성 검증
echo "🔍 Step 5: Terraform 구성 검증 중..."

if [[ "$DRY_RUN" != "true" && -d "$STACK_DIR" ]]; then
    cd "$STACK_DIR"
    
    echo "   📋 Terraform 구문 검증 중..."
    if ! terraform validate; then
        echo "❌ Terraform 구문 오류가 발견되었습니다."
        echo "   구성을 확인하고 다시 시도하세요."
        exit 1
    fi
    
    echo "   📊 Terraform 계획 미리보기..."
    terraform plan -detailed-exitcode -out=tfplan.tmp
    PLAN_EXIT_CODE=$?
    
    if [[ $PLAN_EXIT_CODE -eq 1 ]]; then
        echo "❌ Terraform 계획 생성 중 오류 발생"
        exit 1
    elif [[ $PLAN_EXIT_CODE -eq 2 ]]; then
        echo "   ✅ 적용할 변경사항이 감지됨"
        rm -f tfplan.tmp
    else
        echo "   ℹ️  적용할 변경사항이 없음"
        rm -f tfplan.tmp
    fi
    
else
    echo "   [DRY RUN] terraform validate"
    echo "   [DRY RUN] terraform plan -detailed-exitcode"
fi

echo "✅ Terraform 구성 검증 완료"
echo ""

# Step 6: Terraform 배포
if [[ "$SKIP_DEPLOY" != "true" ]]; then
    echo "🚀 Step 6: Terraform 인프라 배포 중..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        cd "$STACK_DIR"
        
        echo "   🔧 Terraform 초기화 중..."
        terraform init -backend-config=backend.hcl
        
        echo "   📋 Terraform 계획 생성 중..."
        terraform plan -out=tfplan
        
        echo "   🚀 Terraform 배포 실행 중..."
        terraform apply tfplan
        
        echo "   📊 배포 결과 출력 중..."
        terraform output
        
    else
        echo "   [DRY RUN] cd $STACK_DIR"
        echo "   [DRY RUN] terraform init -backend-config=backend.hcl"
        echo "   [DRY RUN] terraform plan"
        echo "   [DRY RUN] terraform apply"
    fi
    
    echo "✅ Terraform 인프라 배포 완료"
else
    echo "⏭️  Step 6: Terraform 배포 건너뛰기"
fi

# Step 7: 배포 후 검증 및 정보 출력
if [[ "$DRY_RUN" != "true" && "$SKIP_DEPLOY" != "true" ]]; then
    echo "🔍 Step 7: 배포 후 검증 중..."
    cd "$STACK_DIR"
    
    # Terraform 출력값 확인
    echo "   📊 배포 결과 출력값:"
    ATLANTIS_URL=$(terraform output -raw atlantis_url 2>/dev/null || echo "N/A")
    ATLANTIS_DNS=$(terraform output -raw atlantis_load_balancer_dns 2>/dev/null || echo "N/A")
    EFS_ID=$(terraform output -raw efs_file_system_id 2>/dev/null || echo "N/A")
    
    echo "   🌐 Atlantis URL: $ATLANTIS_URL"
    echo "   📡 ALB DNS: $ATLANTIS_DNS"
    echo "   💾 EFS File System: $EFS_ID"
    
    # 헬스체크 테스트 (선택적)
    if [[ "$ATLANTIS_URL" != "N/A" && "$ATLANTIS_URL" != "" ]]; then
        echo "   🏥 헬스체크 테스트 중..."
        sleep 10  # 서비스가 시작할 시간을 줌
        
        if curl -s -o /dev/null -w "%{http_code}" "$ATLANTIS_URL/healthz" | grep -q "200"; then
            echo "   ✅ Atlantis 서비스 정상 동작 확인"
        else
            echo "   ⚠️  Atlantis 서비스가 아직 준비되지 않았습니다. 몇 분 후 다시 확인해주세요."
        fi
    fi
    
    echo "✅ 배포 후 검증 완료"
fi

echo ""
echo "🎉 StackKit Atlantis AI Reviewer 셋업 완료!"
echo "=========================================="

if [[ "$DRY_RUN" != "true" && "$SKIP_DEPLOY" != "true" ]]; then
    echo ""
    echo "📋 다음 단계:"
    echo "1. 🔗 GitHub Repository에 Webhook 설정"
    echo "   - Repository Settings → Webhooks → Add webhook"
    echo "   - Payload URL: $ATLANTIS_URL/events"
    echo "   - Content type: application/json"
    echo "   - Secret: (AWS Secrets Manager에서 atlantis/webhook-secret 확인)"
    echo "   - Events: Pull requests, Issue comments, Push"
    echo ""
    echo "2. 📄 Repository에 atlantis.yaml 파일 추가"
    echo "   cp $PROJECT_ROOT/atlantis/atlantis.yaml ./atlantis.yaml"
    echo ""
    echo "3. 🌐 Atlantis 웹 인터페이스 접근"
    echo "   브라우저에서 $ATLANTIS_URL 접속하여 동작 확인"
    echo ""
    echo "4. 🧪 테스트 PR 생성하여 AI 리뷰 확인"
    echo ""
    echo "💡 유용한 명령어:"
    echo "   - Atlantis 로그: aws logs tail /ecs/atlantis-ai-reviewer-atlantis --follow"
    echo "   - Init 컨테이너 로그: aws logs tail /ecs/atlantis-ai-reviewer-atlantis --log-stream-prefix init"
    echo "   - Lambda 로그: aws logs tail /aws/lambda/atlantis-ai-reviewer-plan-ai-reviewer --follow"
    echo "   - CloudWatch 알람: aws cloudwatch describe-alarms --alarm-names atlantis-ai-reviewer-*"
    echo "   - EFS 상태: aws efs describe-file-systems --file-system-id $EFS_ID"
    echo "   - 인프라 제거: cd $STACK_DIR && terraform destroy"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "🔍 DRY RUN 완료"
    echo "실제 배포를 위해 --dry-run 옵션을 제거하고 다시 실행하세요."
    echo ""
    echo "📋 예상 리소스:"
    echo "   - ECS 클러스터 및 서비스 (Init Container 포함)"
    echo "   - Application Load Balancer (공용 액세스)"
    echo "   - EFS 파일 시스템 (BoltDB 영속성)"
    echo "   - Lambda 함수 2개 (AI 리뷰)"
    echo "   - SQS 큐 2개 + DLQ"
    echo "   - CloudWatch 알람 4개"
    echo "   - SNS 토픽 (알림)"
fi

echo ""
echo "📚 자세한 문서: $PROJECT_ROOT/README.md"
echo "🐛 문제 발생 시: $PROJECT_ROOT/terraform/docs/TROUBLESHOOTING.md"
