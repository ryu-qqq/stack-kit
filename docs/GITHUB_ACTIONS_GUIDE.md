# 🚀 StackKit GitHub Actions 워크플로우 가이드

StackKit과 함께 사용할 수 있는 GitHub Actions 워크플로우 템플릿들을 제공합니다. 프로젝트의 요구사항에 맞는 워크플로우를 선택하여 사용하세요.

## 📋 워크플로우 템플릿 목록

### 1. 🔍 Complete Terraform Validation
**파일**: `terraform-validation.yml`  
**용도**: 종합적인 Terraform 검증 (프로덕션 환경 권장)

**포함 기능**:
- ✅ Terraform Format, Validate, Plan 검증
- 🛡️ StackKit 보안 스크립트 실행
- 💰 Infracost 비용 추정
- 📊 PR 코멘트로 상세 결과 제공
- 🎯 변경된 스택만 선택적 검증

**적합한 프로젝트**:
- 프로덕션 환경 관리
- 복잡한 인프라 프로젝트
- 팀 협업이 많은 프로젝트

### 2. 📋 PR Plan & Cost Estimation  
**파일**: `terraform-pr-plan.yml`  
**용도**: PR에서 Plan 실행 및 비용 추정에 특화

**포함 기능**:
- 📋 Terraform Plan 자동 실행
- 💰 상세 비용 분석 및 PR 코멘트
- 📊 스택별 변경사항 요약
- 🔄 PR 업데이트 시 자동 재실행

**적합한 프로젝트**:
- 비용 관리가 중요한 프로젝트
- Plan 결과를 PR에서 상세히 보고 싶은 경우
- 여러 스택을 동시에 관리하는 프로젝트

### 3. ✅ Simple Terraform Check
**파일**: `terraform-simple-validation.yml`  
**용도**: 빠르고 간단한 기본 검증

**포함 기능**:
- 🎨 Terraform Format 검사
- ✅ 기본 구문 검증
- 🚀 빠른 실행 (AWS 연결 불필요)

**적합한 프로젝트**:
- 개발 초기 단계
- 간단한 인프라 프로젝트
- CI 시간을 줄이고 싶은 경우

### 4. 🤖 Atlantis Integration
**파일**: `atlantis-integration.yml`  
**용도**: 중앙 Atlantis 서버와의 연동

**포함 기능**:
- 🔔 Atlantis 서버 상태 확인 및 알림
- 💬 Atlantis 명령어 모니터링
- 🔧 atlantis.yaml 구문 검증
- 📊 PR 업데이트 시 자동 알림

**적합한 프로젝트**:
- 중앙 Atlantis 서버를 사용하는 프로젝트
- 큰 조직에서 여러 프로젝트 관리
- Atlantis 워크플로우 자동화 필요

## 🛠️ 설정 방법

### Step 1: 워크플로우 파일 복사

원하는 워크플로우를 프로젝트의 `.github/workflows/` 디렉토리에 복사:

```bash
# 프로젝트 루트에서 실행
mkdir -p .github/workflows

# 원하는 워크플로우 복사 (예: 종합 검증)
cp path/to/stackkit/.github/workflow-templates/terraform-validation.yml .github/workflows/

# 또는 여러 워크플로우 동시 사용
cp path/to/stackkit/.github/workflow-templates/terraform-pr-plan.yml .github/workflows/
cp path/to/stackkit/.github/workflow-templates/atlantis-integration.yml .github/workflows/
```

### Step 2: Repository Secrets 설정

GitHub 레포지토리 Settings → Secrets and variables → Actions에서 다음 시크릿들을 설정:

#### 필수 Secrets
```bash
# AWS 접근 (방법 1: IAM Role - 권장)
AWS_ROLE_ARN="arn:aws:iam::123456789012:role/GitHubActionsRole"

# AWS 접근 (방법 2: IAM User - 대안)  
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Infracost (비용 추정용)
INFRACOST_API_KEY="ico-xxxxxxxxxxxxxxxx"

# Atlantis (중앙 Atlantis 사용 시)
ATLANTIS_URL="http://your-atlantis-server.com"
```

#### AWS OIDC 설정 (권장)

IAM Role을 사용하는 방법 (더 안전함):

1. **AWS IAM에서 OIDC Provider 생성**:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **GitHub Actions용 IAM Role 생성**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR-ORG/YOUR-REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### Step 3: 프로젝트별 워크플로우 커스터마이징

각 워크플로우 파일에서 프로젝트에 맞게 수정:

```yaml
# terraform-validation.yml 예시
env:
  TF_VERSION: "1.8.5"          # 사용하는 Terraform 버전
  AWS_REGION: "ap-northeast-2"  # AWS 리전
  
on:
  pull_request:
    paths:
      - 'terraform/**/*.tf'      # Terraform 파일 경로 조정
      - 'infrastructure/**/*.tf' # 프로젝트 구조에 맞게 수정
```

## 🎯 사용 시나리오별 권장사항

### 🏢 대기업/팀 프로젝트
```yaml
# 추천 조합
workflows:
  - terraform-validation.yml      # 종합 검증
  - terraform-pr-plan.yml         # 상세 Plan & 비용
  - atlantis-integration.yml      # 중앙 Atlantis 연동
```

**장점**:
- 완전한 검증 및 비용 관리
- 팀 협업에 최적화
- 중앙 집중식 관리

### 🚀 스타트업/소규모 팀
```yaml
# 추천 조합  
workflows:
  - terraform-simple-validation.yml  # 빠른 기본 검증
  - terraform-pr-plan.yml            # 비용 추정
```

**장점**:
- 빠른 CI/CD
- 비용 효율적
- 간단한 설정

### 🧪 개발/실험 프로젝트
```yaml
# 추천 조합
workflows:
  - terraform-simple-validation.yml  # 기본 검증만
```

**장점**:
- 최소한의 오버헤드
- 빠른 피드백
- 간단한 유지보수

## 🔧 고급 설정

### 조건부 실행

특정 조건에서만 워크플로우 실행:

```yaml
# 특정 브랜치에서만 실행
on:
  pull_request:
    branches: [main, develop, staging]
    
# 특정 파일 변경 시에만 실행
on:
  pull_request:
    paths:
      - 'terraform/environments/prod/**'  # prod 환경만
      - '!terraform/environments/dev/**'   # dev 환경 제외
```

### 병렬 실행 제어

```yaml
# 동시 실행 제한
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: true
```

### 캐시 설정

```yaml
# Terraform 캐시
- name: Cache Terraform
  uses: actions/cache@v3
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-${{ runner.os }}-${{ hashFiles('**/.terraform.lock.hcl') }}
```

### 알림 설정

```yaml
# Slack 알림 추가
- name: Slack 알림
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔍 문제 해결

### 자주 발생하는 문제들

#### 1. AWS 자격증명 오류
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**해결책**:
- AWS 자격증명 확인
- S3 버킷 존재 확인
- IAM 권한 확인

#### 2. Terraform 백엔드 오류
```
Error: Backend configuration changed
```

**해결책**:
```yaml
# 워크플로우에서 백엔드 재초기화
- name: Terraform Init
  run: terraform init -reconfigure -backend-config=backend.hcl
```

#### 3. Infracost API 제한
```
Error: Infracost API request failed
```

**해결책**:
- Infracost API 키 확인
- API 사용량 제한 확인
- 조건부로 Infracost 실행:

```yaml
- name: Cost Estimation
  if: env.INFRACOST_API_KEY != ''
  run: infracost breakdown --path .
```

#### 4. 워크플로우 권한 오류
```
Error: Resource not accessible by integration
```

**해결책**:
```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```

### 로그 확인 방법

GitHub Actions 로그에서 다음 섹션들을 확인:

1. **Setup** 단계: 도구 설치 및 환경 설정
2. **Detection** 단계: 변경된 파일 감지
3. **Validation** 단계: Terraform 검증 결과
4. **Cost** 단계: 비용 추정 결과
5. **Comment** 단계: PR 코멘트 생성

## 📊 모니터링 및 메트릭

### GitHub Actions 사용 현황

```bash
# Actions 사용 시간 확인
gh api repos/:owner/:repo/actions/billing/usage

# 워크플로우 실행 이력
gh run list --limit 50
```

### 비용 최적화 팁

1. **조건부 실행**: 불필요한 실행 줄이기
2. **캐시 활용**: 반복 다운로드 방지
3. **병렬 처리**: Matrix 전략으로 시간 단축
4. **Self-hosted Runner**: 큰 조직의 경우 고려

## 🔗 관련 문서

- [StackKit 메인 문서](../README.md)
- [중앙 Atlantis 설정 가이드](../ATLANTIS_SETUP.md) 
- [Terraform 모듈 사용법](../terraform/modules/README.md)
- [GitHub Actions 공식 문서](https://docs.github.com/actions)
- [Infracost 문서](https://www.infracost.io/docs/)

---

💡 **팁**: 처음에는 간단한 워크플로우부터 시작해서 점진적으로 기능을 추가하는 것을 권장합니다!