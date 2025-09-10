# 🔧 문제 해결 가이드

StackKit 사용 중 발생할 수 있는 일반적인 문제들과 해결 방법을 정리했습니다.

## 🚨 긴급 복구 가이드

### Atlantis 서비스 다운 시
```bash
# 1. ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster prod-atlantis-cluster \
  --services prod-atlantis-service

# 2. 서비스 재시작
aws ecs update-service \
  --cluster prod-atlantis-cluster \
  --service prod-atlantis-service \
  --force-new-deployment

# 3. 로그 확인
aws logs tail /ecs/atlantis --follow
```

### 배포 도중 실패 시
```bash
# 현재 상태 확인
cd atlantis-ecs/prod
terraform state list

# 실패한 리소스 개별 재시도
terraform apply -target=resource_name -auto-approve

# 전체 상태 복구
terraform refresh
terraform plan
terraform apply
```

## 💻 설치 및 배포 문제

### "AWS 권한이 부족합니다" 오류

**증상**: `AccessDenied` 또는 권한 관련 오류
```bash
# 문제 진단
aws sts get-caller-identity
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)

# 해결책 1: AdministratorAccess 정책 연결
aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 해결책 2: 세분화된 권한 확인
cat > minimal-atlantis-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "elasticloadbalancing:*",
                "secretsmanager:*",
                "s3:*",
                "dynamodb:*",
                "cloudwatch:*",
                "logs:*",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
EOF
```

### "GitHub 토큰이 잘못되었습니다" 오류

**증상**: `401 Unauthorized` 또는 토큰 관련 오류
```bash
# 토큰 유효성 확인
curl -H "Authorization: token ghp_your_token" https://api.github.com/user

# 토큰 권한 확인
curl -H "Authorization: token ghp_your_token" \
  https://api.github.com/user/repos | jq '.[0].permissions'
```

**해결책**:
1. 새 Personal Access Token 생성
2. 권한에 `repo` (전체), `admin:repo_hook` 포함 확인
3. Classic token 사용 (Fine-grained는 지원하지 않음)

### "VPC를 찾을 수 없습니다" 오류

**증상**: 지정한 VPC ID가 존재하지 않음
```bash
# VPC 존재 확인
aws ec2 describe-vpcs --vpc-ids vpc-12345678

# 리전 내 모든 VPC 조회
aws ec2 describe-vpcs --query 'Vpcs[].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}'

# 기본 VPC 사용
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
echo "Default VPC: $VPC_ID"
```

### Terraform State 잠금 오류

**증상**: `Error acquiring the state lock`
```bash
# 잠금 상태 확인
aws dynamodb scan --table-name prod-atlantis-lock

# 강제 잠금 해제 (주의: 다른 작업이 실행 중이지 않은 경우에만)
terraform force-unlock LOCK_ID

# DynamoDB 테이블 수동 정리
aws dynamodb delete-item \
  --table-name prod-atlantis-lock \
  --key '{"LockID":{"S":"path/to/state"}}'
```

## 🔐 보안 및 접근 문제

### Atlantis 웹 UI 접속 불가

**증상**: 브라우저에서 Atlantis URL 접속 시 타임아웃
```bash
# ALB 상태 확인
aws elbv2 describe-load-balancers \
  --names prod-atlantis-alb

# 타겟 그룹 헬스 체크 확인
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names prod-atlantis-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=prod-atlantis-*"
```

**해결책**:
1. ALB DNS 전파 대기 (최대 5분)
2. 보안 그룹에서 포트 80/443 인바운드 규칙 확인
3. ECS 서비스 헬스 체크 상태 확인

### GitHub 웹훅이 작동하지 않음

**증상**: PR 생성 시 Atlantis가 반응하지 않음
```bash
# 웹훅 설정 확인
curl -H "Authorization: token ghp_your_token" \
  https://api.github.com/repos/owner/repo/hooks

# 웹훅 전송 로그 확인 (GitHub 웹 UI에서)
# Settings → Webhooks → Recent Deliveries

# Atlantis 로그에서 웹훅 수신 확인
aws logs filter-log-events \
  --log-group-name /ecs/atlantis \
  --filter-pattern "webhook"
```

### Secrets Manager 접근 오류

**증상**: 시크릿을 읽을 수 없음
```bash
# 시크릿 존재 확인
aws secretsmanager describe-secret --secret-id prod-atlantis-secrets

# 시크릿 값 확인
aws secretsmanager get-secret-value --secret-id prod-atlantis-secrets

# ECS 태스크 역할 권한 확인
aws iam get-role-policy \
  --role-name atlantis-task-role \
  --policy-name SecretsManagerAccess
```

## 🔧 성능 및 안정성 문제

### Atlantis 응답 속도 느림

**증상**: Plan/Apply 실행이 오래 걸림
```bash
# ECS 리소스 사용률 확인
aws ecs describe-services \
  --cluster prod-atlantis-cluster \
  --services prod-atlantis-service

# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=prod-atlantis-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**해결책**:
1. ECS 태스크 정의에서 CPU/메모리 증량
2. Terraform 병렬 처리 최적화
3. 대용량 state 파일 분할

### 메모리 부족 오류

**증상**: OOMKilled 또는 메모리 관련 오류
```bash
# 메모리 사용률 모니터링
aws logs filter-log-events \
  --log-group-name /ecs/atlantis \
  --filter-pattern "memory"

# ECS 태스크 정의 업데이트
aws ecs register-task-definition \
  --family atlantis \
  --memory 2048 \
  --cpu 1024
```

## 💰 비용 관련 문제

### Infracost 분석 실패

**증상**: 비용 분석이 실행되지 않음
```bash
# API 키 확인
echo $INFRACOST_API_KEY

# Infracost 서비스 연결 테스트
infracost auth login

# 수동 비용 분석 테스트
infracost breakdown --path .
```

**해결책**:
1. 유효한 API 키 설정 확인
2. Infracost 바이너리 버전 확인
3. 네트워크 연결 상태 확인

### 예상보다 높은 AWS 비용

**증상**: ALB, ECS, CloudWatch 비용이 예상보다 높음
```bash
# 현재 실행 중인 리소스 확인
aws ecs list-services --cluster prod-atlantis-cluster
aws elbv2 describe-load-balancers
aws logs describe-log-groups --log-group-name-prefix "/ecs/atlantis"

# 비용 최적화 스크립트 실행
./scripts/cost-optimization.sh
```

## 🔄 자동 복구 스크립트

### 종합 헬스 체크
```bash
#!/bin/bash
# healthcheck.sh

check_atlantis_health() {
    echo "🏥 Atlantis 헬스 체크 시작..."
    
    # ECS 서비스 상태
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster prod-atlantis-cluster \
        --services prod-atlantis-service \
        --query 'services[0].status' --output text)
    
    echo "ECS 서비스 상태: $SERVICE_STATUS"
    
    # ALB 헬스 체크
    HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups \
            --names prod-atlantis-tg \
            --query 'TargetGroups[0].TargetGroupArn' --output text) \
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])')
    
    echo "헬시한 타겟 수: $HEALTHY_TARGETS"
    
    # 웹 UI 응답 확인
    ATLANTIS_URL=$(terraform output -raw atlantis_url 2>/dev/null)
    if curl -s -o /dev/null -w "%{http_code}" "$ATLANTIS_URL" | grep -q "200"; then
        echo "✅ 웹 UI 정상 응답"
    else
        echo "❌ 웹 UI 응답 없음"
        return 1
    fi
    
    echo "✅ 모든 헬스 체크 통과"
}

# 실행
check_atlantis_health
```

### 자동 복구 스크립트
```bash
#!/bin/bash
# auto-recovery.sh

auto_recover_atlantis() {
    echo "🔧 자동 복구 시작..."
    
    # 1. ECS 서비스 재시작
    aws ecs update-service \
        --cluster prod-atlantis-cluster \
        --service prod-atlantis-service \
        --force-new-deployment
    
    # 2. 5분 대기
    echo "⏳ 서비스 재시작 대기 중 (5분)..."
    sleep 300
    
    # 3. 헬스 체크
    if check_atlantis_health; then
        echo "✅ 자동 복구 성공"
        return 0
    else
        echo "❌ 자동 복구 실패 - 수동 확인 필요"
        return 1
    fi
}
```

## 📞 추가 지원

### 문제 지속 시 확인사항
1. **최신 버전 사용 여부**: `git pull origin main`
2. **AWS 서비스 상태**: [AWS Service Health Dashboard](https://status.aws.amazon.com/)
3. **GitHub 서비스 상태**: [GitHub Status](https://www.githubstatus.com/)

### 로그 수집 및 분석
```bash
# 종합 로그 수집 스크립트
./scripts/collect-logs.sh > atlantis-debug-$(date +%Y%m%d-%H%M%S).log
```

### 커뮤니티 지원
- **Issues**: [GitHub Issues](https://github.com/ryu-qqq/stackkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ryu-qqq/stackkit/discussions)

문제 해결이 되지 않는 경우, 위의 로그 수집 스크립트 결과와 함께 이슈를 등록해주세요.