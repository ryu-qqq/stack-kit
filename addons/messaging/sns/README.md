# SNS Messaging Addon

## 개요

AWS SNS를 위한 enterprise-grade Terraform 모듈입니다. 다양한 프로토콜 지원, 전달 상태 로깅, 모니터링 기능을 포함합니다.

## 버전

- **v1.0.0** - 초기 릴리즈

## 특징

- ✅ **다중 프로토콜 지원** (Email, SMS, SQS, Lambda, HTTP/HTTPS)
- ✅ **FIFO 토픽 지원**
- ✅ **전달 상태 로깅**
- ✅ **KMS 암호화 지원**
- ✅ **CloudWatch 모니터링 및 알람**
- ✅ **IAM 역할 및 정책 자동 생성**
- ✅ **Lambda 권한 자동 설정**
- ✅ **필터 정책 지원**
- ✅ **CloudWatch 대시보드**

## 사용법

### 기본 SNS 토픽

```hcl
module "notifications" {
  source = "./addons/messaging/sns"

  project_name = "myapp"
  environment  = "prod"
  topic_name   = "user-notifications"
  display_name = "User Notifications"

  # 이메일 구독
  subscriptions = [
    {
      protocol = "email"
      endpoint = "admin@company.com"
    },
    {
      protocol = "email"
      endpoint = "alerts@company.com"
      raw_message_delivery = true
    }
  ]

  # 모니터링
  enable_monitoring = true
  monitoring_config = {
    failed_notifications_threshold = 1
    alarm_actions = [aws_sns_topic.alerts.arn]
  }

  common_tags = {
    Team        = "platform"
    Service     = "notifications"
    Environment = "prod"
  }
}
```

### 다중 프로토콜 구독

```hcl
module "multi_protocol_topic" {
  source = "./addons/messaging/sns"

  project_name = "alerts"
  environment  = "prod"
  topic_name   = "system-alerts"

  subscriptions = [
    # 이메일 구독
    {
      protocol = "email"
      endpoint = "oncall@company.com"
    },
    # SMS 구독
    {
      protocol = "sms"
      endpoint = "+821012345678"
    },
    # SQS 구독
    {
      protocol = "sqs"
      endpoint = module.alert_queue.queue_arn
      raw_message_delivery = true
    },
    # Lambda 구독
    {
      protocol = "lambda"
      endpoint = aws_lambda_function.alert_processor.arn
      filter_policy = jsonencode({
        severity = ["high", "critical"]
      })
    },
    # HTTP 엔드포인트
    {
      protocol = "https"
      endpoint = "https://webhook.company.com/alerts"
      raw_message_delivery = false
    }
  ]

  # 전달 상태 로깅
  create_delivery_status_role = true
  create_delivery_status_logs = true

  common_tags = {
    Team = "sre"
  }
}
```

### FIFO 토픽

```hcl
module "order_notifications" {
  source = "./addons/messaging/sns"

  project_name = "ecommerce"
  environment  = "prod"
  topic_name   = "order-events"

  # FIFO 설정
  fifo_topic                  = true
  content_based_deduplication = true

  subscriptions = [
    {
      protocol = "sqs"
      endpoint = module.order_processing_queue.queue_arn
      raw_message_delivery = true
    }
  ]

  # 암호화
  kms_master_key_id = aws_kms_key.sns_encryption.arn

  common_tags = {
    Team = "orders"
  }
}
```

### 필터 정책과 함께

```hcl
module "event_topic" {
  source = "./addons/messaging/sns"

  project_name = "analytics"
  environment  = "prod"
  topic_name   = "user-events"

  subscriptions = [
    # 중요 이벤트만 처리하는 Lambda
    {
      protocol = "lambda"
      endpoint = aws_lambda_function.critical_events.arn
      filter_policy = jsonencode({
        event_type = ["user_signup", "payment_completed"],
        priority   = ["high"]
      })
    },
    # 모든 이벤트를 저장하는 SQS
    {
      protocol = "sqs"
      endpoint = module.events_archive.queue_arn
      raw_message_delivery = true
    }
  ]

  # 대시보드 생성
  create_dashboard = true

  common_tags = {
    Team = "analytics"
  }
}
```

### Cross-Account 퍼블리시

```hcl
module "shared_topic" {
  source = "./addons/messaging/sns"

  project_name = "shared"
  environment  = "prod"  
  topic_name   = "cross-account-events"

  # Cross-account 정책
  topic_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::123456789012:root",
            "arn:aws:iam::234567890123:root"
          ]
        }
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = "*"
      }
    ]
  })

  subscriptions = [
    {
      protocol = "sqs"
      endpoint = module.central_processing.queue_arn
    }
  ]

  common_tags = {
    Purpose = "cross-account-integration"
  }
}
```

## Variables

### 필수 Variables

| Name | Description | Type |
|------|-------------|------|
| `project_name` | 프로젝트 이름 | `string` |
| `environment` | 환경 (dev/staging/prod) | `string` |
| `topic_name` | SNS 토픽 이름 | `string` |

### 선택적 Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `display_name` | 토픽 표시 이름 | `string` | `null` |
| `fifo_topic` | FIFO 토픽 여부 | `bool` | `false` |
| `subscriptions` | 구독 설정 목록 | `list(object)` | `[]` |
| `enable_monitoring` | 모니터링 활성화 | `bool` | `true` |
| `create_iam_role` | IAM 역할 생성 | `bool` | `false` |
| `kms_master_key_id` | KMS 키 ID | `string` | `null` |

전체 변수 목록은 `variables.tf` 파일을 참조하세요.

## Outputs

| Name | Description |
|------|-------------|
| `topic_arn` | SNS 토픽 ARN |
| `topic_name` | SNS 토픽 이름 |
| `subscriptions` | 구독 정보 |
| `iam_role_arn` | IAM 역할 ARN |
| `cloudwatch_alarms` | CloudWatch 알람 정보 |

전체 출력 목록은 `outputs.tf` 파일을 참조하세요.

## 구독 프로토콜

### Email

```hcl
{
  protocol = "email"
  endpoint = "user@example.com"
  raw_message_delivery = false  # HTML 형식
}
```

### SMS

```hcl
{
  protocol = "sms"
  endpoint = "+821012345678"  # E.164 형식
}
```

### SQS

```hcl
{
  protocol = "sqs"
  endpoint = "arn:aws:sqs:region:account:queue-name"
  raw_message_delivery = true  # 메시지 래핑 없이
}
```

### Lambda

```hcl
{
  protocol = "lambda"
  endpoint = "arn:aws:lambda:region:account:function:function-name"
  filter_policy = jsonencode({
    store = ["example_corp"],
    event = ["order-placed", "order-cancelled"]
  })
}
```

### HTTP/HTTPS

```hcl
{
  protocol = "https"
  endpoint = "https://example.com/webhook"
  delivery_policy = jsonencode({
    healthyRetryPolicy = {
      numRetries         = 3
      numNoDelayRetries  = 0
      minDelayTarget     = 20
      maxDelayTarget     = 20
      numMinDelayRetries = 0
      numMaxDelayRetries = 0
      backoffFunction    = "linear"
    }
  })
}
```

## 필터 정책

메시지 속성 기반 필터링:

```json
{
  "event_type": ["order_placed", "order_cancelled"],
  "store": ["example_corp"],
  "price": [{"numeric": [">=", 100]}],
  "customer_type": ["premium"]
}
```

메시지 본문 기반 필터링:

```hcl
{
  protocol = "lambda"
  endpoint = aws_lambda_function.processor.arn
  filter_policy_scope = "MessageBody"
  filter_policy = jsonencode({
    customer = {
      type = ["premium", "gold"]
    }
  })
}
```

## 모니터링

### CloudWatch 알람

자동으로 생성되는 알람:

1. **Failed Notifications**: 전달 실패한 알림
2. **Messages Published** (선택적): 게시된 메시지 수 (낮은 임계값)
3. **High Publish Rate** (선택적): 높은 게시 비율

### CloudWatch 대시보드

`create_dashboard = true`로 설정하면 다음 메트릭을 포함한 대시보드가 생성됩니다:

- NumberOfMessagesPublished
- NumberOfNotificationsDelivered
- NumberOfNotificationsFailed
- NumberOfNotificationsFilteredOut
- 프로토콜별 메시지 분포

## 보안

### 암호화

1. **전송 중 암호화**: 기본적으로 HTTPS 사용
2. **저장 중 암호화**: KMS 키로 메시지 암호화
3. **엔드포인트 암호화**: HTTPS 엔드포인트 강제

### IAM 정책

생성되는 IAM 정책은 최소 권한 원칙을 따릅니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic"
      ],
      "Resource": "arn:aws:sns:region:account:topic-name"
    }
  ]
}
```

## 통합 예제

### SQS와 함께

```hcl
# SQS Queue
module "processing_queue" {
  source = "./addons/messaging/sqs"
  
  project_name = "processing"
  environment  = "prod"
  queue_name   = "order-processing"
}

# SNS Topic
module "order_topic" {
  source = "./addons/messaging/sns"

  project_name = "orders"
  environment  = "prod"
  topic_name   = "order-events"

  subscriptions = [
    {
      protocol = "sqs"
      endpoint = module.processing_queue.queue_arn
      raw_message_delivery = true
    }
  ]
}

# SQS에 SNS 메시지 수신 권한 부여
resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = module.processing_queue.queue_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = module.processing_queue.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.order_topic.topic_arn
          }
        }
      }
    ]
  })
}
```

### Lambda와 함께

```hcl
# Lambda Function
resource "aws_lambda_function" "processor" {
  filename      = "processor.zip"
  function_name = "order-processor"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.9"
}

# SNS Topic with Lambda subscription
module "notifications" {
  source = "./addons/messaging/sns"

  project_name = "orders"
  environment  = "prod"
  topic_name   = "order-notifications"

  subscriptions = [
    {
      protocol = "lambda"
      endpoint = aws_lambda_function.processor.arn
      filter_policy = jsonencode({
        event_type = ["order_placed", "order_shipped"]
      })
    }
  ]
}

# Lambda permission is automatically created by the module
```

## 모범 사례

1. **구독 확인**: 이메일/SMS 구독은 수동 확인 필요
2. **DLQ 사용**: SQS 구독에는 DLQ 설정 권장
3. **필터 정책**: 불필요한 메시지 전달 방지
4. **전달 정책**: HTTP 엔드포인트에 재시도 로직 설정
5. **모니터링**: 실패한 전달에 대한 알람 설정
6. **암호화**: 민감한 데이터는 KMS 암호화 사용
7. **FIFO vs 표준**: 순서가 중요한 경우만 FIFO 사용

## 제한사항

- FIFO 토픽은 SQS FIFO 큐와 Lambda만 지원
- SMS는 일부 지역에서만 지원
- 메시지 크기는 최대 256KB
- 구독당 필터 정책은 최대 5개 속성
- HTTP 엔드포인트는 HTTPS 권장

## 문제 해결

### 이메일 구독이 확인되지 않음

```bash
# 구독 상태 확인
aws sns get-subscription-attributes --subscription-arn <subscription-arn>

# 구독 재확인 요청
aws sns confirm-subscription --topic-arn <topic-arn> --token <token>
```

### Lambda 함수가 호출되지 않음

```bash
# Lambda 권한 확인
aws lambda get-policy --function-name <function-name>

# SNS 구독 상태 확인
aws sns list-subscriptions-by-topic --topic-arn <topic-arn>
```

## 라이센스

MIT License

## 지원

Issues 및 기여는 GitHub 저장소를 통해 환영합니다.