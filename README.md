# StackKit v2 - Infrastructure as Code 템플릿 시스템

> 🚀 **즉시 배포 가능한** 엔터프라이즈급 GitOps 인프라 템플릿 시스템

## 개요

StackKit은 한국 DevOps/Platform 엔지니어링 팀을 위한 표준화된 Infrastructure as Code (IaC) 템플릿 시스템입니다. Terraform과 Atlantis를 기반으로 한 GitOps 워크플로우를 제공하며, 비용 분석, 보안 검증, Slack 알림 등 엔터프라이즈급 기능을 포함합니다.

### 🎯 핵심 가치 제안

- **💰 비용 투명성**: 모든 인프라 변경사항에 대한 실시간 비용 분석
- **🛡️ 보안 우선**: 자동화된 보안 검증 및 거버넌스 정책
- **📊 풍부한 알림**: Slack 통합으로 팀 협업 강화
- **⚡ 즉시 배포**: 검증된 템플릿으로 빠른 프로젝트 시작
- **📋 표준화**: 47개 표준 변수와 일관된 명명 규칙

## 주요 구성요소

### 📁 프로젝트 구조

```
stackkit/
├── templates/                      # 인프라 템플릿
│   └── gitops-atlantis/           # 메인 GitOps Atlantis 템플릿
├── tools/                          # StackKit CLI 도구
│   ├── stackkit-cli.sh            # 메인 CLI 도구
│   ├── create-project-infrastructure.sh
│   ├── add-addon.sh               # 애드온 관리
│   └── governance-validator.sh     # 거버넌스 검증
├── addons/                         # 인프라 애드온 모듈
│   ├── database/                  # 데이터베이스 모듈
│   ├── messaging/                 # 메시징 서비스
│   ├── monitoring/                # 모니터링 솔루션
│   └── storage/                   # 스토리지 솔루션
├── shared-infra-infrastructure/    # 구현 예시
├── VARIABLE_STANDARDS.md          # 필수 변수 표준
└── README.md                      # 이 문서
```

### 🏗️ GitOps Atlantis 템플릿

**위치**: `templates/gitops-atlantis/`

엔터프라이즈급 Atlantis 템플릿으로 다음 기능을 제공합니다:

#### 🔍 향상된 분석 기능
- **리소스 변경 분석**: 상세한 plan 분석 및 리소스 개수 추적
- **비용 영향 평가**: Infracost 통합으로 월간 비용 추정
- **보안 검증**: 일반적인 보안 이슈 자동 검사
- **풍부한 리포팅**: 종합적인 로깅 및 디버깅 정보

#### 💬 소통 & 알림
- **Slack 통합**: 구조화된 메시지로 풍부한 알림
- **GitHub 댓글**: 자동 Infracost 비용 분석 댓글
- **상태 업데이트**: 실시간 plan 및 apply 상태 알림
- **에러 리포팅**: 디버깅 컨텍스트가 포함된 상세한 오류 정보

#### 🛡️ 보안 & 거버넌스
- **수동 승인**: 인프라 변경 전 필수 승인 과정
- **브랜치 보호**: 안전한 운영을 위한 웹훅 이벤트 구성
- **시크릿 관리**: 보안 웹훅 시크릿 처리
- **감사 추적**: 인프라 변경사항 완전 추적

## 빠른 시작

### 1. 새 프로젝트 생성

```bash
# StackKit CLI를 사용한 프로젝트 생성
./tools/stackkit-cli.sh new --template gitops-atlantis --name my-project

# 생성된 프로젝트 디렉토리로 이동
cd my-project-infrastructure
```

### 2. 프로젝트 설정

```bash
# terraform.tfvars.example 파일을 복사하여 설정
cp terraform.tfvars.example terraform.tfvars

# 프로젝트별 설정 수정
vim terraform.tfvars
```

### 3. 저장소 연결 (Atlantis)

```bash
# 기본 연결
./scripts/connect.sh \
  --atlantis-url https://atlantis.your-company.com \
  --repo-name your-org/your-project \
  --github-token ghp_your_token

# 전체 기능이 포함된 연결 (Slack + 비용 분석)
./scripts/connect.sh \
  --atlantis-url https://atlantis.your-company.com \
  --repo-name your-org/your-project \
  --github-token ghp_your_token \
  --slack-webhook https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  --infracost-key ico_your_infracost_key \
  --environment prod
```

### 4. GitOps 워크플로우

1. **피처 브랜치 생성**: `git checkout -b feature/your-feature`
2. **인프라 수정**: `.tf` 파일 수정
3. **Pull Request 생성**: Atlantis가 자동으로 `terraform plan` 실행
4. **변경사항 검토**: plan 출력, 비용 분석, 보안 검사 확인
5. **PR 승인**: 팀의 인프라 변경 승인 받기
6. **변경사항 적용**: `atlantis apply` 실행하여 인프라 배포

## 핵심 기능

### 🔧 StackKit CLI 도구

**메인 명령어**: `./tools/stackkit-cli.sh`

```bash
# 새 프로젝트 생성
stackkit-cli.sh new --template gitops-atlantis --name user-api

# 애드온 추가
stackkit-cli.sh addon add database/mysql-rds user-api

# 프로젝트 검증
stackkit-cli.sh validate

# 인프라 배포
stackkit-cli.sh deploy --env dev

# 비용 분석
stackkit-cli.sh cost --env dev
```

### 📦 애드온 시스템

사용 가능한 애드온들:

- **database/**: MySQL RDS, PostgreSQL, DynamoDB
- **messaging/**: SQS, SNS, EventBridge
- **monitoring/**: CloudWatch, X-Ray
- **storage/**: S3, EFS
- **compute/**: Lambda, ECS 추가 구성

```bash
# 애드온 목록 확인
./tools/add-addon.sh list

# 프로젝트에 애드온 추가
./tools/add-addon.sh add database/mysql-rds my-project
```

### 🔒 거버넌스 검증

**12개 카테고리 정책 검증**:
- 보안 (IAM, 암호화, 네트워크)
- 비용 최적화
- 태깅 표준
- 명명 규칙
- 백업 및 재해 복구
- 모니터링 및 로깅

```bash
# 프로젝트 검증
./tools/governance-validator.sh validate --project-dir ./my-project

# HTML 리포트 생성
./tools/governance-validator.sh report --output html --project-dir ./my-project
```

## 표준화

### 📋 변수 표준 (VARIABLE_STANDARDS.md)

StackKit은 **47개 이상의 표준화된 Terraform 변수**를 제공합니다:

- **프로젝트 메타데이터**: `project_name`, `team`, `organization`, `environment`
- **AWS 설정**: `aws_region`, `tags`
- **네트워킹**: `vpc_cidr`, `enable_nat_gateway`
- **ECS**: `ecs_task_cpu`, `ecs_task_memory`, `enable_autoscaling`
- **보안**: `allowed_cidr_blocks`, `secret_recovery_window_days`

### 🎯 명명 규칙

- **snake_case** 사용 (Terraform 표준)
- **prefix 기반 그룹핑** (service_name 형태)  
- **boolean은 enable_/use_ prefix**
- **기존 리소스는 existing_ prefix**

## 실제 구현 예시

**shared-infra-infrastructure/** 디렉토리는 StackKit 템플릿을 사용한 실제 구현 예시입니다:

- Connectly 조직의 플랫폼 팀
- GitOps Atlantis 템플릿 기반
- 개발/스테이징/프로덕션 환경 분리
- Infracost 비용 분석 통합
- Slack 알림 설정

## 고급 사용법

### 환경별 배포

```bash
# 개발 환경
stackkit-cli.sh deploy --env dev --auto-approve

# 스테이징 환경 (수동 승인)
stackkit-cli.sh deploy --env staging

# 프로덕션 환경 (최대 검증)
stackkit-cli.sh deploy --env prod --validate-all
```

### 멀티 프로젝트 관리

```bash
# 여러 프로젝트 동시 검증
for project in user-api order-api payment-api; do
  stackkit-cli.sh validate $project
done

# 의존성 순서로 배포
stackkit-cli.sh deploy-pipeline --projects "shared-infra,user-api,order-api"
```

## 문제 해결

### 일반적인 이슈

1. **웹훅이 트리거되지 않음**
   - 웹훅 URL이 GitHub에서 접근 가능한지 확인
   - 웹훅 시크릿이 GitHub와 Atlantis에서 일치하는지 확인

2. **Plan 실패**
   - AWS 자격 증명 및 권한 확인
   - Terraform 백엔드 설정 검증

3. **비용 분석이 표시되지 않음**
   - `INFRACOST_API_KEY` 설정 확인
   - infracost 바이너리 가용성 확인

4. **Slack 알림이 작동하지 않음**
   - `SLACK_WEBHOOK_URL` 정확성 확인
   - Slack 앱 권한 확인

### 디버그 모드

```bash
# Atlantis 서버 설정에서
ATLANTIS_LOG_LEVEL=debug
TF_LOG=DEBUG
```

