# GitHub Actions Setup Guide

이 문서는 Atlantis Terraform CI/CD를 위한 GitHub Actions 설정 방법을 설명합니다.

## 🔧 필요한 설정

### 1. AWS IAM Role for GitHub Actions (OIDC)

GitHub Actions에서 AWS에 접근하기 위한 OIDC 설정이 필요합니다.

#### AWS IAM Identity Provider 생성

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### IAM Role 생성 (trust-policy.json)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID_PLACEHOLDER:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_USER_PLACEHOLDER/REPO_NAME_PLACEHOLDER:*"
        }
      }
    }
  ]
}
```

#### Role 생성 명령

```bash
aws iam create-role \
  --role-name GitHubActionsAtlantisRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name GitHubActionsAtlantisRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### 2. GitHub Repository Secrets

GitHub Repository Settings → Secrets and variables → Actions에서 다음 secret을 추가:

- **AWS_ROLE_ARN**: `arn:aws:iam::ACCOUNT_ID_PLACEHOLDER:role/GitHubActionsAtlantisRole`

### 3. ECR Repository 생성 (선택적)

Docker 이미지를 ECR에 저장하려면:

```bash
aws ecr create-repository \
  --repository-name ORG_NAME_PLACEHOLDER/atlantis \
  --region ap-northeast-2
```

## 🚀 Workflow 설명

### 1. Atlantis-Terraform.yml

- **Trigger**: `gitops-atlantis/` 경로의 변경사항
- **Pull Request**: Terraform plan 실행 및 PR 코멘트 추가
- **Main branch push**: Terraform apply 실행

### 2. Atlantis-Docker-build.yml

- **Trigger**: Manual dispatch 또는 gitops-Atlantis 변경
- **기능**: Atlantis 이미지를 ECR로 복사하여 rate limit 문제 해결

## 📝 사용법

### Pull Request 생성시

1. `gitops-atlantis/` 디렉토리 수정
2. PR 생성
3. 자동으로 `terraform plan` 실행되고 결과가 PR 코멘트로 표시

### Main branch 배포

1. PR을 main branch에 merge
2. 자동으로 `terraform apply` 실행
3. ECS 서비스 상태 확인

### Docker 이미지 빌드 (수동)

1. Actions 탭에서 "Build and Push Atlantis Docker Image" workflow 선택
2. "Run workflow" 클릭하여 수동 실행
3. Atlantis 버전 지정 (예: v0.27.0)

## 🔍 디버깅

### Workflow 실패시 체크사항

1. AWS Role ARN이 올바르게 설정되었는지 확인
2. IAM Role에 필요한 권한이 있는지 확인
3. ECR Repository가 존재하는지 확인
4. Terraform state backend 설정 확인

### 로그 확인

- GitHub Actions의 workflow 실행 로그 확인
- AWS CloudWatch Logs에서 ECS 태스크 로그 확인

## 🎯 다음 단계

1. **GitHub Repository Secrets 설정**
2. **첫 PR 생성하여 workflow 테스트**
3. **Docker 이미지 빌드 workflow 실행**
4. **Atlantis 배포 확인**
