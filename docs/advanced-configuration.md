# 🚀 고급 설정 가이드

StackKit Atlantis의 고급 기능과 커스터마이징 옵션을 다룹니다.

## 🏗️ 아키텍처 커스터마이징

### 기존 인프라 최대 활용

#### VPC 및 네트워킹 재사용
```bash
# 기존 VPC의 모든 서브넷 자동 검색
./quick-deploy.sh \
  --org enterprise \
  --github-token ghp_xxx \
  --vpc-id vpc-12345678

# 특정 서브넷 지정 (세밀한 제어)
./quick-deploy.sh \
  --org enterprise \
  --github-token ghp_xxx \
  --vpc-id vpc-12345678 \
  --public-subnets "subnet-abc123,subnet-def456" \
  --private-subnets "subnet-ghi789,subnet-jkl012"
```

#### 상태 관리 인프라 재사용
```bash
# 기존 S3/DynamoDB 활용으로 비용 절약
./quick-deploy.sh \
  --org enterprise \
  --github-token ghp_xxx \
  --state-bucket existing-terraform-state \
  --lock-table existing-terraform-locks
```

### 성능 최적화 설정

#### ECS 리소스 조정
```hcl
# terraform/prod/variables.tf에서 조정
variable "atlantis_cpu" {
  default = 1024  # 기본값에서 증량
}

variable "atlantis_memory" {
  default = 2048  # 기본값에서 증량
}
```

#### ALB 설정 최적화
```hcl
# 대규모 팀용 설정
variable "alb_idle_timeout" {
  default = 300  # 5분으로 증가
}

variable "health_check_grace_period" {
  default = 300  # 5분으로 증가
}
```

## 🔐 보안 강화

### HTTPS 및 커스텀 도메인
```bash
# 프로덕션 환경용 HTTPS 설정
./quick-deploy.sh \
  --org enterprise \
  --github-token ghp_xxx \
  --custom-domain atlantis.company.com \
  --certificate-arn arn:aws:acm:ap-northeast-2:123456789:certificate/abcd-1234
```

#### SSL 인증서 생성
```bash
# AWS Certificate Manager에서 인증서 요청
aws acm request-certificate \
  --domain-name atlantis.company.com \
  --validation-method DNS \
  --region ap-northeast-2

# 인증서 ARN 확인
aws acm list-certificates \
  --query 'CertificateSummaryList[?DomainName==`atlantis.company.com`].CertificateArn' \
  --output text
```

### WAF 및 보안 그룹 강화
```hcl
# 추가 보안 설정 (terraform/prod/security.tf)
resource "aws_wafv2_web_acl" "atlantis" {
  name  = "${var.org_name}-atlantis-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "atlantis-waf-common"
      sampled_requests_enabled   = true
    }
  }
}
```

## 💰 비용 최적화

### Infracost 고급 설정
```bash
# Infracost 프로젝트별 설정
cat > .infracost.yml << EOF
version: 0.1
projects:
  - path: .
    name: atlantis-infrastructure
    usage_file: infracost-usage.yml
EOF

# 사용량 파일로 정확한 비용 산정
cat > infracost-usage.yml << EOF
version: 0.1
resource_usage:
  aws_ecs_service.atlantis:
    monthly_cpu_hours: 720  # 24/7 운영
    monthly_memory_gb_hours: 1440  # 2GB * 720시간
EOF
```

### 스팟 인스턴스 활용 (개발 환경)
```hcl
# ECS 태스크 정의에서 Fargate Spot 사용
resource "aws_ecs_task_definition" "atlantis" {
  # ... 기본 설정 ...
  
  # 개발 환경에서만 Spot 사용
  requires_compatibilities = ["FARGATE", "FARGATE_SPOT"]
}
```

## 📊 모니터링 및 로깅

### CloudWatch 대시보드
```bash
# 대시보드 생성 스크립트
cat > create-dashboard.sh << 'EOF'
#!/bin/bash
aws cloudwatch put-dashboard \
  --dashboard-name "Atlantis-Monitoring" \
  --dashboard-body file://dashboard.json
EOF

# 대시보드 정의
cat > dashboard.json << 'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "prod-atlantis-service"],
          [".", "MemoryUtilization", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-2",
        "title": "ECS Metrics"
      }
    }
  ]
}
EOF
```

### 알림 설정
```hcl
# CloudWatch 알림
resource "aws_cloudwatch_metric_alarm" "atlantis_cpu_high" {
  alarm_name          = "${var.org_name}-atlantis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors atlantis cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.atlantis.name
  }
}
```

## 🔄 멀티 환경 관리

### 환경별 배포
```bash
# 개발 환경
TF_STACK_NAME="dev-atlantis" \
./quick-deploy.sh \
  --org mycompany-dev \
  --github-token ghp_xxx \
  --environment dev

# 스테이징 환경
TF_STACK_NAME="staging-atlantis" \
./quick-deploy.sh \
  --org mycompany-staging \
  --github-token ghp_xxx \
  --environment staging \
  --vpc-id vpc-staging

# 프로덕션 환경
TF_STACK_NAME="prod-atlantis" \
./quick-deploy.sh \
  --org mycompany \
  --github-token ghp_xxx \
  --environment prod \
  --vpc-id vpc-prod \
  --custom-domain atlantis.company.com \
  --certificate-arn arn:aws:acm:...
```

### 환경별 설정 파일
```bash
# environments/dev.tfvars
atlantis_cpu    = 512
atlantis_memory = 1024
min_capacity    = 1
max_capacity    = 2

# environments/prod.tfvars
atlantis_cpu    = 1024
atlantis_memory = 2048
min_capacity    = 2
max_capacity    = 10
enable_waf      = true
backup_enabled  = true
```

## 🤖 CI/CD 통합

### GitHub Actions 워크플로우
```yaml
# .github/workflows/atlantis-deploy.yml
name: Deploy Atlantis

on:
  push:
    branches: [main]
    paths: ['atlantis-ecs/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.ATLANTIS_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.ATLANTIS_AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.ATLANTIS_REGION }}
      
      - name: Deploy Atlantis
        run: |
          cd atlantis-ecs
          ./quick-deploy.sh \
            --org ${{ vars.ATLANTIS_ORG_NAME }} \
            --github-token ${{ secrets.ATLANTIS_GITHUB_TOKEN }} \
            --environment ${{ vars.ATLANTIS_ENVIRONMENT }} \
            --infracost-key ${{ secrets.INFRACOST_API_KEY }} \
            --slack-webhook ${{ secrets.SLACK_WEBHOOK_URL }}
```

### GitLab CI/CD
```yaml
# .gitlab-ci.yml
deploy-atlantis:
  stage: deploy
  image: hashicorp/terraform:latest
  before_script:
    - apk add --no-cache aws-cli jq curl
  script:
    - cd atlantis-ecs
    - ./quick-deploy.sh 
        --org $ORG_NAME 
        --github-token $GITHUB_TOKEN 
        --environment $CI_ENVIRONMENT_NAME
  only:
    - main
  variables:
    AWS_ACCESS_KEY_ID: $ATLANTIS_AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $ATLANTIS_AWS_SECRET_ACCESS_KEY
```

## 🔧 트러블슈팅 및 유지보수

### 자동 백업 설정
```bash
# 백업 스크립트
cat > scripts/backup-atlantis.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_BUCKET="atlantis-backups-${DATE}"

# Terraform 상태 백업
aws s3 cp s3://${STATE_BUCKET}/atlantis-prod.tfstate \
  s3://${BACKUP_BUCKET}/terraform-state/

# Secrets 백업 (암호화된 상태로)
aws secretsmanager get-secret-value \
  --secret-id prod-atlantis-secrets \
  --query SecretString \
  --output text > secrets-backup-${DATE}.json.enc
EOF
```

### 성능 모니터링 스크립트
```bash
# 성능 체크 스크립트
cat > scripts/performance-check.sh << 'EOF'
#!/bin/bash
echo "🔍 Atlantis 성능 체크"

# ECS 서비스 상태
aws ecs describe-services \
  --cluster prod-atlantis-cluster \
  --services prod-atlantis-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# CloudWatch 메트릭
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=prod-atlantis-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# 응답 시간 테스트
curl -w "@curl-format.txt" -o /dev/null -s "https://your-atlantis-url.com/healthz"
EOF
```

## 📈 스케일링 전략

### 오토 스케일링 설정
```hcl
# Auto Scaling 타겟
resource "aws_appautoscaling_target" "atlantis" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.atlantis.name}/${aws_ecs_service.atlantis.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU 기반 스케일링
resource "aws_appautoscaling_policy" "atlantis_cpu" {
  name               = "${var.org_name}-atlantis-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.atlantis.resource_id
  scalable_dimension = aws_appautoscaling_target.atlantis.scalable_dimension
  service_namespace  = aws_appautoscaling_target.atlantis.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

### 로드 밸런서 최적화
```hcl
# ALB 설정 최적화
resource "aws_lb_target_group" "atlantis" {
  # ... 기본 설정 ...
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    protocol            = "HTTP"
  }
  
  # Connection draining
  deregistration_delay = 30
  
  # Load balancing algorithm
  load_balancing_algorithm_type = "least_outstanding_requests"
}
```

이러한 고급 설정들을 통해 enterprise 급 Atlantis 인프라를 구축하고 운영할 수 있습니다.