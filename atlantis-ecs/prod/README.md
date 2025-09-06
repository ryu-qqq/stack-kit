# Atlantis ECS - Production Environment

## 🎯 개요
StackKit 표준을 따라 구축된 프로덕션급 Atlantis ECS 서버 배포 환경입니다.  
AWS ECS Fargate를 사용하여 확장 가능하고 안정적인 Terraform 자동화 인프라를 제공합니다.

## 🏗️ 환경 정보
- **환경**: Production (prod)
- **리전**: ap-northeast-2 (Seoul)
- **플랫폼**: AWS ECS Fargate
- **배포 방식**: Terraform Infrastructure as Code
- **관리**: StackKit 표준 호환

## 📦 배포되는 AWS 리소스

### 핵심 인프라
- **VPC**: 2-AZ 구성, 퍼블릭/프라이빗 서브넷, NAT Gateway
- **ECS Cluster**: Fargate 기반, Auto Scaling 지원
- **Application Load Balancer**: HTTPS 리스너, SSL 종료, 헬스체크
- **EFS**: Atlantis 데이터 영구 저장소 (BoltDB, Git repos)

### 보안 및 인증
- **AWS Secrets Manager**: GitHub Token, Webhook Secret 암호화 저장
- **IAM Roles**: 최소 권한 원칙, ECS Task/Execution 역할
- **Security Groups**: 필요한 포트만 개방 (80, 443, 4141)

### 모니터링 및 알림
- **CloudWatch Logs**: ECS 태스크 로그 수집
- **CloudWatch Alarms**: CPU, 메모리, ALB 헬스체크 알람
- **SNS Topics**: 이메일/Slack 알림 채널

### 선택적 고급 기능
- **AI Reviewer Lambda**: OpenAI 기반 Terraform 계획 자동 분석 (실험적)
- **S3 Bucket**: AI 리뷰용 계획 파일 저장소
- **SQS Queue**: AI 리뷰 작업 큐
- **EventBridge**: S3 이벤트 기반 Lambda 트리거

## 🚀 배포 방법

### 방법 1: 자동 배포 스크립트 (권장)

상위 디렉토리의 `quick-deploy.sh` 스크립트를 사용하여 완전 자동 배포:

```bash
# 프로젝트 루트에서 실행
cd ..

# 최소 설정으로 배포
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx

# 기존 VPC 활용 배포
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx \
  --vpc-id vpc-12345678

# AI 리뷰어 포함 배포 (실험적 기능)
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx \
  --enable-ai-reviewer --openai-key sk-xxxxxxxxxxxx

# 환경변수 사용 (GitHub Actions/CI 환경)
export TF_STACK_REGION=ap-northeast-2
export ATLANTIS_GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export ATLANTIS_AWS_ACCESS_KEY_ID=AKIA...
export ATLANTIS_AWS_SECRET_ACCESS_KEY=...
./quick-deploy.sh --org mycompany
```

### 방법 2: 수동 배포 (고급 사용자)

Terraform을 직접 사용하여 세밀한 제어:

```bash
# 1. prod 디렉토리로 이동
cd prod/

# 2. 설정 파일 준비
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 필수 값들 설정

# 3. 백엔드 설정 (S3 + DynamoDB)
# backend.hcl 파일 확인 및 수정

# 4. Terraform 초기화
terraform init -backend-config=backend.hcl

# 5. 계획 확인
terraform plan

# 6. 배포 실행
terraform apply

# 7. 출력 확인
terraform output
```

## ⚙️ 필수 설정값

### Terraform 변수 (terraform.tfvars)

`terraform.tfvars.example`을 복사하여 다음 값들을 설정:

```hcl
# 기본 설정
org_name     = "mycompany"
environment  = "prod"
aws_region   = "ap-northeast-2"
stack_name   = "prod-atlantis-stack"
secret_name  = "prod-atlantis-secrets"

# GitHub 설정
git_username   = "mycompany-atlantis"
repo_allowlist = [
    "github.com/mycompany/*"
]

# 기존 인프라 사용 설정 (선택사항)
use_existing_vpc             = false
existing_vpc_id              = ""
existing_public_subnet_ids   = []
existing_private_subnet_ids  = []
existing_state_bucket        = ""
existing_lock_table          = ""

# HTTPS 설정 (선택사항)
custom_domain   = ""
certificate_arn = ""

# 고급 기능
enable_infracost    = false
enable_ai_reviewer  = false  # 실험적 기능
```

### StackKit 표준 환경변수

```bash
# 필수: AWS 인증
ATLANTIS_AWS_ACCESS_KEY_ID=AKIA...
ATLANTIS_AWS_SECRET_ACCESS_KEY=...

# 필수: GitHub 토큰
ATLANTIS_GITHUB_TOKEN=ghp_...

# StackKit 표준
TF_STACK_REGION=ap-northeast-2      # AWS 리전
TF_STACK_NAME=atlantis-prod         # 스택 이름
TF_VERSION=1.7.5                    # Terraform 버전

# 선택적: 고급 기능
INFRACOST_API_KEY=ico-...           # 비용 분석
OPENAI_API_KEY=sk-...               # AI 리뷰어 (실험적)
SLACK_WEBHOOK_URL=https://...       # Slack 알림
```

### AWS Secrets Manager 설정

배포 시 자동으로 생성되는 시크릿:

```json
{
  "github_token": "ghp_...",
  "webhook_secret": "auto-generated-secret",
  "infracost_api_key": "ico-..." // 선택사항
}
```

AI 리뷰어 활성화 시 추가 시크릿:

```json
{
  "openai_api_key": "sk-...",
  "slack_webhook_url": "https://hooks.slack.com/..."
}
```

## 📊 모니터링 및 알림

### CloudWatch 메트릭
- **ECS 메트릭**: CPU 사용률, 메모리 사용률, 태스크 상태
- **ALB 메트릭**: 요청 수, 응답 시간, 헬스체크 상태
- **Lambda 메트릭**: AI 리뷰어 실행 시간, 오류율 (활성화 시)

### 자동 알람
- CPU 사용률 > 80% (5분 연속)
- 메모리 사용률 > 90% (5분 연속)
- ALB 헬스체크 실패 (3회 연속)
- ECS 태스크 중지/재시작
- Lambda 오류 발생 (AI 리뷰어)

### 알림 채널
- **SNS Topics**: 이메일 알림
- **Slack 웹훅**: 실시간 알림 (설정 시)
- **CloudWatch 대시보드**: 실시간 메트릭 시각화

## 💰 비용 관리

### 예상 월간 비용 (ap-northeast-2 기준)
- **기본 구성**: $80-120
  - ECS Fargate: $40-60
  - ALB: $20-25
  - EFS: $5-10
  - CloudWatch/SNS: $5-10
  - NAT Gateway: $15-20

- **AI 리뷰어 포함**: +$20-50
  - Lambda 실행: $5-10
  - OpenAI API: $15-40 (사용량에 따라)

### 비용 최적화 기능
- **Infracost 통합**: PR에서 실시간 비용 영향 분석
- **Auto Scaling**: 트래픽에 따른 자동 스케일링
- **Spot 인스턴스**: 개발 환경에서 비용 절약 (선택사항)

## 🔒 보안 고려사항

### 네트워크 보안
- **VPC 격리**: 전용 VPC에서 실행
- **프라이빗 서브넷**: ECS 태스크는 프라이빗 서브넷에 배포
- **Security Groups**: 최소 필요 포트만 개방
- **HTTPS 강제**: ALB에서 SSL 종료, HTTP → HTTPS 리다이렉트

### 인증 및 권한
- **IAM 역할**: 최소 권한 원칙 적용
- **Secrets Manager**: 모든 민감 정보 암호화 저장
- **GitHub 토큰**: Fine-grained personal access token 권장

### AI 리뷰어 보안 (실험적 기능)
- ⚠️ **데이터 전송**: Terraform 계획이 OpenAI로 전송됨
- 🔍 **민감 정보 필터링**: 시크릿, 패스워드 패턴 자동 제거
- 🌐 **네트워크 정보**: VPC ID, 서브넷 ID 등이 노출될 수 있음
- 🏢 **프로덕션 사용**: 보안 정책에 따라 신중한 검토 필요

## 🏷️ 태그 정책

모든 AWS 리소스에 자동 적용되는 표준 태그:

```hcl
tags = {
  Project     = "atlantis"
  Environment = "prod"
  Stack       = "prod-atlantis-stack"
  Owner       = var.org_name
  ManagedBy   = "terraform"
  CreatedBy   = "atlantis-ecs"
  Repository  = "stackkit/atlantis-ecs"
}
```

## 🛠️ 운영 및 유지보수

### 일반적인 운영 작업

```bash
# ECS 서비스 상태 확인
aws ecs describe-services --cluster prod-atlantis --services prod-atlantis-service

# 태스크 로그 확인
aws logs tail /ecs/atlantis-prod --follow

# 시크릿 업데이트
aws secretsmanager update-secret --secret-id prod-atlantis-secrets --secret-string '{...}'

# ALB 상태 확인
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...
```

### 문제 해결

```bash
# BoltDB 초기화 오류 시
# 1. ECS 서비스 desired count를 0으로 설정
# 2. EFS 마운트 포인트에서 BoltDB 파일 삭제
# 3. 서비스 재시작

# AI 리뷰어 문제 시
aws logs tail /aws/lambda/prod-atlantis-ai-reviewer --follow

# 웹훅 연결 문제 시
# GitHub 저장소 Settings > Webhooks에서 delivery 확인
```

### 업그레이드 절차

1. **Terraform 버전 업그레이드**
   ```bash
   # terraform.tfvars에서 terraform_version 업데이트
   terraform plan
   terraform apply
   ```

2. **Atlantis 이미지 업그레이드**
   ```bash
   # variables.tf에서 atlantis_image 태그 업데이트
   terraform plan
   terraform apply
   ```

3. **AI 리뷰어 업그레이드**
   ```bash
   # lambda/ai-reviewer/ 코드 업데이트 후
   terraform apply
   ```

## 📚 관련 문서

- [상위 README.md](../README.md) - 전체 프로젝트 개요 및 스크립트 사용법
- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [StackKit 표준 가이드](../../terraform/README.md)
- [AWS ECS Fargate 문서](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)

## 🤝 지원 및 기여

문제가 발생하거나 개선사항이 있으시면:

1. **로그 확인**: CloudWatch Logs에서 상세 로그 확인
2. **이슈 생성**: GitHub Issues에 문제 상황 보고
3. **커뮤니티**: StackKit 커뮤니티에서 도움 요청

AI 리뷰어는 실험적 기능이므로 피드백을 특히 환영합니다!

