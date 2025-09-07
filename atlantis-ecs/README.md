# Atlantis ECS - AI-Powered Terraform Automation

## 🎯 개요

StackKit 기반의 프로덕션급 Atlantis 서버 배포 솔루션입니다. AWS ECS Fargate를 사용하여 확장 가능하고 안정적인 Terraform 자동화 환경을 제공합니다.

### 주요 기능

- 🚀 **원클릭 배포**: `quick-deploy.sh`로 5분 내 완전 자동 설정
- 🔗 **저장소 연결**: `connect.sh`로 기존 Atlantis 서버에 프로젝트 연결  
- 💰 **비용 분석**: Infracost 자동 설치로 PR에서 실시간 비용 분석 (무료 플랜 지원)
- 📊 **고급 워크플로우**: 향상된 Slack 알림과 Plan 요약
- 🏗️ **StackKit 호환**: StackKit 표준 변수 및 모듈 완전 지원
- 🔒 **보안 강화**: AWS Secrets Manager, VPC 격리, HTTPS 강제

## 📁 구조

```
atlantis-ecs/
├── quick-deploy.sh      # 🚀 원클릭 Atlantis 서버 배포
├── connect.sh           # 🔗 저장소를 기존 Atlantis에 연결
├── config/
│   └── atlantis.yaml    # 📋 Atlantis 설정 템플릿
├── lambda/
│   └── ai-reviewer/     # 🤖 AI 리뷰어 Lambda (실험적)
└── prod/                # 🏭 프로덕션 환경 Terraform 코드
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md
```

## 🚀 빠른 시작

### 방법 1: 새 Atlantis 서버 배포 (권장)

```bash
# 최소 설정으로 배포
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx

# 기존 VPC 활용
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx \
  --vpc-id vpc-12345678

# AI 리뷰어 포함 (실험적 기능)
./quick-deploy.sh --org mycompany --github-token ghp_xxxxxxxxxxxx \
  --enable-ai-reviewer --openai-key sk-xxxxxxxxxxxx

# 환경변수 사용 (GitHub Actions/CI 환경)
export TF_STACK_REGION=ap-northeast-2
export ATLANTIS_GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export ATLANTIS_AWS_ACCESS_KEY_ID=AKIA...
export ATLANTIS_AWS_SECRET_ACCESS_KEY=...
./quick-deploy.sh --org mycompany
```

### 방법 2: 기존 Atlantis 서버에 연결

```bash
# 기본 연결
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxxxxxxxxxxx

# AI 리뷰어 포함 연결
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxxxxxxxxxxx \
  --enable-ai-reviewer \
  --ai-review-bucket my-ai-review-bucket

# 환경변수 사용
export ATLANTIS_GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export TF_STACK_REGION=ap-northeast-2
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo
```

## 📋 스크립트 상세 사용법

### `quick-deploy.sh` - Atlantis 서버 배포

완전한 Atlantis ECS 인프라를 자동으로 배포합니다.

#### 필수 인수
```bash
--org COMPANY               # 조직/회사 이름
--github-token TOKEN        # GitHub Personal Access Token
```

#### StackKit 표준 환경변수 지원
```bash
TF_STACK_REGION=ap-northeast-2    # AWS 리전
TF_STACK_NAME=mycompany           # 스택 이름 (--org 대신 사용 가능)
ATLANTIS_GITHUB_TOKEN=ghp_xxx     # GitHub 토큰
ATLANTIS_AWS_ACCESS_KEY_ID=AKIA   # AWS 액세스 키
ATLANTIS_AWS_SECRET_ACCESS_KEY=   # AWS 시크릿 키
INFRACOST_API_KEY=ico-xxx         # Infracost API 키
```

#### 기존 인프라 활용 옵션
```bash
--vpc-id VPC_ID                   # 기존 VPC ID (서브넷 자동 검색)
--public-subnets "id1,id2"        # 기존 퍼블릭 서브넷 ID 목록
--private-subnets "id1,id2"       # 기존 프라이빗 서브넷 ID 목록
--state-bucket BUCKET             # 기존 Terraform 상태 S3 버킷
--lock-table TABLE                # 기존 Terraform 락 DynamoDB 테이블
```

#### HTTPS 설정
```bash
--custom-domain DOMAIN            # 커스텀 도메인
--certificate-arn ARN             # SSL 인증서 ARN
```

#### AI 리뷰어 설정 (실험적 기능)
```bash
--enable-ai-reviewer              # AI 리뷰어 활성화
--openai-key KEY                  # OpenAI API 키
--slack-webhook URL               # Slack 웹훅 URL (알림용)
```

#### 사용 예시
```bash
# 기본 배포
./quick-deploy.sh --org acme --github-token ghp_xxx

# 기존 인프라 + HTTPS + AI 리뷰어
./quick-deploy.sh --org enterprise --github-token ghp_xxx \
  --vpc-id vpc-12345678 \
  --custom-domain atlantis.enterprise.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123456789012:certificate/xxx \
  --enable-ai-reviewer \
  --openai-key sk-xxx \
  --slack-webhook https://hooks.slack.com/xxx
```

### `connect.sh` - 저장소 연결

기존 Atlantis 서버에 저장소를 연결하고 설정을 자동화합니다.

#### 필수 인수
```bash
--atlantis-url URL                # Atlantis 서버 URL
--repo-name NAME                  # 저장소 이름 (예: myorg/myrepo)
```

#### 선택 인수
```bash
--project-dir DIR                 # Terraform 프로젝트 디렉토리 (기본: .)
--github-token TOKEN              # GitHub Personal Access Token
--webhook-secret SECRET           # GitHub 웹훅 시크릿 (자동 생성 가능)
--secret-name NAME                # Atlantis Secrets Manager 이름
--aws-region REGION               # AWS 리전 (기본: ap-northeast-2)
--auto-plan                       # 자동 plan 활성화
--auto-merge                      # 자동 merge 활성화
--skip-webhook                    # 웹훅 설정 건너뛰기
```

#### AI 리뷰어 설정 (실험적 기능)
```bash
--enable-ai-reviewer              # AI 리뷰어 활성화
--ai-review-bucket BUCKET         # AI 리뷰용 S3 버킷 이름
```

#### 자동 기능
- GitHub remote에서 저장소 이름 자동 탐지
- Atlantis Secrets Manager와 웹훅 시크릿 동기화
- GitHub 웹훅 자동 설정 및 업데이트
- GitHub Repository Variables 자동 설정
- `.gitignore`, `README.md` 자동 업데이트

#### 사용 예시
```bash
# 기본 연결 (웹훅 자동 설정)
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxx

# 시크릿 동기화 포함
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxx \
  --secret-name prod-atlantis-secrets

# 웹훅 설정 없이 설정 파일만 생성
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --skip-webhook
```

## 💰 Infracost 비용 분석 통합

### 개요
StackKit은 공식 Atlantis 이미지에 Infracost를 자동으로 설치하여 PR에서 실시간 비용 분석을 제공합니다.

### 🎁 무료 플랜 혜택
- **월 100회 추정 무료**: 소규모 개발팀에 충분한 용량
- **PR당 비용 차이 계산**: 변경 전후 비용 자동 비교
- **클라우드 대시보드**: 웹 기반 비용 추세 분석
- **팀 협업 기능**: 여러 팀원이 함께 사용 가능
- **신용카드 불필요**: 무료로 시작, 필요시 업그레이드

### 설정 방법
```bash
# 1. Infracost 가입 및 API 키 발급
# https://www.infracost.io 접속 → Sign Up → API Keys

# 2. API 키 환경변수 설정
export INFRACOST_API_KEY="ico-xxxxxxxxxxxx"

# 3. Atlantis 배포 시 자동 활성화
./quick-deploy.sh --org mycompany --github-token ghp_xxx \
  --infracost-key ico-xxxxxxxxxxxx
```

### 작동 방식
1. **자동 설치**: Atlantis 컨테이너 시작 시 Infracost 바이너리 자동 다운로드
2. **Plan 통합**: `terraform plan` 실행 후 자동으로 비용 분석
3. **PR 댓글**: 비용 차이를 표로 정리하여 PR에 댓글 작성
4. **대시보드 연동**: Infracost Cloud에서 비용 추세 확인

### PR에서 보이는 정보
```markdown
💰 Infracost Cost Estimate

Monthly cost will increase by $125.43 (+15%)

| Resource | Before | After | Diff |
|----------|---------|--------|------|
| aws_instance.web | $50.00 | $100.00 | +$50.00 |
| aws_rds_instance.db | $200.00 | $275.43 | +$75.43 |
| **Total** | **$835.00** | **$960.43** | **+$125.43** |
```

### 고급 설정
```bash
# 환경변수로 추가 옵션 설정
export INFRACOST_ENABLE_CLOUD=true      # 클라우드 대시보드 활성화
export INFRACOST_ENABLE_DASHBOARD=true  # 웹 대시보드 활성화
```

## 🤖 AI 리뷰어 (실험적 기능)

### 개요
OpenAI GPT를 활용하여 Terraform 계획을 자동으로 분석하고 PR에 리뷰 댓글을 작성하는 실험적 기능입니다.

### 주요 기능
- 📊 Terraform 계획 자동 분석
- 🔍 보안 위험 요소 탐지
- 💰 비용 영향 분석
- 📝 자동 PR 댓글 작성
- 🚨 Slack 알림 (선택사항)

### 설정 방법
```bash
# 배포 시 AI 리뷰어 활성화
./quick-deploy.sh --org mycompany --github-token ghp_xxx \
  --enable-ai-reviewer \
  --openai-key sk-xxxxxxxxxxxx \
  --slack-webhook https://hooks.slack.com/xxx

# 기존 서버에 AI 리뷰어 연결
./connect.sh --atlantis-url https://atlantis.company.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxx \
  --enable-ai-reviewer \
  --ai-review-bucket my-ai-review-bucket
```

### 작동 방식
1. Atlantis가 `terraform plan` 실행
2. 계획 결과를 S3 버킷에 업로드
3. Lambda 함수가 S3 이벤트로 트리거됨
4. OpenAI API로 계획 분석
5. GitHub API로 PR에 리뷰 댓글 작성
6. Slack 알림 발송 (설정된 경우)

### 주의사항
- ⚠️ **실험적 기능**: 프로덕션 환경에서 신중히 사용
- 💸 **비용 발생**: OpenAI API 사용량에 따른 비용
- 🔐 **보안**: OpenAI에 인프라 정보 전송됨
- 🚧 **제한사항**: 복잡한 계획의 경우 분석 정확도 제한

## 🛠️ Atlantis 사용법

### 기본 명령어
```bash
# PR에서 댓글로 실행
atlantis plan                     # Terraform plan 실행
atlantis apply                    # Terraform apply 실행 (승인 필요)
atlantis plan -d ./modules/vpc    # 특정 디렉토리만 plan
atlantis unlock                   # 잠금 해제 (필요시)
```

### 고급 명령어
```bash
atlantis plan -w staging          # 특정 워크스페이스
atlantis plan --verbose           # 상세 로그
atlantis apply -auto-merge-disabled # 자동 머지 비활성화
```

### 워크플로우
1. **PR 생성**: Terraform 파일 수정 후 PR 생성
2. **자동 Plan**: `.tf` 파일 변경 시 자동으로 plan 실행 (설정에 따라)
3. **리뷰**: AI 리뷰어가 자동으로 분석 댓글 작성 (활성화된 경우)
4. **승인**: PR 승인 필요 (프로덕션 환경)
5. **Apply**: `atlantis apply` 댓글로 배포 실행

## 🏗️ StackKit 표준 호환

### 환경변수
```bash
# 필수
TF_STACK_REGION=ap-northeast-2
ATLANTIS_GITHUB_TOKEN=ghp_xxx
ATLANTIS_AWS_ACCESS_KEY_ID=AKIA...
ATLANTIS_AWS_SECRET_ACCESS_KEY=...

# 선택적
TF_STACK_NAME=mycompany
TF_VERSION=1.7.5
INFRACOST_API_KEY=ico-xxx
OPENAI_API_KEY=sk-xxx
SLACK_WEBHOOK_URL=https://hooks.slack.com/xxx
```

### GitHub Actions 연동
Repository Settings > Secrets and variables > Actions에서 설정:

**Secrets:**
```yaml
ATLANTIS_GITHUB_TOKEN: "ghp_xxx"
ATLANTIS_AWS_ACCESS_KEY_ID: "AKIA..."
ATLANTIS_AWS_SECRET_ACCESS_KEY: "..."
INFRACOST_API_KEY: "ico-xxx"
OPENAI_API_KEY: "sk-xxx"
SLACK_WEBHOOK_URL: "https://hooks.slack.com/xxx"
```

**Variables:**
```yaml
TF_STACK_REGION: "ap-northeast-2"
TF_STACK_NAME: "atlantis-prod"
```

## 📊 모니터링 및 비용

### 포함된 모니터링
- CloudWatch 대시보드
- ECS, ALB, Lambda 메트릭
- 자동 알람 (CPU, 메모리, 에러)
- SNS 알림 (이메일/Slack)

### 예상 비용 (월간)
- **기본 구성**: $80-120 (ECS Fargate, ALB, RDS 없음)
- **AI 리뷰어 포함**: +$20-50 (OpenAI API 사용량에 따라)
- **고가용성 구성**: $150-200 (Multi-AZ, 더 큰 인스턴스)

## 🔒 보안 고려사항

### 기본 보안
- VPC 프라이빗 서브넷에 ECS 배포
- HTTPS 강제, SSL 종료
- AWS Secrets Manager로 민감 정보 관리
- IAM 역할 기반 최소 권한 원칙

### AI 리뷰어 보안 (실험적 기능)
- ⚠️ Terraform 계획이 OpenAI로 전송됨
- 민감한 정보 필터링 권장
- 프라이빗 네트워크 정보 노출 가능성
- 프로덕션 환경에서 신중한 사용 필요

## 🆘 문제 해결

### 일반적인 문제
```bash
# BoltDB 초기화 오류
# ECS 태스크 중지 → EFS 정리 → 서비스 재시작

# 웹훅 설정 문제
./connect.sh --skip-webhook  # 수동 설정 후 재시도

# AI 리뷰어 작동 안함
# CloudWatch Logs에서 Lambda 로그 확인
# OpenAI API 키 및 S3 권한 확인
```

### 로그 확인
```bash
# ECS 로그
aws logs tail /ecs/atlantis-prod --follow

# Lambda 로그 (AI 리뷰어)
aws logs tail /aws/lambda/prod-atlantis-ai-reviewer --follow
```

## 📚 추가 리소스

- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [StackKit 표준 가이드](../terraform/README.md)
- [Infracost 설정](https://www.infracost.io/docs/)
- [OpenAI API 문서](https://platform.openai.com/docs/) (AI 리뷰어용)

## 🤝 기여

이슈나 개선사항이 있으시면 GitHub Issues를 통해 제보해 주세요. AI 리뷰어는 실험적 기능이므로 피드백을 환영합니다!

