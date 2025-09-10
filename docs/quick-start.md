# 🚀 5분 빠른 시작 가이드

실제 타이머를 재면서 5분 내에 Atlantis 인프라를 구축해보세요!

## ⏰ 5분 타임라인

### 0-1분: 사전 확인
```bash
# 1. 사전 준비 완료 확인
./atlantis-ecs/scripts/check-prerequisites.sh

# 2. 환경변수 설정 (선택사항)
export TF_STACK_NAME="mycompany"
export ATLANTIS_GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"
```

### 1-4분: Atlantis 배포
```bash
# 기본 배포 (모든 인프라 신규 생성)
cd atlantis-ecs
./quick-deploy.sh \
  --org mycompany \
  --github-token ghp_xxxxxxxxxxxxx
```

**또는 기존 VPC 활용 (더 빠름)**:
```bash
./quick-deploy.sh \
  --org mycompany \
  --github-token ghp_xxxxxxxxxxxxx \
  --vpc-id vpc-12345678
```

### 4-5분: 저장소 연결
```bash
# 출력된 Atlantis URL 사용
./connect.sh \
  --atlantis-url https://mycompany-atlantis-alb-xxx.elb.amazonaws.com \
  --repo-name myorg/myrepo \
  --github-token ghp_xxxxxxxxxxxxx
```

## 🎯 시간 단축 팁

### 최대 속도 설정
```bash
# 환경변수로 모든 설정 미리 준비
export TF_STACK_NAME="mycompany"
export TF_STACK_REGION="ap-northeast-2"
export ATLANTIS_GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"
export INFRACOST_API_KEY="ico-xxxxxxxxxxxxx"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/xxx"

# 기존 VPC 사용으로 네트워킹 시간 절약
./quick-deploy.sh --org mycompany --vpc-id vpc-existing
```

### 병렬 처리 활용
```bash
# 백그라운드에서 Terraform 적용하면서 다른 작업 진행
./quick-deploy.sh --org mycompany --github-token ghp_xxx &

# 동시에 문서 준비나 다른 저장소 설정 진행
```

## 📊 실시간 진행률 모니터링

### 진행 상황 확인 방법
```bash
# Terraform 진행률 모니터링
tail -f /tmp/atlantis-deploy.log

# AWS 리소스 생성 확인
aws ecs list-clusters --region ap-northeast-2
aws elbv2 describe-load-balancers --region ap-northeast-2
```

### 각 단계별 예상 시간
- **사전 요구사항 확인**: 10초
- **S3/DynamoDB 설정**: 20초
- **시크릿 저장**: 10초
- **Terraform 설정 생성**: 5초
- **인프라 배포**: 2-3분 (VPC 신규 생성 시 3-4분)
- **출력 확인**: 5초

## 🔧 고급 5분 배포 옵션

### 완전 자동화 배포
```bash
# 모든 기능 활성화된 원스톱 배포
./quick-deploy.sh \
  --org enterprise \
  --github-token ghp_xxx \
  --vpc-id vpc-12345678 \
  --custom-domain atlantis.company.com \
  --certificate-arn arn:aws:acm:region:account:certificate/xxx \
  --infracost-key ico-xxx \
  --slack-webhook https://hooks.slack.com/services/xxx
```

### 대화형 설정 모드
```bash
# 사용자 친화적 설정 마법사
./quick-deploy.sh --interactive
```

## 🚨 5분 내 완료되지 않는 경우

### 일반적인 지연 원인
1. **AWS 권한 문제**: 2-3분 추가 소요
2. **VPC 신규 생성**: 1-2분 추가 소요  
3. **ALB DNS 전파**: 30초-1분 추가 소요
4. **GitHub API 제한**: 10-30초 추가 소요

### 빠른 복구 방법
```bash
# 배포 상태 확인
terraform show -json | jq '.values.root_module.resources[].values.state'

# 실패한 리소스만 재시도
terraform apply -target=aws_ecs_service.atlantis -auto-approve
```

## ✅ 성공 확인

### 1. Atlantis 웹 UI 접속
```bash
# 출력된 URL로 접속 확인
curl -I https://your-atlantis-url.com
```

### 2. GitHub 웹훅 테스트
- 연결된 저장소에서 더미 PR 생성
- `atlantis plan` 댓글 작성
- 결과 확인

### 3. Slack 알림 테스트 (설정한 경우)
- Plan 실행 시 Slack 메시지 수신 확인

## 🔄 다음 단계

5분 배포 완료 후:
1. **[저장소 연결 가이드](./repository-setup.md)** - 여러 저장소 연결
2. **[고급 설정 가이드](./advanced-configuration.md)** - 커스터마이징
3. **[문제 해결 가이드](./troubleshooting.md)** - 일반적인 문제들

## 📈 성능 최적화

### 다음 배포 시 더 빨리 하는 방법
```bash
# 기존 S3/DynamoDB 재사용
./quick-deploy.sh \
  --org newproject \
  --github-token ghp_xxx \
  --state-bucket existing-terraform-state \
  --lock-table existing-terraform-locks
```

### 인프라 재사용으로 1분 배포
```bash
# 기존 Atlantis 인프라에 새 저장소만 연결
./connect.sh \
  --atlantis-url https://existing-atlantis.com \
  --repo-name neworg/newrepo \
  --github-token ghp_xxx
```