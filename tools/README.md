# StackKit Tools

> 인프라 관리를 위한 핵심 도구 모음

## 📋 도구 목록

### 🚀 stackkit-cli.sh
**주요 CLI 도구** - 프로젝트 생성, 애드온 관리, 배포 자동화

```bash
# 새 프로젝트 생성
./stackkit-cli.sh new --template gitops-atlantis --name my-project

# 애드온 관리
./stackkit-cli.sh addon add database/mysql-rds my-project

# 프로젝트 검증
./stackkit-cli.sh validate

# 인프라 배포
./stackkit-cli.sh deploy --env dev
```

**주요 기능**:
- 템플릿 기반 프로젝트 생성
- 애드온 시스템 통합
- 모듈 버전 관리
- 배포 자동화
- 비용 분석

---

### 🏗️ create-project-infrastructure.sh
**프로젝트 인프라 생성 도구** - 표준화된 프로젝트 구조 생성

```bash
# 기본 프로젝트 생성
./create-project-infrastructure.sh --project my-api --team backend

# 공유 인프라 참조
./create-project-infrastructure.sh --project my-api --use-shared-vpc

# 거버넌스 정책 포함
./create-project-infrastructure.sh --project my-api --copy-governance
```

**주요 기능**:
- 표준화된 디렉토리 구조 생성
- 환경별 설정 (dev/staging/prod)
- GitHub Actions CI/CD 템플릿
- Atlantis GitOps 설정
- 거버넌스 정책 복사

---

### 🔧 add-addon.sh
**애드온 관리 도구** - 프로젝트에 애드온 추가/제거

```bash
# 애드온 목록 확인
./add-addon.sh list

# 애드온 정보 확인
./add-addon.sh info database/mysql-rds

# 프로젝트에 애드온 추가
./add-addon.sh add database/mysql-rds my-project

# 애드온 제거
./add-addon.sh remove database/mysql-rds my-project

# 프로젝트 검증
./add-addon.sh validate my-project
```

**주요 기능**:
- 애드온 탐색 및 정보 확인
- 스마트 애드온 통합
- 환경별 설정 자동 적용
- 충돌 감지 및 해결
- 백업 및 롤백

---

### 🔒 governance-validator.sh
**거버넌스 검증 도구** - 인프라 코드 정책 준수 검증

```bash
# 프로젝트 검증
./governance-validator.sh validate --project-dir ./my-project

# 특정 정책 검증
./governance-validator.sh validate --policy security --project-dir ./my-project

# 검증 리포트 생성
./governance-validator.sh report --output html --project-dir ./my-project
```

**주요 기능**:
- 12개 카테고리 거버넌스 검증
  - 보안 (IAM, 암호화, 네트워크)
  - 비용 최적화
  - 태깅 표준
  - 명명 규칙
  - 백업 및 재해 복구
  - 모니터링 및 로깅
  - 네트워킹 표준
  - 고가용성
  - 컴플라이언스
  - 문서화
  - 모듈 버전 관리
  - 환경 분리
- HTML/JSON 리포트 생성
- CI/CD 통합 가능

---

## 🔄 워크플로우

### 일반적인 프로젝트 생성 흐름

```bash
# 1. CLI로 새 프로젝트 생성
./stackkit-cli.sh new --template api-service --name user-api

# 2. 프로젝트 디렉토리로 이동
cd user-api-infrastructure

# 3. 필요한 애드온 추가
../tools/add-addon.sh add database/mysql-rds .
../tools/add-addon.sh add messaging/sqs .
../tools/add-addon.sh add monitoring/cloudwatch .

# 4. 거버넌스 검증
../tools/governance-validator.sh validate --project-dir .

# 5. 개발 환경 배포
../tools/stackkit-cli.sh deploy --env dev
```

### GitOps 설정 흐름

```bash
# 1. Atlantis 템플릿으로 시작
cp -r templates/gitops-atlantis my-atlantis

# 2. 설정 수정
cd my-atlantis/environments/shared
vim terraform.tfvars

# 3. 배포
terraform init
terraform apply

# 4. GitHub webhook 설정
# GitHub 저장소 설정에서 webhook 추가
```

---

## 🛠️ 도구 간 통합

- **stackkit-cli.sh**: 메인 진입점, 다른 도구들을 내부적으로 호출
- **create-project-infrastructure.sh**: 프로젝트 초기 구조 생성
- **add-addon.sh**: 애드온 시스템 관리
- **governance-validator.sh**: 모든 단계에서 정책 검증

---

## 📝 개발 가이드

### 새 도구 추가 시
1. `tools/` 디렉토리에 실행 가능한 스크립트 추가
2. 일관된 색상 코드 및 로깅 함수 사용
3. `--help` 옵션 필수 구현
4. 에러 처리 및 롤백 메커니즘 포함
5. 이 README에 문서 추가

### 코딩 규칙
- Bash strict mode 사용: `set -euo pipefail`
- 함수형 프로그래밍 스타일 선호
- 명확한 변수명 사용
- 충분한 주석 작성
- 컬러 출력으로 가독성 향상

---

## 🔮 향후 계획

- [ ] Interactive 모드 추가 (대화형 프로젝트 생성)
- [ ] 자동 백업 및 복원 기능
- [ ] 멀티 클라우드 지원 (Azure, GCP)
- [ ] 웹 UI 대시보드
- [ ] 플러그인 시스템

---

**Version**: 1.0.0  
**Last Updated**: 2024-09-11  
**Maintained By**: StackKit Team