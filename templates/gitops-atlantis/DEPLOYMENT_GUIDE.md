# GitOps Atlantis 배포 가이드

## 🚀 Quick Start

### 1. StackKit CLI로 프로젝트 생성

```bash
# StackKit CLI를 사용하여 프로젝트 생성
./tools/stackkit-cli.sh new \
  --template gitops-atlantis \
  --name gitops \
  --team platform \
  --org your-company \
  --output-dir ./gitops-infrastructure

cd gitops-infrastructure
```

### 2. 필수 사전 준비사항

#### AWS 준비사항
- [ ] AWS 계정 및 적절한 권한
- [ ] S3 버킷 (Terraform state 저장용)
- [ ] DynamoDB 테이블 (state locking용)
- [ ] Route53 도메인 또는 서브도메인
- [ ] ACM 인증서 (HTTPS용)

#### GitHub 준비사항
- [ ] GitHub Organization 접근 권한
- [ ] Atlantis용 GitHub App 또는 Personal Access Token
- [ ] Webhook 설정 권한

### 3. 설정 파일 구성

```bash
# tfvars 예제 파일 복사
cp terraform.tfvars.example terraform.tfvars

# 조직에 맞게 수정
vim terraform.tfvars
```

#### 주요 설정 항목:
- `organization`: 회사/조직 이름
- `atlantis_github_token`: GitHub 토큰 (Secrets Manager 사용 권장)
- `atlantis_host`: Atlantis 도메인 (예: atlantis.company.com)
- `certificate_arn`: ACM 인증서 ARN

### 4. Backend 설정

```bash
# backend.tf 파일 수정
vim backend.tf

# 다음 값들을 실제 값으로 변경:
# - TERRAFORM_STATE_BUCKET_PLACEHOLDER → your-terraform-state-bucket
# - REGION_PLACEHOLDER → ap-northeast-2
```

### 5. GitHub Token 설정 (Secrets Manager 사용)

```bash
# AWS Secrets Manager에 GitHub 토큰 저장
aws secretsmanager create-secret \
  --name atlantis/github-token \
  --secret-string "ghp_your_github_token_here" \
  --region ap-northeast-2
```

### 6. 인프라 배포

```bash
# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 배포 실행
terraform apply -auto-approve
```

### 7. GitHub Webhook 설정

배포 완료 후 출력되는 값들을 사용하여 GitHub webhook 설정:

1. GitHub Organization/Repository 설정으로 이동
2. Settings → Webhooks → Add webhook
3. 다음 정보 입력:
   - **Payload URL**: `https://atlantis.your-domain.com/events`
   - **Content type**: `application/json`
   - **Secret**: Terraform 출력의 `webhook_secret` 값
   - **Events**: Pull requests, Issue comments, Pushes 선택

### 8. Atlantis 설정 확인

```bash
# ALB DNS 확인
terraform output alb_dns_name

# Atlantis 웹 UI 접속
https://atlantis.your-domain.com
```

## 📋 운영 가이드

### 로그 확인

```bash
# CloudWatch Logs에서 Atlantis 로그 확인
aws logs tail /ecs/atlantis --follow
```

### 스케일링 조정

```bash
# terraform.tfvars 수정
ecs_min_capacity = 2
ecs_max_capacity = 5

# 적용
terraform apply -auto-approve
```

### 백업 및 복구

EFS를 사용하므로 Atlantis 작업 디렉토리가 영구 보존됩니다:
- EFS 자동 백업 활성화 권장
- 재시작 시에도 진행 중인 PR 상태 유지

## 🔧 문제 해결

### Atlantis가 시작되지 않는 경우

1. CloudWatch Logs 확인
2. GitHub Token 권한 확인
3. Security Group 규칙 확인

### Webhook이 작동하지 않는 경우

1. GitHub Webhook 전달 기록 확인
2. ALB Target Group 상태 확인
3. Atlantis 로그에서 webhook 수신 확인

### PR에서 plan이 실행되지 않는 경우

1. `atlantis.yaml` 설정 확인
2. Repository 권한 확인
3. Atlantis 로그 확인

## 📚 추가 리소스

- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [StackKit 문서](/docs/templates/gitops-atlantis.md)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest)

## 💡 Best Practices

1. **보안**
   - GitHub Token은 반드시 Secrets Manager 사용
   - 최소 권한 원칙 적용
   - VPC Private Subnet에 ECS Task 배치

2. **모니터링**
   - CloudWatch Alarms 설정
   - X-Ray 트레이싱 활성화
   - 정기적인 로그 검토

3. **비용 최적화**
   - 개발 환경은 낮은 스펙 사용
   - Auto-scaling 적절히 설정
   - EFS Lifecycle Policy 활용

4. **운영**
   - 정기적인 Atlantis 버전 업데이트
   - atlantis.yaml로 워크플로우 표준화
   - PR 템플릿 활용