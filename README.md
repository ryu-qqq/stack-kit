# 🚀 StackKit - 5분만에 시작하는 Atlantis

StackKit은 팀이 5분만에 자신만의 Atlantis 구축하여 안전하고 효율적인 Infrastructure as Code 워크플로우를 시작할 수 있도록 도와줍니다.

---

## ⚡ 5분 빠른 시작

### 🎯 목표: 나만의 Atlantis  구축

```bash
# 1. StackKit 클론 (30초)
git clone https://github.com/ryu-qqq/stackkit.git
cd stackkit

# 2. 5분 자동 배포 (5분)
./quick-start.sh \
  --org mycompany \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --slack-webhook https://hooks.slack.com/services/xxx/xxx/xxx \
  --use-existing-vpc  # EIP 한계 방지를 위한 기존 VPC 사용

# 3. 기존 저장소 연결 (1분)
curl -sSL https://github.com/ryu-qqq/stackkit/raw/main/connect.sh | \
  bash -s -- --atlantis-url http://mycompany-atlantis.aws.com

```

**결과:** 
- ✅ AWS에 완전한 Atlantis 인프라 배포
- ✅ GitHub 웹훅 자동 설정으로 PR 기반 워크플로우 활성화  
- ✅ Slack 알림으로 팀 전체가 실시간 현황 파악

---

## ⚙️ 고급 옵션

### VPC 설정 (EIP 한계 해결)
```bash
# 기존 VPC 사용 (권장: EIP 한계 방지)
./quick-start.sh --org mycompany \
  --github-token xxx --openai-key xxx \
  --use-existing-vpc \
  --vpc-id vpc-12345678 \
  --subnet-ids "subnet-abc123,subnet-def456"
```

### 리소스 충돌 처리
```bash
# 충돌 검사 건너뛰기 (고급 사용자용)
./quick-start.sh --org mycompany \
  --github-token xxx --openai-key xxx \
  --skip-conflicts
```

### 배포 시뮬레이션
```bash
# 실제 배포 없이 계획만 확인
./quick-start.sh --org mycompany \
  --github-token xxx --openai-key xxx \
  --dry-run
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
./quick-start.sh --org mycompany \
  --github-token ghp_xxx --openai-key sk-xxx \
  --custom-domain atlantis.mycompany.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123:certificate/xxx
```

### 프로덕션 환경 배포 (기존 VPC 사용 권장)
```bash
./quick-start.sh --org enterprise --environment prod \
  --github-token ghp_xxx --openai-key sk-xxx \
  --aws-region us-west-2 \
  --use-existing-vpc --vpc-id vpc-prod123 \
  --subnet-ids "subnet-prod1,subnet-prod2"
```

### 리소스 충돌 문제 해결
```bash
# EIP 한계 도달 시
./quick-start.sh --org mycompany \
  --github-token ghp_xxx --openai-key sk-xxx \
  --use-existing-vpc

# CloudWatch 로그 그룹 충돌 시
./quick-start.sh --org mycompany \
  --github-token ghp_xxx --openai-key sk-xxx \
  --skip-conflicts

# 배포 전 체크
./quick-start.sh --org mycompany \
  --github-token ghp_xxx --openai-key sk-xxx \
  --dry-run
```

### 여러 저장소 일괄 연결
```bash
# 저장소 목록 파일 생성
echo "mycompany/backend-infra
mycompany/frontend-infra  
mycompany/data-infra" > repos.txt

# 모든 저장소에 대해 연결 스크립트 실행
while read repo; do
  cd "../$repo"
  curl -sSL https://github.com/ryu-qqq/stackkit/raw/main/connect.sh | \
    bash -s -- --atlantis-url http://mycompany-atlantis.aws.com
done < repos.txt
```

---

## 📚 추가 리소스

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