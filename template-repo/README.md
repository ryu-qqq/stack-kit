# StackKit Atlantis 템플릿

기존 VPC와 S3 버킷을 사용하여 Atlantis + AI 리뷰어를 빠르게 배포하는 GitHub 템플릿입니다.

## 🚀 빠른 시작 (5분 설정)

### 1단계: 템플릿 사용하기

이 템플릿을 사용하여 새 저장소를 만드세요:

1. GitHub에서 "Use this template" 버튼 클릭
2. 새 저장소 이름 입력 (예: `mycompany-atlantis`)
3. "Create repository from template" 클릭

### 2단계: GitHub Secrets 설정

저장소의 Settings → Secrets and variables → Actions에서 다음 secrets를 추가하세요:

```bash
# 필수 Secrets
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"

# 선택사항
INFRACOST_API_KEY=""
```

### 3단계: 설정 파일 작성

`terraform/environments/dev/terraform.tfvars` 파일을 만들고 실제 값을 입력하세요:

```hcl
# 조직 정보
org_name = "mycompany"
environment = "dev"
aws_region = "ap-northeast-2"

# 기존 AWS 리소스 (실제 값으로 변경)
vpc_id = "vpc-0123456789abcdef0"
public_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-fedcba9876543210f"
]
private_subnet_ids = [
  "subnet-0a1b2c3d4e5f6g7h8",
  "subnet-8h7g6f5e4d3c2b1a0"
]
s3_bucket_name = "my-terraform-state-bucket"

# GitHub 설정
github_user = "mycompany-devops"
repo_allowlist = [
  "github.com/mycompany/*"
]
```

### 4단계: 배포하기

1. 파일을 커밋하고 푸시합니다:
```bash
git add terraform/environments/dev/terraform.tfvars
git commit -m "Add Terraform configuration"
git push
```

2. GitHub Actions가 자동으로 인프라를 배포합니다.

3. Actions 탭에서 배포 진행상황을 확인하세요.

## 📋 실제 사용 예제

### AWS 리소스 확인

먼저 기존 AWS 리소스의 ID를 확인하세요:

```bash
# VPC 목록 확인
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table

# 서브넷 목록 확인 (VPC ID를 실제 값으로 변경)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0123456789abcdef0" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# S3 버킷 목록 확인
aws s3 ls
```

### terraform.tfvars 예제 (실제 환경)

```hcl
# 실제 운영 환경 예제
org_name = "acme"
environment = "dev"
aws_region = "ap-northeast-2"

# Seoul 리전 기본 VPC 사용
vpc_id = "vpc-0a1b2c3d4e5f6789"
public_subnet_ids = [
  "subnet-0123456789abcdef0",    # ap-northeast-2a 퍼블릭
  "subnet-fedcba9876543210f"     # ap-northeast-2c 퍼블릭
]
private_subnet_ids = [
  "subnet-0a1b2c3d4e5f6g7h",    # ap-northeast-2a 프라이빗
  "subnet-8h7g6f5e4d3c2b1a"     # ap-northeast-2c 프라이빗
]

# 기존 Terraform 상태 버킷 사용
s3_bucket_name = "acme-terraform-state-prod"

# GitHub 설정
github_user = "acme-devops"
repo_allowlist = [
  "github.com/acme/*",
  "github.com/acme/infrastructure",
  "github.com/acme/terraform-modules"
]
```

## 🔧 배포 후 확인

배포가 완료되면 다음을 확인하세요:

### 1. Atlantis URL 확인
```bash
# ALB DNS 이름 확인
aws elbv2 describe-load-balancers --names "acme-atlantis-dev-alb" \
  --query 'LoadBalancers[0].DNSName' --output text
```

### 2. GitHub Webhook 설정 확인
1. 관리할 저장소의 Settings → Webhooks
2. Atlantis URL이 웹훅으로 설정되어 있는지 확인

### 3. 테스트 PR 생성
간단한 Terraform 파일로 테스트:

```hcl
# test/main.tf
resource "aws_s3_bucket" "test" {
  bucket = "acme-atlantis-test-${random_id.test.hex}"
}

resource "random_id" "test" {
  byte_length = 8
}
```

PR을 생성하면 Atlantis가 자동으로:
- `terraform plan` 실행
- AI가 계획을 리뷰하고 Slack으로 알림
- PR에 계획 결과 코멘트 추가

## 🏗️ 생성되는 AWS 리소스

이 템플릿은 다음 리소스를 생성합니다:

- **ECS Fargate**: Atlantis 서버 실행
- **Application Load Balancer**: 외부 접근용
- **Lambda**: AI 리뷰어 (Java 21)
- **SQS**: AI 리뷰 작업 큐
- **Secrets Manager**: GitHub 토큰과 웹훅 시크릿
- **CloudWatch**: 로그 및 모니터링
- **Security Groups**: 네트워크 보안

기존 리소스 사용:
- ✅ VPC, 서브넷 (기존 사용)
- ✅ S3 버킷 (기존 사용)
- ✅ Route 53, 인증서 (선택사항)

## ⚙️ 고급 설정

### 사용자 정의 도메인 설정

```hcl
# terraform.tfvars에 추가
custom_domain = "atlantis.mycompany.com"
enable_https = true
certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### 알림 설정

Slack 웹훅 URL을 설정하면 다음 상황에 알림이 전송됩니다:
- Terraform 계획 완료
- AI 리뷰 완료
- Apply 성공/실패
- 보안 취약점 발견

## 🔍 문제 해결

### 일반적인 오류

**1. VPC ID 오류**
```
Error: Invalid value for variable "vpc_id"
```
→ `aws ec2 describe-vpcs`로 정확한 VPC ID 확인

**2. 서브넷 부족 오류**
```
Error: At least 2 public subnets are required
```
→ 서로 다른 가용영역의 서브넷 2개 이상 필요

**3. GitHub 토큰 오류**
```
Error: GitHub token must be provided and start with 'ghp_'
```
→ GitHub Settings → Developer settings → Personal access tokens에서 새 토큰 생성

### 로그 확인

```bash
# ECS 로그 확인
aws logs describe-log-groups --log-group-name-prefix "/ecs/acme-atlantis-dev"

# Lambda 로그 확인  
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/acme-atlantis-dev"
```

## 📞 지원

- 이슈 리포트: [GitHub Issues](../../issues)
- 문서: [StackKit 가이드](../../docs)
- Slack: #infrastructure 채널