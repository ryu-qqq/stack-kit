# SNS 모듈

AWS SNS (Simple Notification Service) 토픽과 관련 리소스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- SNS 토픽 및 구독 생성 (표준, FIFO)
- 다중 프로토콜 지원 (HTTP/HTTPS, Email, SMS, SQS, Lambda 등)
- 메시지 암호화 (KMS) 지원
- 배달 정책 및 재시도 설정
- 교차 계정 액세스 정책
- 데이터 보호 정책
- 배달 상태 피드백 로깅
- CloudWatch 모니터링 및 알람
- Lambda 함수와의 자동 권한 설정

## 사용법

### 기본 사용 (이메일 알림)

```hcl
module "notification_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "my-app"
  environment  = "dev"
  
  topic_name   = "app-alerts"
  display_name = "Application Alerts"
  
  # 이메일 구독 설정
  subscriptions = [
    {
      protocol = "email"
      endpoint = "admin@example.com"
    },
    {
      protocol = "email"
      endpoint = "dev-team@example.com"
    }
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "alerting"
  }
}
```

### 고급 설정 (다중 프로토콜)

```hcl
module "multi_protocol_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "enterprise-app"
  environment  = "prod"
  
  topic_name   = "critical-alerts"
  display_name = "Critical System Alerts"
  
  # KMS 암호화
  kms_master_key_id = module.kms.key_id
  
  # 다중 구독 설정
  subscriptions = [
    # 이메일 알림
    {
      protocol = "email-json"
      endpoint = "ops-team@company.com"
      raw_message_delivery = false
    },
    # SMS 알림 (긴급시)
    {
      protocol = "sms"
      endpoint = "+1234567890"
    },
    # SQS 큐로 전송
    {
      protocol = "sqs"
      endpoint = module.alert_queue.queue_arn
      raw_message_delivery = true
      filter_policy = jsonencode({
        severity = ["critical", "high"]
      })
    },
    # Lambda 함수 트리거
    {
      protocol = "lambda"
      endpoint = module.alert_processor.function_arn
    },
    # HTTP 웹훅
    {
      protocol = "https"
      endpoint = "https://webhook.company.com/alerts"
      delivery_policy = jsonencode({
        healthyRetryPolicy = {
          minDelayTarget    = 20
          maxDelayTarget    = 20
          numRetries        = 3
          numMaxDelayRetries = 0
          backoffFunction   = "linear"
        }
      })
    }
  ]
  
  # 배달 상태 로깅 활성화
  create_delivery_status_role = true
  create_delivery_status_logs = true
  log_retention_days         = 30
  
  # 피드백 설정
  lambda_success_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  lambda_success_feedback_sample_rate = 100
  lambda_failure_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  
  sqs_success_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  sqs_failure_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  
  http_success_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  http_failure_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  
  # 모니터링 설정
  create_cloudwatch_alarms = true
  alarm_actions = [module.escalation_topic.topic_arn]
  
  common_tags = {
    Project      = "enterprise-app"
    Environment  = "prod"
    Component    = "monitoring"
    CriticalPath = "yes"
  }
}
```

### FIFO 토픽 (순서 보장)

```hcl
module "fifo_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "order-system"
  environment  = "prod"
  
  topic_name   = "order-events.fifo"
  display_name = "Order Processing Events"
  
  # FIFO 설정
  fifo_topic                 = true
  content_based_deduplication = true
  
  # FIFO SQS 구독
  subscriptions = [
    {
      protocol = "sqs"
      endpoint = module.order_queue.queue_arn  # FIFO 큐여야 함
      sqs_parameters = {
        message_group_id = "order-processing"
      }
    }
  ]
  
  # 암호화
  kms_master_key_id = module.order_kms.key_id
  
  common_tags = {
    Project = "order-system"
    Environment = "prod"
    DataType = "transactional"
  }
}
```

### 교차 계정 액세스

```hcl
module "cross_account_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "shared-services"
  environment  = "prod"
  
  topic_name   = "cross-account-alerts"
  display_name = "Cross Account Monitoring"
  
  # 교차 계정 정책
  cross_account_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountSubscribe"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::123456789012:root",  # 다른 계정
            "arn:aws:iam::210987654321:root"
          ]
        }
        Action = [
          "SNS:Subscribe",
          "SNS:Receive"
        ]
        Resource = "*"
      }
    ]
  })
  
  common_tags = {
    Project = "shared-services"
    Environment = "prod"
    Scope = "cross-account"
  }
}
```

### 데이터 보호 정책

```hcl
module "secure_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "compliance-app"
  environment  = "prod"
  
  topic_name   = "secure-notifications"
  display_name = "Secure Notifications"
  
  # 데이터 보호 정책 (PII 감지 및 차단)
  data_protection_policy = jsonencode({
    Name    = "PII-Protection-Policy"
    Version = "2021-06-01"
    Statement = [
      {
        Sid           = "PreventPIIPublishing"
        DataDirection = "Inbound"
        Principal     = ["*"]
        DataIdentifier = [
          "arn:aws:dataprotection::aws:data-identifier/CreditCardNumber",
          "arn:aws:dataprotection::aws:data-identifier/SSN",
          "arn:aws:dataprotection::aws:data-identifier/EmailAddress"
        ]
        Operation = {
          Deny = {}
        }
      }
    ]
  })
  
  # 암호화 필수
  kms_master_key_id = module.compliance_kms.key_id
  
  common_tags = {
    Project = "compliance-app"
    Environment = "prod"
    Compliance = "required"
  }
}
```

### 환경별 설정

```hcl
locals {
  sns_config = {
    dev = {
      create_alarms        = false
      log_retention       = 7
      feedback_sampling   = 10
      encryption_required = false
    }
    staging = {
      create_alarms        = true
      log_retention       = 14
      feedback_sampling   = 50
      encryption_required = true
    }
    prod = {
      create_alarms        = true
      log_retention       = 90
      feedback_sampling   = 100
      encryption_required = true
    }
  }
}

module "environment_topic" {
  source = "../../modules/monitoring/sns"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  topic_name = "app-notifications-${var.environment}"
  
  # 환경별 설정
  create_cloudwatch_alarms = local.sns_config[var.environment].create_alarms
  log_retention_days      = local.sns_config[var.environment].log_retention
  
  # 프로덕션에서만 암호화
  kms_master_key_id = local.sns_config[var.environment].encryption_required ? module.kms[0].key_id : null
  
  # 피드백 샘플링 비율
  lambda_success_feedback_sample_rate = local.sns_config[var.environment].feedback_sampling
  
  subscriptions = var.environment == "prod" ? var.prod_subscriptions : var.dev_subscriptions
  
  common_tags = {
    Project = "adaptive-app"
    Environment = var.environment
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `topic_name` | SNS 토픽 이름 | `string` | - | ✅ |
| `display_name` | SNS 토픽 표시 이름 | `string` | `null` | ❌ |
| `fifo_topic` | FIFO 토픽 여부 | `bool` | `false` | ❌ |
| `content_based_deduplication` | 콘텐츠 기반 중복 제거 (FIFO 토픽만 해당) | `bool` | `false` | ❌ |
| `topic_policy` | SNS 토픽 정책 (JSON) | `string` | `null` | ❌ |
| `delivery_policy` | 배달 정책 (JSON) | `string` | `null` | ❌ |
| `cross_account_policy` | 교차 계정 접근 정책 (JSON) | `string` | `null` | ❌ |
| `data_protection_policy` | 데이터 보호 정책 (JSON) | `string` | `null` | ❌ |
| `kms_master_key_id` | KMS 마스터 키 ID | `string` | `null` | ❌ |
| `subscriptions` | SNS 구독 설정 리스트 | `list(object)` | `[]` | ❌ |
| `create_delivery_status_role` | 배달 상태 로깅용 IAM 역할 생성 여부 | `bool` | `false` | ❌ |
| `create_delivery_status_logs` | 배달 상태 로그 그룹 생성 여부 | `bool` | `false` | ❌ |
| `log_retention_days` | 로그 보존 기간 (일) | `number` | `14` | ❌ |
| `application_success_feedback_role_arn` | 애플리케이션 성공 피드백 IAM 역할 ARN | `string` | `null` | ❌ |
| `lambda_success_feedback_role_arn` | Lambda 성공 피드백 IAM 역할 ARN | `string` | `null` | ❌ |
| `http_success_feedback_role_arn` | HTTP 성공 피드백 IAM 역할 ARN | `string` | `null` | ❌ |
| `sqs_success_feedback_role_arn` | SQS 성공 피드백 IAM 역할 ARN | `string` | `null` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `failed_notifications_alarm_threshold` | 실패한 알림 수 알람 임계값 | `number` | `1` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `topic_id` | SNS 토픽 ID | `string` |
| `topic_arn` | SNS 토픽 ARN | `string` |
| `topic_name` | SNS 토픽 이름 | `string` |
| `topic_display_name` | SNS 토픽 표시 이름 | `string` |
| `topic_owner` | SNS 토픽 소유자 계정 ID | `string` |
| `fifo_topic` | FIFO 토픽 여부 | `bool` |
| `subscription_arns` | 구독 ARN 리스트 | `list(string)` |
| `subscription_details` | 구독 상세 정보 | `list(object)` |
| `delivery_status_role_arn` | 배달 상태 IAM 역할 ARN | `string` |
| `log_group_name` | CloudWatch 로그 그룹 이름 | `string` |
| `failed_notifications_alarm_name` | 실패한 알림 수 알람 이름 | `string` |

## 일반적인 사용 사례

### 1. 애플리케이션 모니터링 알림

```hcl
module "app_monitoring" {
  source = "../../modules/monitoring/sns"
  
  project_name = "web-service"
  environment  = "prod"
  
  topic_name = "app-health-alerts"
  
  subscriptions = [
    {
      protocol = "email"
      endpoint = "devops@company.com"
    },
    {
      protocol = "lambda"
      endpoint = module.alert_processor.function_arn
    }
  ]
  
  # CloudWatch 알람과 연결
  alarm_actions = [module.escalation_topic.topic_arn]
}
```

### 2. 배치 작업 완료 알림

```hcl
module "batch_notifications" {
  source = "../../modules/monitoring/sns"
  
  topic_name = "batch-job-status"
  
  subscriptions = [
    {
      protocol = "sqs"
      endpoint = module.job_status_queue.queue_arn
      filter_policy = jsonencode({
        job_status = ["completed", "failed"]
      })
    }
  ]
}
```

### 3. 보안 이벤트 알림

```hcl
module "security_alerts" {
  source = "../../modules/monitoring/sns"
  
  topic_name = "security-events"
  
  # 암호화 필수
  kms_master_key_id = module.security_kms.key_id
  
  # 즉시 알림 + 로깅
  subscriptions = [
    {
      protocol = "email"
      endpoint = "security-team@company.com"
    },
    {
      protocol = "sqs"
      endpoint = module.security_audit_queue.queue_arn
    }
  ]
  
  # 배달 실패시 에스컬레이션
  alarm_actions = [module.critical_alerts.topic_arn]
}
```

## 모범 사례

### 보안 설정

```hcl
# ✅ 좋은 예: 보안 강화 설정
module "secure_topic" {
  source = "../../modules/monitoring/sns"
  
  # 암호화 활성화
  kms_master_key_id = module.kms.key_id
  
  # 데이터 보호 정책 적용
  data_protection_policy = var.pii_protection_policy
  
  # 접근 제한
  topic_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.authorized_principals
      }
      Action = ["SNS:Publish"]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# ❌ 피해야 할 예: 보안이 약한 설정
# kms_master_key_id = null  # 암호화 비활성화
# topic_policy with "*" principals  # 너무 광범위한 권한
```

### 안정성 및 모니터링

```hcl
module "reliable_topic" {
  source = "../../modules/monitoring/sns"
  
  # 재시도 정책 설정
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget    = 20
        maxDelayTarget    = 20
        numRetries        = 3
        backoffFunction   = "linear"
      }
      disableSubscriptionOverrides = false
    }
  })
  
  # 모니터링 활성화
  create_cloudwatch_alarms = true
  create_delivery_status_logs = true
  
  # 피드백 로깅
  lambda_success_feedback_role_arn = aws_iam_role.sns_feedback.arn
  lambda_failure_feedback_role_arn = aws_iam_role.sns_feedback.arn
}
```

### 비용 최적화

```hcl
# 개발 환경용 비용 최적화 설정
module "cost_optimized_topic" {
  source = "../../modules/monitoring/sns"
  
  # 개발환경에서는 모니터링 최소화
  create_cloudwatch_alarms = var.environment == "prod"
  create_delivery_status_logs = var.environment == "prod"
  
  # 피드백 샘플링 비율 조정
  lambda_success_feedback_sample_rate = var.environment == "prod" ? 100 : 10
  
  # 로그 보존 기간 최소화
  log_retention_days = var.environment == "prod" ? 90 : 7
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "InvalidParameter" (FIFO 토픽 이름)

```hcl
# 해결책: FIFO 토픽은 .fifo로 끝나야 함
module "fifo_topic" {
  source = "../../modules/monitoring/sns"
  
  topic_name = "my-topic.fifo"  # .fifo 필수
  fifo_topic = true
}
```

#### 2. "AuthorizationError" (Lambda 권한 부족)

```hcl
# 해결책: Lambda 함수에 SNS invoke 권한 부여
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.topic.topic_arn
}
```

#### 3. "SubscriptionLimitExceeded"

```hcl
# 해결책: 토픽당 구독 수 제한 (12.5M) 확인
# 필요시 여러 토픽으로 분산
module "primary_topic" {
  source = "../../modules/monitoring/sns"
  topic_name = "primary-notifications"
  # 일부 구독만 설정
}

module "secondary_topic" {
  source = "../../modules/monitoring/sns"
  topic_name = "secondary-notifications"
  # 나머지 구독 설정
}
```

## 제한 사항

- 토픽당 최대 12.5M 구독 가능
- 메시지 크기 최대 256KB
- FIFO 토픽은 초당 3,000개 메시지로 제한 (배치 사용시 30,000개)
- SMS는 지역별 제한 사항 적용
- Cross-region 복제 미지원

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.