# 🔐 AWS OIDC 설정 가이드

GitHub Actions에서 AWS OIDC를 사용하여 안전하게 인증하는 방법입니다.

## 🎯 왜 OIDC를 사용해야 하나요?

### ❌ 기존 방식 (Access Key)의 문제점
- AWS Access Key가 GitHub Secrets에 평문 저장
- 키 순환(rotation)이 어려움
- 키 유출 시 보안 위험

### ✅ OIDC 방식의 장점
- AWS 자격 증명이 GitHub에 저장되지 않음
- 임시 토큰 사용으로 보안성 향상
- 세밀한 권한 제어 가능

## 🏗️ AWS OIDC Identity Provider 설정

### 1단계: OIDC Identity Provider 생성

```bash
# AWS CLI로 OIDC Provider 생성
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com
```

또는 AWS 콘솔에서:

1. **IAM** → **Identity providers** → **Create provider**
2. **Provider type**: OpenID Connect
3. **Provider URL**: `https://token.actions.githubusercontent.com`
4. **Audience**: `sts.amazonaws.com`
5. **Thumbprint**: `6938fd4d98bab03faadb97b34396831e3780aea1`

### 2단계: IAM 역할 생성

다음 내용으로 `trust-policy.json` 파일을 생성:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

**중요**: `YOUR_ACCOUNT_ID`, `YOUR_GITHUB_ORG`, `YOUR_REPO`를 실제 값으로 변경하세요.

### 3단계: IAM 역할 생성 및 정책 연결

```bash
# 1. IAM 역할 생성
aws iam create-role \
  --role-name GitHubActions-StackKit-Atlantis \
  --assume-role-policy-document file://trust-policy.json \
  --description "GitHub Actions role for StackKit Atlantis deployment"

# 2. 필요한 권한 정책 연결
aws iam attach-role-policy \
  --role-name GitHubActions-StackKit-Atlantis \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. 역할 ARN 확인 (이 값을 GitHub Secret에 저장)
aws iam get-role \
  --role-name GitHubActions-StackKit-Atlantis \
  --query 'Role.Arn' \
  --output text
```

## 🎯 실제 설정 예제

### 계정 ID: 123456789012, 조직: mycompany, 저장소: mycompany-atlantis

**trust-policy.json**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:mycompany/mycompany-atlantis:*"
        }
      }
    }
  ]
}
```

**생성된 역할 ARN**: 
```
arn:aws:iam::123456789012:role/GitHubActions-StackKit-Atlantis
```

## 🔑 GitHub Secrets 설정

저장소의 Settings → Secrets and variables → Actions에서 다음 secrets를 설정:

```bash
# AWS OIDC 역할 ARN (위에서 생성한 역할)
AWS_OIDC_ROLE_ARN="arn:aws:iam::123456789012:role/GitHubActions-StackKit-Atlantis"

# OpenAI API 키
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Slack 웹훅 URL
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"

# GitHub Personal Access Token (Atlantis가 GitHub API 호출용)
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## 📋 GITHUB_TOKEN 사용 용도

**GITHUB_TOKEN**은 다음 두 곳에서 사용됩니다:

### 1. Atlantis 서버 설정
- Atlantis가 GitHub API를 호출하여 PR 상태 확인
- PR에 계획 결과 코멘트 작성
- 저장소 클론 및 웹훅 이벤트 처리

### 2. GitHub Webhook 자동 설정
- 배포 완료 후 GitHub API를 통해 자동으로 웹훅 생성
- Atlantis URL을 webhook endpoint로 등록

**필요한 권한**:
- `repo` (full control) - 저장소 접근 및 PR 관리
- `admin:repo_hook` - 웹훅 생성 및 관리

## 🔍 문제 해결

### 오류: "AssumeRoleFailure"

**원인**: Trust policy의 조건이 맞지 않음

**해결**:
1. `YOUR_ACCOUNT_ID`, `YOUR_GITHUB_ORG`, `YOUR_REPO` 값 확인
2. 저장소 이름과 조직명이 정확한지 확인

### 오류: "OIDC provider not found"

**원인**: Identity Provider가 생성되지 않음

**해결**:
```bash
# Identity Provider 존재 확인
aws iam list-open-id-connect-providers

# 없다면 다시 생성
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com
```

### 오류: "GitHub API rate limit"

**원인**: GITHUB_TOKEN의 권한 부족

**해결**:
1. GitHub Settings → Developer settings → Personal access tokens
2. 새 토큰 생성 시 `repo`, `admin:repo_hook` 권한 선택

## 🚀 배포 테스트

모든 설정이 완료되면:

1. 저장소에 코드 푸시
2. GitHub Actions 실행 확인
3. AWS CloudTrail에서 OIDC 인증 로그 확인:
   ```bash
   aws logs filter-log-events \
     --log-group-name CloudTrail/GitHubActions \
     --start-time $(date -d '1 hour ago' +%s)000
   ```

## 📚 참고 자료

- [GitHub OIDC 공식 문서](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS OIDC Identity Provider 가이드](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)