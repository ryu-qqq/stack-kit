# StackKit v2 마이그레이션 가이드

## 🎯 마이그레이션 개요

이 가이드는 기존 StackKit v1 구조에서 새로운 v2 아키텍처로의 단계적 전환을 위한 상세한 로드맵을 제공합니다.

### 🔄 변경 사항 요약

| 구분 | v1 (현재) | v2 (목표) |
|------|-----------|-----------|
| **아키텍처** | Monolithic | Template + Registry |
| **모듈 관리** | 단일 저장소 | 태그 기반 버전 관리 |
| **프로젝트 시작** | 수동 복사 | GitHub Template |
| **모듈 분류** | 단일 구조 | 3-Tier (Foundation/Enterprise/Community) |
| **의존성 관리** | 로컬 참조 | 원격 레지스트리 |

---

## 📅 마이그레이션 타임라인

### Phase 1: 즉시 적용 (1주) ✅ 진행중
- [x] 새로운 CLI 도구 개발 (stackkit-v2-cli.sh)
- [x] API Service 템플릿 생성
- [x] 마이그레이션 도구 개발
- [x] 현재 모듈 태깅 시스템 준비

### Phase 2: 기반 구축 (2주)
- [ ] 모듈 버전 태깅 시작
- [ ] 추가 템플릿 생성 (web-application, serverless)
- [ ] CI/CD 워크플로우 테스트
- [ ] 문서화 완료

### Phase 3: 점진적 전환 (3주)
- [ ] 파일럿 프로젝트 마이그레이션
- [ ] 피드백 수집 및 개선
- [ ] 팀 교육 및 온보딩
- [ ] 프로덕션 환경 테스트

### Phase 4: 완전 전환 (2주)
- [ ] 전체 프로젝트 마이그레이션
- [ ] 레거시 지원 종료 계획
- [ ] 모니터링 및 안정화

---

## 🚀 즉시 시작 가능한 개선사항

### 1. 모듈 버전 태깅 시작

```bash
cd /Users/sangwon-ryu/stackkit

# 현재 주요 모듈들에 초기 태그 생성
git tag stackkit-terraform/modules/networking/vpc/v1.0.0
git tag stackkit-terraform/modules/compute/ecs/v1.0.0
git tag stackkit-terraform/modules/database/rds/v1.0.0
git tag stackkit-terraform/modules/security/iam/v1.0.0

# 태그를 원격에 푸시
git push origin --tags
```

### 2. 새로운 CLI 도구 테스트

```bash
# 새 CLI 도구 사용해보기
./tools/stackkit-v2-cli.sh --help

# 사용 가능한 템플릿 확인
./tools/stackkit-v2-cli.sh templates list

# 프로젝트 검증 기능 테스트
./tools/stackkit-v2-cli.sh validate
```

### 3. 기존 도구 개선

```bash
# create-project-infrastructure.sh에 v2 호환 기능 추가
# - 템플릿 선택 옵션
# - 모듈 버전 지정 옵션
# - 기존 VPC 검색 기능
```

---

## 📋 단계별 마이그레이션 가이드

### Stage 1: 준비 단계 (기존 프로젝트 유지)

#### 1.1 현재 환경 백업
```bash
# 기존 프로젝트 백업
cp -r my-existing-project my-existing-project-backup-$(date +%Y%m%d)

# 현재 상태 문서화
cd my-existing-project
terraform show > current-state-$(date +%Y%m%d).txt
```

#### 1.2 의존성 분석
```bash
# 현재 사용 중인 모듈 분석
grep -r "source.*=" . | grep -v ".terraform"

# 사용 중인 리소스 목록
terraform state list > resources-$(date +%Y%m%d).txt
```

#### 1.3 v2 호환성 검사
```bash
# 마이그레이션 도구로 dry-run 실행
../stackkit/tools/migrate-to-v2.sh \
  --project-dir ./my-existing-project \
  --dry-run \
  --template api-service
```

### Stage 2: 병렬 환경 구축

#### 2.1 새로운 v2 프로젝트 생성
```bash
# v2 템플릿으로 새 프로젝트 생성
../stackkit/tools/stackkit-v2-cli.sh new \
  --template api-service \
  --name my-project-v2 \
  --team backend \
  --org mycompany
```

#### 2.2 설정 이전
```bash
cd my-project-v2-infrastructure

# 기존 설정 값 복사
# 1. terraform.tfvars 값들
# 2. 환경 변수
# 3. 시크릿 정보
```

#### 2.3 단계적 배포 테스트
```bash
# 개발 환경에서 먼저 테스트
cd environments/dev
terraform init
terraform plan
# 리뷰 후 apply
terraform apply
```

### Stage 3: 프로덕션 마이그레이션

#### 3.1 State 마이그레이션 (옵션)
```bash
# 기존 리소스 import (필요한 경우)
terraform import module.vpc.aws_vpc.main vpc-existing-id
terraform import module.ecs_service.aws_ecs_service.main my-service

# 또는 새로 생성 후 DNS 전환
```

#### 3.2 점진적 트래픽 전환
```bash
# 1. 새 환경을 스테이징으로 배포
# 2. 트래픽 일부를 새 환경으로 라우팅
# 3. 모니터링 및 검증
# 4. 전체 트래픽 전환
# 5. 기존 환경 정리
```

---

## 🛠️ 마이그레이션 도구 사용법

### 자동 마이그레이션 도구

```bash
# 기본 마이그레이션 (백업 포함)
./tools/migrate-to-v2.sh --project-dir ./my-legacy-project

# Dry-run으로 사전 확인
./tools/migrate-to-v2.sh \
  --project-dir ./my-legacy-project \
  --dry-run

# 특정 템플릿으로 강제 마이그레이션
./tools/migrate-to-v2.sh \
  --project-dir ./my-legacy-project \
  --template api-service \
  --force
```

### 수동 마이그레이션 체크리스트

#### ✅ 사전 준비
- [ ] 프로젝트 백업 완료
- [ ] 현재 상태 문서화
- [ ] 팀 공지 및 일정 조율
- [ ] 롤백 계획 수립

#### ✅ 구조 변경
- [ ] 새 디렉토리 구조 생성
- [ ] 환경별 설정 분리
- [ ] 모듈 참조 업데이트
- [ ] CI/CD 파이프라인 설정

#### ✅ 테스트 및 검증
- [ ] Terraform 문법 검증
- [ ] 개발 환경 배포 테스트
- [ ] 보안 스캔 통과
- [ ] 비용 분석 검토

#### ✅ 프로덕션 적용
- [ ] 스테이징 환경 배포
- [ ] 프로덕션 배포
- [ ] 모니터링 설정
- [ ] 문서 업데이트

---

## 🔧 환경별 마이그레이션 전략

### 개발 환경 (Dev)
**전략**: 새로 생성하여 즉시 전환
```bash
# 1. 새 v2 프로젝트 생성
# 2. 기존 설정 복사
# 3. 새 환경 배포
# 4. 기존 환경 정리
```

### 스테이징 환경 (Staging)
**전략**: 점진적 전환
```bash
# 1. v2 환경을 staging-v2로 배포
# 2. 테스트 및 검증
# 3. DNS 전환
# 4. 기존 staging 정리
```

### 프로덕션 환경 (Prod)
**전략**: Blue-Green 배포
```bash
# 1. Green 환경으로 v2 배포
# 2. 트래픽 점진적 전환 (10% → 50% → 100%)
# 3. 모니터링 및 안정화
# 4. Blue 환경 정리
```

---

## 📊 리스크 관리 및 롤백 계획

### 🚨 주요 리스크

| 리스크 | 확률 | 영향도 | 완화 방안 |
|--------|------|---------|-----------|
| **State 손실** | 낮음 | 높음 | 백업 필수, 검증된 도구 사용 |
| **모듈 호환성** | 중간 | 중간 | 사전 테스트, 점진적 적용 |
| **CI/CD 중단** | 중간 | 중간 | 병렬 파이프라인 운영 |
| **팀 적응** | 높음 | 낮음 | 교육 및 문서화 강화 |

### 🔄 롤백 절차

#### 즉시 롤백 (5분 내)
```bash
# DNS 레벨 롤백
# 기존 환경으로 트래픽 전환
aws route53 change-resource-record-sets --hosted-zone-id Z123 --change-batch file://rollback.json
```

#### 부분 롤백 (30분 내)
```bash
# 백업에서 특정 환경 복원
cp -r my-project-backup-20240911/* ./
cd environments/prod
terraform apply -auto-approve
```

#### 전체 롤백 (2시간 내)
```bash
# 완전히 이전 상태로 복원
rm -rf my-project-v2-infrastructure
cp -r my-project-backup-20240911 my-project
# 기존 CI/CD 파이프라인 재활성화
```

---

## 🎓 팀 교육 및 온보딩

### 교육 프로그램

#### 1주차: v2 아키텍처 이해
- [ ] Template + Registry 개념
- [ ] 3-Tier 모듈 분류
- [ ] 새로운 도구 사용법

#### 2주차: 실습 및 마이그레이션
- [ ] 개발 환경 마이그레이션 실습
- [ ] CI/CD 파이프라인 설정
- [ ] 트러블슈팅 가이드

#### 3주차: 고급 기능 및 최적화
- [ ] Enterprise 모듈 활용
- [ ] 비용 최적화 전략
- [ ] 모니터링 및 알림 설정

### 필수 문서

- [ ] **Quick Start Guide**: 5분 내 시작하기
- [ ] **Migration Checklist**: 단계별 체크리스트
- [ ] **Troubleshooting Guide**: 일반적인 문제 해결
- [ ] **Best Practices**: 권장 사용 패턴

---

## 📈 성공 지표 및 모니터링

### 🎯 목표 지표

| 지표 | 현재 | 목표 | 측정 방법 |
|------|------|------|-----------|
| **프로젝트 시작 시간** | 60분 | 5분 | 타이머로 측정 |
| **모듈 업데이트 시간** | 30분 | 2분 | 자동화 스크립트 |
| **에러율** | 25% | 5% | 배포 성공률 추적 |
| **개발자 만족도** | - | 80%+ | 월간 설문조사 |

### 📊 모니터링 대시보드

```bash
# 사용 현황 추적
echo "StackKit v2 Usage Statistics" > usage-stats.txt
echo "================================" >> usage-stats.txt
echo "New projects created: $(find . -name "*-infrastructure" | wc -l)" >> usage-stats.txt
echo "V2 migrations completed: $(grep -r "stackkit-v2" . | wc -l)" >> usage-stats.txt
echo "Active templates: $(ls templates/ | wc -l)" >> usage-stats.txt
```

---

## 🔮 향후 계획

### Q4 2024: 안정화 및 최적화
- [ ] 사용자 피드백 반영
- [ ] 성능 최적화
- [ ] 추가 템플릿 개발
- [ ] Enterprise 기능 강화

### Q1 2025: 확장 및 개선
- [ ] 다중 클라우드 지원
- [ ] 고급 거버넌스 기능
- [ ] 써드파티 통합 확대
- [ ] 커뮤니티 기여 프로그램

### 지속적 개선
- [ ] **월간 리뷰**: 사용 패턴 분석 및 개선점 도출
- [ ] **분기 업데이트**: 새로운 모듈 및 기능 추가
- [ ] **연간 아키텍처 리뷰**: 전체 구조 최적화

---

## 📞 지원 및 문의

### 즉시 지원
- **Slack**: #stackkit-support
- **이메일**: devops-team@company.com
- **문서**: [StackKit v2 Documentation](./stackkit-restructure-plan.md)

### 정기 미팅
- **주간 오피스 아워**: 매주 목요일 2-3PM
- **월간 사용자 그룹**: 매월 첫째 주 금요일
- **분기 로드맵 리뷰**: 분기 마지막 주

---

**최종 업데이트**: 2024-09-11  
**문서 버전**: v2.0.0  
**작성자**: StackKit Team