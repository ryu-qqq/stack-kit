# 🎯 StackKit Atlantis 데모 - 실제 예제 사용법

이 문서는 실제로 따라할 수 있는 데모 예제입니다.

## 📋 사전 준비

### AWS 리소스 확인

```bash
# 1. AWS CLI 설정 확인
aws sts get-caller-identity

# 2. 현재 VPC 목록 확인
aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# 3. 기본 VPC의 서브넷 확인 (VPC ID를 실제 값으로 변경)
export VPC_ID="vpc-0123456789abcdef0"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch,CidrBlock]' \
  --output table

# 4. S3 버킷 목록 확인
aws s3 ls
```

### GitHub 설정 준비

```bash
# GitHub Personal Access Token 생성 (다음 권한 필요)
# - repo (full control)
# - admin:repo_hook
# - admin:org_hook (조직의 경우)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Slack Webhook URL 생성
# Slack App → Incoming Webhooks 활성화
export SLACK_WEBHOOK="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
```

## 🚀 실제 배포 데모

### 1단계: 템플릿 저장소 생성

```bash
# GitHub에서 템플릿 사용 또는 직접 클론
git clone https://github.com/your-org/stackkit-template.git mycompany-atlantis
cd mycompany-atlantis

# 새 원격 저장소로 설정 (선택사항)
git remote set-url origin https://github.com/mycompany/mycompany-atlantis.git
```

### 2단계: 실제 설정값으로 terraform.tfvars 생성

실제 AWS 환경에 맞는 값을 입력하세요:

```bash
# terraform/environments/dev/terraform.tfvars 파일 생성
cat > terraform/environments/dev/terraform.tfvars << 'EOF'
# 실제 환경 설정 예제
org_name = "demo"
environment = "dev"
aws_region = "ap-northeast-2"

# 실제 VPC 정보 (아래 값들을 실제 환경에 맞게 변경)
vpc_id = "vpc-0a1b2c3d4e5f6789"
public_subnet_ids = [
  "subnet-0123456789abcdef0",    # ap-northeast-2a public
  "subnet-fedcba9876543210f"     # ap-northeast-2c public
]
private_subnet_ids = [
  "subnet-0a1b2c3d4e5f6g7h",    # ap-northeast-2a private
  "subnet-8h7g6f5e4d3c2b1a"     # ap-northeast-2c private
]

# 기존 S3 버킷 사용 (실제 버킷명으로 변경)
s3_bucket_name = "demo-terraform-state-bucket"

# GitHub 설정
github_user = "demo-devops"
repo_allowlist = [
  "github.com/mycompany/*",
  "github.com/mycompany/demo-app"
]
EOF
```

### 3단계: GitHub Secrets 설정

저장소의 Settings → Secrets and variables → Actions에서 설정:

```bash
# 다음 값들을 GitHub Secrets에 추가
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
```

### 4단계: 배포 실행

```bash
# 설정 파일 커밋 및 푸시
git add terraform/environments/dev/terraform.tfvars
git commit -m "feat: configure demo atlantis infrastructure"
git push origin main
```

### 5단계: 배포 상태 확인

```bash
# GitHub Actions 로그 확인 (브라우저)
# https://github.com/mycompany/mycompany-atlantis/actions

# AWS 리소스 생성 확인
aws ecs list-clusters --query 'clusterArns' --output table
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName,`atlantis`)].DNSName' --output table
```

## 🧪 테스트 시나리오

### 테스트용 프로젝트 저장소 생성

```bash
# 새 프로젝트 저장소 생성
mkdir demo-app && cd demo-app
git init
git remote add origin https://github.com/mycompany/demo-app.git

# Atlantis 설정 추가
cat > atlantis.yaml << 'EOF'
version: 3
projects:
- name: demo-app
  dir: terraform/
  workflow: default
  autoplan:
    enabled: true
    when_modified: ["**/*.tf", "**/*.tfvars"]
EOF

# 간단한 Terraform 코드 생성
mkdir -p terraform
cat > terraform/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
  
  backend "s3" {
    bucket = "demo-terraform-state-bucket"
    key    = "demo-app/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
  
  default_tags {
    tags = {
      Project     = "demo-app"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# 테스트용 S3 버킷 생성
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket" "demo" {
  bucket = "demo-app-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "Demo App Bucket"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 출력
output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.demo.arn
}
EOF
```

### PR 생성 및 테스트

```bash
# 브랜치 생성 및 푸시
git add .
git commit -m "feat: add demo S3 bucket infrastructure"
git push -u origin main

# feature 브랜치 생성
git checkout -b feature/add-s3-bucket
git push -u origin feature/add-s3-bucket

# GitHub에서 PR 생성 또는 CLI 사용
gh pr create \
  --title "Add demo S3 bucket" \
  --body "Testing Atlantis + AI reviewer integration"
```

### 예상 결과

1. **PR 생성 후 자동 실행**:
   - Atlantis가 `terraform plan` 실행
   - AI 리뷰어가 계획 분석
   - PR에 계획 결과 코멘트 추가

2. **Slack 알림 예시**:
```
🤖 AI Review - Terraform Plan

📊 변경 사항
• 생성: 4개 리소스 (S3 bucket, versioning, encryption, random_id)
• 수정: 0개 리소스
• 삭제: 0개 리소스
• 예상 월 비용: ~$2

🛡️ 보안 검토
• S3 버킷 암호화 활성화됨 ✅
• S3 버전 관리 활성화됨 ✅
• 퍼블릭 액세스 차단 권장 ⚠️

💰 비용 최적화
• Standard Storage 클래스 사용 - 적절함

✅ 승인 권장
```

3. **Apply 실행**:
```bash
# PR에 코멘트로 적용 명령
atlantis apply
```

## 📊 모니터링 및 확인

### 생성된 리소스 확인

```bash
# ECS 클러스터 상태 확인
aws ecs describe-clusters \
  --clusters demo-atlantis-dev-cluster \
  --query 'clusters[0].{Name:clusterName,Status:status,RunningTasks:runningTasksCount}'

# ALB 상태 확인
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names demo-atlantis-dev-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --load-balancer-arn $ALB_ARN \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

### 로그 확인

```bash
# Atlantis 서버 로그
aws logs tail /ecs/demo-atlantis-dev --follow

# AI 리뷰어 Lambda 로그
aws logs tail /aws/lambda/demo-atlantis-dev-ai-reviewer --follow
```

### 웹 인터페이스 접근

```bash
# ALB DNS 이름 확인
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names demo-atlantis-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "Atlantis URL: http://$ALB_DNS"
```

## 🧹 정리하기

테스트 완료 후 리소스 정리:

```bash
# Terraform 리소스 삭제
cd demo-app
git checkout main
atlantis apply -d terraform/ -p demo-app  # 또는 PR에서 destroy 명령

# Atlantis 인프라 삭제
cd ../mycompany-atlantis
# GitHub Actions에서 destroy workflow 실행 또는
cd terraform/environments/dev
terraform init
terraform destroy
```

## 🔍 문제 해결 시나리오

### 시나리오 1: VPC 오류

```bash
# 오류: Invalid VPC ID
# 해결방법: 정확한 VPC ID 확인
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,IsDefault,State]' --output table
```

### 시나리오 2: 서브넷 오류

```bash
# 오류: Subnet not in different AZs
# 해결방법: 다른 가용영역의 서브넷 선택
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0123456789abcdef0" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table
```

### 시나리오 3: Lambda 함수 오류

```bash
# AI 리뷰어 로그 확인
aws logs filter-log-events \
  --log-group-name /aws/lambda/demo-atlantis-dev-ai-reviewer \
  --start-time $(date -d '1 hour ago' +%s)000
```

이 데모를 통해 실제 환경에서 StackKit Atlantis 템플릿을 테스트하고 사용법을 익힐 수 있습니다.