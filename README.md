# 🚀 StackKit - 5분만에 시작하는 Atlantis

StackKit은 팀이 5분만에 자신만의 Atlantis 구축하여 안전하고 효율적인 Infrastructure as Code 워크플로우를 시작할 수 있도록 도와줍니다.

---

## ⚡ 5분 빠른 시작

### 🎯 목표: 나만의 Atlantis  구축

```bash
# 1. StackKit 클론 (30초)
git clone https://github.com/ryu-qqq/stackkit.git
cd stackkit

# 2. 사전 준비 확인 (30초)
./atlantis-ecs/scripts/check-prerequisites.sh

# 3. Atlantis 서버 배포 (3가지 방법 중 선택)

# 방법 1: 대화형 설정 마법사 (초보자 권장) 🧙‍♂️
cd atlantis-ecs
./quick-deploy.sh --interactive

# 방법 2: 기본 배포 (빠른 설정)
./quick-deploy.sh \
  --org mycompany \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 방법 3: 고급 배포 (모든 기능 활성화)
./quick-deploy.sh \
  --org mycompany \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --vpc-id vpc-12345678 \
  --slack-webhook https://hooks.slack.com/services/xxx/xxx/xxx \
  --infracost-key ico-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 4. 기존 저장소 연결 (1분)
./connect.sh --atlantis-url http://mycompany-atlantis.aws.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

```

**결과:** 
- ✅ AWS에 완전한 Atlantis 인프라 배포
- ✅ GitHub 웹훅 자동 설정으로 PR 기반 워크플로우 활성화  
- ✅ Slack 알림으로 팀 전체가 실시간 현황 파악

---

## ⚙️ 고급 옵션

### VPC 설정 (기존 VPC 활용)
```bash
# 기존 VPC 사용 (권장: EIP 한계 방지)
cd atlantis-ecs
./quick-deploy.sh --org mycompany \
  --github-token ghp_xxx \
  --vpc-id vpc-12345678 \
  --public-subnets "subnet-abc123,subnet-def456"
```

### AI 리뷰어 활성화 (실험적 기능)
```bash
# AI 기반 Terraform 계획 자동 분석
./quick-deploy.sh --org mycompany \
  --github-token ghp_xxx \
  --enable-ai-reviewer \
  --openai-key sk-xxxxxxxxxxxx \
  --slack-webhook https://hooks.slack.com/services/xxx/xxx/xxx
```

### HTTPS 도메인 설정
```bash
# 커스텀 도메인과 SSL 인증서
./quick-deploy.sh --org mycompany \
  --github-token ghp_xxx \
  --custom-domain atlantis.mycompany.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123456:certificate/xxx
```

## 🔧 필요한 준비물 (5분)

### 1. GitHub Personal Access Token
```bash
# GitHub → Settings → Developer settings → Personal access tokens
# "Generate new token (classic)" 선택
# 권한 선택: repo (전체), admin:repo_hook
# 생성된 ghp_로 시작하는 토큰 복사
```


### 2. AWS 계정 설정
```bash
# AWS CLI 설치 및 인증 정보 설정
aws configure
# 또는 환경 변수로 설정
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

### 3. Slack 웹훅 (선택사항)
```bash
# Slack → Apps → Incoming Webhooks
# Add to Slack → 채널 선택 → Webhook URL 복사
```

### 4. Infracost 비용 분석 (권장)
```bash
# 🎁 무료 플랜으로 시작하기
# https://infracost.io에서 무료 API 키 생성
# 회원가입 → API 키 → 환경변수 설정
export INFRACOST_API_KEY="ico-your-key-here"

# 💰 Infracost 무료 플랜 정보
# - 월 1,000회 추정 무료 (소규모 팀에 충분)
# - PR당 비용 차이 자동 계산
# - 클라우드 대시보드 접근
# - Slack/GitHub 통합
# - 신용카드 불필요

# StackKit 자동 설치 방식
# 공식 Atlantis 이미지에 Infracost를 런타임에 설치
# 별도의 컨테이너 이미지 빌드 불필요
```

---

## 📦 무엇이 설치되나요?

### 🏗️ AWS 인프라 스택
- **ECS Fargate**: Atlantis 서버 실행 환경
- **Application Load Balancer**: 외부 접근을 위한 로드밸런서
- **Secrets Manager**: GitHub 토큰, OpenAI 키 안전한 보관
- **CloudWatch**: 로그 및 모니터링

---

## 🚀 주요 기능

### ⚡ 자동화된 워크플로우
- **PR 생성** → 자동 `terraform plan` 실행
- **Slack 알림** → 팀에 실시간 상태 공유
- **승인 후 Apply** → 안전한 인프라 변경

### 🛡️ 보안 중심 설계
- **시크릿 관리**: AWS Secrets Manager를 통한 안전한 토큰 보관
- **VPC 격리**: 모든 컴포넌트가 프라이빗 서브넷에서 실행
- **암호화**: 저장 및 전송 데이터 암호화
- **접근 제어**: 최소 권한 원칙 적용

---

## 🎯 고급 사용법

### 사용자 정의 도메인 설정
```bash
cd atlantis-ecs
./quick-deploy.sh --org mycompany \
  --github-token ghp_xxx \
  --custom-domain atlantis.mycompany.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123:certificate/xxx
```

### 프로덕션 환경 배포 (기존 VPC 사용 권장)
```bash
cd atlantis-ecs
./quick-deploy.sh --org enterprise \
  --github-token ghp_xxx \
  --vpc-id vpc-prod123 \
  --public-subnets "subnet-prod1,subnet-prod2" \
  --private-subnets "subnet-prod3,subnet-prod4" \
  --environment prod
```

### 완전한 설정 예시 (모든 기능 활성화)
```bash
cd atlantis-ecs
./quick-deploy.sh --org enterprise \
  --github-token ghp_xxx \
  --vpc-id vpc-12345678 \
  --custom-domain atlantis.enterprise.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123456:certificate/xxx \
  --enable-ai-reviewer \
  --openai-key sk-xxxxxxxxxxxx \
  --slack-webhook https://hooks.slack.com/services/xxx/xxx/xxx
```

### 여러 저장소 일괄 연결
```bash
# 저장소 목록 파일 생성
echo "mycompany/backend-infra
mycompany/frontend-infra  
mycompany/data-infra" > repos.txt

# Atlantis URL 설정 (배포 후 ALB DNS 또는 커스텀 도메인)
ATLANTIS_URL="https://mycompany-atlantis-alb-123456789.ap-northeast-2.elb.amazonaws.com"

# 모든 저장소에 대해 연결 스크립트 실행
cd atlantis-ecs
while read repo; do
  ./connect.sh --atlantis-url "$ATLANTIS_URL" \
    --repo-name "$repo" \
    --github-token ghp_xxx
done < repos.txt
```

---

## 📚 문서 가이드

### 📖 단계별 가이드
- **[📋 사전 준비 체크리스트](./docs/prerequisites.md)** - 5분 배포를 위한 환경 확인
- **[⚡ 5분 빠른 시작](./docs/quick-start.md)** - 실제 타이머와 함께하는 배포 가이드
- **[🔗 저장소 연결 가이드](./docs/repository-setup.md)** - 여러 저장소 관리 및 연결
- **[🚀 고급 설정 가이드](./docs/advanced-configuration.md)** - 엔터프라이즈 급 커스터마이징
- **[🔧 문제 해결 가이드](./docs/troubleshooting.md)** - 일반적인 문제와 해결 방법

### 🏗️ Terraform 모듈 활용
StackKit에는 12개 AWS 서비스의 표준화된 모듈이 포함되어 있습니다:

```bash
# 새 프로젝트에서 StackKit 모듈 사용
./terraform/tools/stackkit-cli.sh create my-web-app dev

# 검증 및 배포
./terraform/tools/stackkit-cli.sh validate my-web-app dev
./terraform/tools/stackkit-cli.sh deploy my-web-app dev
```

**📖 상세 가이드**: [Terraform 모듈 완전 가이드](./terraform/README.md)

### 💡 실제 사용 예제 (추가 예정..)
**📁 예제 모음**: [Examples 디렉토리](./examples/)
- 웹 애플리케이션 스택
- API 서버 구성
- 데이터 파이프라인
- 마이크로서비스 아키텍처

---

## 🔍 문제 해결

### 자주 묻는 질문

**Q: AWS 권한이 부족하다는 오류가 나와요**
```bash
# IAM 사용자에게 다음 정책 연결 필요:
# - AdministratorAccess (또는 세분화된 권한)
aws iam attach-user-policy --user-name your-user --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Q: GitHub 웹훅이 제대로 작동하지 않아요**
```bash
# 토큰 권한 확인
# repo (전체), admin:repo_hook 권한이 필요합니다
```

**Q: Infracost 비용 분석이 작동하지 않아요**
```bash
# StackKit은 Infracost 공식 이미지를 사용하므로 바이너리 문제 없음
# ghcr.io/infracost/infracost-atlantis:atlantis-latest

# Infracost 사용하려면:
# 1. API 키 설정 (필수)
export INFRACOST_API_KEY="ico-your-key-here"

# 2. Secrets Manager에 API 키 추가
aws secretsmanager update-secret \
  --secret-id your-atlantis-secrets \
  --secret-string '{"infracost_api_key": "ico-your-key-here"}'

# 3. ECS에서 자동으로 활성화됨
# - Plan 시 비용 분석 자동 실행
# - GitHub PR에 비용 댓글 자동 생성
# - Slack 알림에 비용 정보 포함
```

---

### 개발 환경 설정
```bash
# 저장소 클론
git clone https://github.com/ryu-qqq/stackkit.git
cd stackkit

# 개발용 브랜치 생성
git checkout -b feature/my-improvement

# 변경사항 작성 후 테스트
./quick-start.sh --dry-run --org test --github-token ghp_xxx 
```

---