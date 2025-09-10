# 🔧 사전 준비 체크리스트

StackKit 5분 배포를 위한 사전 준비사항을 체크하세요.

## ✅ 필수 준비물 체크리스트

### 1. 개발 환경 도구
- [ ] **AWS CLI** 설치 및 설정 완료
  ```bash
  # 설치 확인
  aws --version
  # 설정 확인
  aws configure list
  ```

- [ ] **Terraform** (1.7.5+) 설치 완료
  ```bash
  terraform version
  ```

- [ ] **jq** JSON 처리 도구 설치
  ```bash
  jq --version
  ```

### 2. AWS 계정 및 권한
- [ ] **AWS 계정** 준비 완료
- [ ] **IAM 사용자** 생성 및 필요 권한 설정
  - AdministratorAccess 또는 다음 세분화된 권한:
    - EC2, ECS, VPC, ALB, Secrets Manager, S3, DynamoDB, CloudWatch

- [ ] **AWS 자격 증명** 설정 완료
  ```bash
  # 방법 1: AWS CLI configure
  aws configure
  
  # 방법 2: 환경변수
  export AWS_ACCESS_KEY_ID=your-key
  export AWS_SECRET_ACCESS_KEY=your-secret
  ```

### 3. GitHub 설정
- [ ] **GitHub Personal Access Token** 생성
  - Settings → Developer settings → Personal access tokens
  - **필요 권한**: `repo`, `admin:repo_hook`
  - 토큰 형식: `ghp_xxxxxxxxxxxx...`

- [ ] **저장소 관리자 권한** 확인
  - Atlantis를 연결할 저장소에 대한 관리자 권한 필요

### 4. 선택적 준비물
- [ ] **Slack 웹훅 URL** (알림 기능 사용 시)
  - Slack → Apps → Incoming Webhooks
  - 채널 선택 후 웹훅 URL 생성

- [ ] **Infracost API 키** (비용 분석 기능 사용 시)
  - [infracost.io](https://infracost.io) 무료 가입
  - API 키 생성 (`ico-xxxxx...`)

- [ ] **SSL 인증서 ARN** (커스텀 도메인 사용 시)
  - AWS Certificate Manager에서 SSL 인증서 생성

## 🚀 빠른 환경 확인 스크립트

```bash
# 모든 필수 도구 확인
./atlantis-ecs/scripts/check-prerequisites.sh
```

## ⚡ 5분 배포를 위한 최적 설정

### 기존 인프라 활용 (권장)
- **기존 VPC 사용**: EIP 한계 방지 및 배포 시간 단축
- **기존 S3/DynamoDB**: Terraform state 관리 인프라 재사용

### 환경변수 미리 설정
```bash
# StackKit 표준 환경변수
export TF_STACK_REGION="ap-northeast-2"
export TF_STACK_NAME="mycompany"
export ATLANTIS_GITHUB_TOKEN="ghp_xxxxx"
export INFRACOST_API_KEY="ico-xxxxx"
```

## 🔍 문제 해결

### AWS 권한 오류
```bash
# IAM 정책 확인
aws iam list-attached-user-policies --user-name your-username

# 필요 시 AdministratorAccess 연결
aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### GitHub 토큰 권한 오류
- 토큰 권한에 `repo` (전체), `admin:repo_hook` 포함 여부 확인
- Classic token 사용 (Fine-grained 토큰은 지원하지 않음)

### 네트워크 연결 확인
```bash
# AWS API 연결 확인
aws sts get-caller-identity

# GitHub API 연결 확인
curl -H "Authorization: token ghp_xxxxx" \
  https://api.github.com/user
```

## 📋 체크리스트 완료 후

모든 항목이 체크되었다면 [5분 빠른 시작 가이드](./quick-start.md)를 진행하세요.