# SQS Messaging Addon

## 개요

AWS SQS를 위한 enterprise-grade Terraform 모듈입니다. 표준 큐와 FIFO 큐를 지원하며, DLQ, 모니터링, 보안 기능을 포함합니다.

## 버전

- **v1.0.0** - 초기 릴리즈

## 특징

- ✅ **표준 및 FIFO 큐 지원**
- ✅ **Dead Letter Queue (DLQ) 자동 구성**
- ✅ **KMS 암호화 지원**
- ✅ **CloudWatch 모니터링 및 알람**
- ✅ **Lambda 트리거 통합**
- ✅ **IAM 역할 및 정책 자동 생성**
- ✅ **Cross-account 액세스 정책**
- ✅ **CloudWatch 대시보드**

## 사용법

### 기본 SQS 큐

```hcl
module "api_queue" {
  source = "./addons/messaging/sqs"

  project_name = "myapp"
  environment  = "prod"
  queue_name   = "api-processing"

  # 기본 설정
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600  # 14 days
  
  # DLQ 활성화
  enable_dlq        = true
  max_receive_count = 3

  # 모니터링
  enable_monitoring = true
  monitoring_config = {
    visible_messages_threshold   = 100
    oldest_message_age_threshold = 300
    alarm_actions               = [aws_sns_topic.alerts.arn]
  }

  common_tags = {
    Team        = "backend"
    Service     = "api"
    Environment = "prod"
  }
}
```

### FIFO 큐

```hcl
module "order_queue" {
  source = "./addons/messaging/sqs"

  project_name = "ecommerce"
  environment  = "prod"
  queue_name   = "order-processing"

  # FIFO 설정
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope        = "messageGroup"
  fifo_throughput_limit      = "perMessageGroupId"

  # DLQ (FIFO)
  enable_dlq        = true
  max_receive_count = 5

  # 암호화
  kms_master_key_id = aws_kms_key.queue_encryption.arn

  common_tags = {
    Team    = "orders"
    Service = "ecommerce"
  }
}
```

### Lambda 트리거와 함께

```hcl
module "event_queue" {
  source = "./addons/messaging/sqs"

  project_name = "analytics"
  environment  = "prod"
  queue_name   = "events"

  # Lambda 트리거
  lambda_trigger = {
    function_name = aws_lambda_function.event_processor.function_name
    batch_size    = 10
    enabled       = true
    scaling_config = {
      maximum_concurrency = 100
    }
  }

  # IAM 역할 생성
  create_iam_role = true
  iam_role_principals = ["lambda.amazonaws.com"]

  common_tags = {
    Team = "analytics"
  }
}
```

### Cross-Account 액세스

```hcl
module "shared_queue" {
  source = "./addons/messaging/sqs"

  project_name = "shared"
  environment  = "prod"
  queue_name   = "cross-account"

  # Cross-account 정책
  queue_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage"
        ]
        Resource = "*"
      }
    ]
  })

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
| `queue_name` | SQS 큐 이름 | `string` |

### 선택적 Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `fifo_queue` | FIFO 큐 여부 | `bool` | `false` |
| `enable_dlq` | DLQ 활성화 | `bool` | `true` |
| `max_receive_count` | DLQ 이동 전 최대 수신 횟수 | `number` | `3` |
| `visibility_timeout_seconds` | 가시성 타임아웃 (초) | `number` | `30` |
| `message_retention_seconds` | 메시지 보존 기간 (초) | `number` | `1209600` |
| `enable_monitoring` | 모니터링 활성화 | `bool` | `true` |
| `create_iam_role` | IAM 역할 생성 | `bool` | `false` |
| `kms_master_key_id` | KMS 키 ID | `string` | `null` |

전체 변수 목록은 `variables.tf` 파일을 참조하세요.

## Outputs

| Name | Description |
|------|-------------|
| `queue_id` | SQS 큐 ID (URL) |
| `queue_arn` | SQS 큐 ARN |
| `queue_name` | SQS 큐 이름 |
| `dlq_arn` | DLQ ARN |
| `iam_role_arn` | IAM 역할 ARN |
| `cloudwatch_alarms` | CloudWatch 알람 정보 |

전체 출력 목록은 `outputs.tf` 파일을 참조하세요.

## 모니터링

### CloudWatch 알람

자동으로 생성되는 알람:

1. **Visible Messages**: 큐에 쌓인 메시지 수
2. **Oldest Message Age**: 가장 오래된 메시지의 나이
3. **DLQ Messages**: DLQ에 있는 메시지 수

### CloudWatch 대시보드

`create_dashboard = true`로 설정하면 다음 메트릭을 포함한 대시보드가 생성됩니다:

- ApproximateNumberOfVisibleMessages
- ApproximateAgeOfOldestMessage
- NumberOfMessagesSent/Received/Deleted

## 보안

### 암호화

1. **SQS 관리 암호화**: 기본적으로 활성화
2. **KMS 암호화**: `kms_master_key_id` 설정으로 활성화
3. **전송 중 암호화**: HTTPS 강제

### IAM 정책

생성되는 IAM 정책은 최소 권한 원칙을 따릅니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility"
      ],
      "Resource": "arn:aws:sqs:region:account:queue-name"
    }
  ]
}
```

## 통합 예제

### SNS와 함께

```hcl
# SNS Topic
module "notifications" {
  source = "./addons/messaging/sns"
  # ... SNS 설정
}

# SQS Queue for SNS messages
module "notification_queue" {
  source = "./addons/messaging/sqs"

  project_name = "notifications"
  environment  = "prod"
  queue_name   = "email-processing"

  # SNS가 메시지를 보낼 수 있도록 정책 설정
  queue_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = "*"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.notifications.topic_arn
          }
        }
      }
    ]
  })
}

# SNS Subscription to SQS
resource "aws_sns_topic_subscription" "queue" {
  topic_arn = module.notifications.topic_arn
  protocol  = "sqs"
  endpoint  = module.notification_queue.queue_arn
}
```

## 모범 사례

1. **DLQ 사용**: 항상 DLQ를 활성화하여 처리 실패한 메시지를 추적
2. **적절한 타임아웃**: 처리 시간에 맞게 visibility timeout 설정
3. **배치 처리**: Lambda 트리거 시 적절한 batch_size 설정
4. **모니터링**: CloudWatch 알람으로 큐 상태 모니터링
5. **암호화**: 민감한 데이터는 KMS 암호화 사용
6. **FIFO vs 표준**: 순서가 중요한 경우만 FIFO 사용 (비용과 처리량 고려)

## 제한사항

- FIFO 큐는 초당 최대 3,000개 메시지 처리 (batch 사용 시 30,000개)
- 표준 큐는 거의 무제한 처리량이지만 순서 보장 없음
- 메시지 크기는 최대 256KB
- 메시지 보존 기간은 최대 14일

## 라이센스

MIT License

## 지원

Issues 및 기여는 GitHub 저장소를 통해 환영합니다.