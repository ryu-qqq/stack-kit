# SQS 모듈

AWS SQS (Simple Queue Service) 큐와 관련 리소스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- SQS 큐 생성 (표준, FIFO)
- 데드 레터 큐 (DLQ) 자동 생성 및 설정
- 메시지 암호화 (KMS, SQS 관리형)
- Lambda 함수와의 이벤트 소스 매핑
- 가시성 타임아웃 및 메시지 보존 설정
- Long Polling 지원
- IAM 정책 자동 생성
- CloudWatch 모니터링 및 알람
- FIFO 큐 중복 제거 및 순서 보장

## 사용법

### 기본 사용 (표준 큐)

```hcl
module "task_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "my-app"
  environment  = "dev"
  
  queue_name = "task-processing"
  
  # 기본 설정
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600  # 14일
  receive_wait_time_seconds  = 20       # Long Polling
  
  # DLQ 설정
  create_dlq         = true
  max_receive_count  = 3
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "task-processing"
  }
}
```

### 고급 설정 (Lambda 통합)

```hcl
module "lambda_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "order-system"
  environment  = "prod"
  
  queue_name = "order-processing"
  
  # 큐 설정 최적화
  visibility_timeout_seconds = 300  # Lambda 타임아웃보다 6배 크게
  message_retention_seconds  = 604800  # 7일
  receive_wait_time_seconds  = 20
  max_message_size          = 262144  # 256KB
  
  # DLQ 설정
  create_dlq         = true
  max_receive_count  = 5
  dlq_message_retention_seconds = 1209600  # 14일
  
  # KMS 암호화
  kms_master_key_id = module.order_kms.key_id
  
  # Lambda 트리거 설정
  lambda_trigger = {
    function_name = module.order_processor.function_name
    batch_size   = 10
    enabled      = true
    scaling_config = {
      maximum_concurrency = 100
    }
    filter_criteria = {
      filters = [
        {
          pattern = jsonencode({
            eventType = ["order_created", "order_updated"]
          })
        }
      ]
    }
  }
  
  # IAM 정책 생성
  create_iam_policy = true
  
  # 모니터링
  create_cloudwatch_alarms = true
  visible_messages_alarm_threshold = 50
  oldest_message_age_alarm_threshold = 900  # 15분
  alarm_actions = [module.alert_topic.topic_arn]
  
  common_tags = {
    Project      = "order-system"
    Environment  = "prod"
    Component    = "messaging"
    CriticalPath = "yes"
  }
}
```

### FIFO 큐 (순서 보장)

```hcl
module "fifo_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "payment-system"
  environment  = "prod"
  
  queue_name = "payment-events.fifo"
  
  # FIFO 설정
  fifo_queue                 = true
  content_based_deduplication = true
  deduplication_scope        = "messageGroup"
  fifo_throughput_limit      = "perMessageGroupId"
  
  # 설정 최적화
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600  # 4일
  
  # FIFO DLQ
  create_dlq        = true
  max_receive_count = 3
  
  # 암호화
  kms_master_key_id = module.payment_kms.key_id
  
  # Lambda 처리
  lambda_trigger = {
    function_name = module.payment_processor.function_name
    batch_size   = 1  # FIFO에서는 순서 보장을 위해 작게 설정
    enabled      = true
  }
  
  common_tags = {
    Project = "payment-system"
    Environment = "prod"
    DataType = "transactional"
    Ordering = "required"
  }
}
```

### 배치 처리용 큐

```hcl
module "batch_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "analytics"
  environment  = "prod"
  
  queue_name = "data-processing-batch"
  
  # 배치 최적화 설정
  visibility_timeout_seconds = 43200   # 12시간 (긴 배치 작업용)
  message_retention_seconds  = 1209600 # 14일
  receive_wait_time_seconds  = 20
  max_message_size          = 262144
  delay_seconds             = 0
  
  # DLQ 설정 (배치용)
  create_dlq         = true
  max_receive_count  = 1  # 배치는 재처리 비용이 크므로 바로 DLQ로
  
  # 큐 정책 (S3 이벤트 알림 허용)
  queue_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "SQS:SendMessage"
        Resource = "*"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.data_bucket.bucket_arn
          }
        }
      }
    ]
  })
  
  # 모니터링
  visible_messages_alarm_threshold = 100
  oldest_message_age_alarm_threshold = 7200  # 2시간
  
  common_tags = {
    Project = "analytics"
    Environment = "prod"
    WorkloadType = "batch"
  }
}
```

### 마이크로서비스 간 통신

```hcl
locals {
  services = ["user", "order", "inventory", "notification"]
}

module "service_queues" {
  for_each = toset(local.services)
  source   = "../../modules/integration/sqs"
  
  project_name = "ecommerce"
  environment  = "prod"
  
  queue_name = "${each.key}-service-queue"
  
  # 서비스별 설정
  visibility_timeout_seconds = each.key == "notification" ? 60 : 300
  message_retention_seconds  = 604800  # 7일
  receive_wait_time_seconds  = 20
  
  # DLQ 설정
  create_dlq        = true
  max_receive_count = each.key == "order" ? 5 : 3  # 주문은 더 많은 재시도
  
  # 중요 서비스는 암호화
  kms_master_key_id = contains(["order", "user"], each.key) ? module.service_kms.key_id : null
  
  # 모니터링 임계값 조정
  visible_messages_alarm_threshold = each.key == "notification" ? 1000 : 50
  oldest_message_age_alarm_threshold = each.key == "notification" ? 300 : 600
  
  common_tags = {
    Project     = "ecommerce"
    Environment = "prod"
    Service     = each.key
    Architecture = "microservices"
  }
}
```

### 환경별 설정

```hcl
locals {
  queue_config = {
    dev = {
      dlq_enabled           = false
      monitoring_enabled    = false
      encryption_enabled    = false
      retention_days       = 1
      visibility_timeout   = 30
    }
    staging = {
      dlq_enabled           = true
      monitoring_enabled    = true
      encryption_enabled    = false
      retention_days       = 7
      visibility_timeout   = 300
    }
    prod = {
      dlq_enabled           = true
      monitoring_enabled    = true
      encryption_enabled    = true
      retention_days       = 14
      visibility_timeout   = 300
    }
  }
}

module "adaptive_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  queue_name = "app-events-${var.environment}"
  
  # 환경별 동적 설정
  create_dlq                = local.queue_config[var.environment].dlq_enabled
  create_cloudwatch_alarms  = local.queue_config[var.environment].monitoring_enabled
  visibility_timeout_seconds = local.queue_config[var.environment].visibility_timeout
  message_retention_seconds = local.queue_config[var.environment].retention_days * 86400
  
  # 프로덕션에서만 암호화
  kms_master_key_id = local.queue_config[var.environment].encryption_enabled ? module.kms[0].key_id : null
  
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
| `queue_name` | SQS 큐 이름 | `string` | - | ✅ |
| `delay_seconds` | 메시지 지연 시간 (초) | `number` | `0` | ❌ |
| `max_message_size` | 최대 메시지 크기 (바이트) | `number` | `262144` | ❌ |
| `message_retention_seconds` | 메시지 보존 시간 (초) | `number` | `1209600` | ❌ |
| `receive_wait_time_seconds` | 수신 대기 시간 (초) - Long Polling | `number` | `0` | ❌ |
| `visibility_timeout_seconds` | 가시성 타임아웃 (초) | `number` | `30` | ❌ |
| `fifo_queue` | FIFO 큐 여부 | `bool` | `false` | ❌ |
| `content_based_deduplication` | 콘텐츠 기반 중복 제거 (FIFO 큐만 해당) | `bool` | `false` | ❌ |
| `deduplication_scope` | 중복 제거 범위 (FIFO 큐만 해당) | `string` | `null` | ❌ |
| `fifo_throughput_limit` | FIFO 처리량 제한 (FIFO 큐만 해당) | `string` | `null` | ❌ |
| `create_dlq` | 데드 레터 큐 생성 여부 | `bool` | `true` | ❌ |
| `max_receive_count` | 최대 수신 횟수 (DLQ로 이동하기 전) | `number` | `3` | ❌ |
| `dlq_message_retention_seconds` | DLQ 메시지 보존 시간 (초) | `number` | `1209600` | ❌ |
| `kms_master_key_id` | KMS 마스터 키 ID | `string` | `null` | ❌ |
| `sqs_managed_sse_enabled` | SQS 관리형 SSE 활성화 | `bool` | `true` | ❌ |
| `queue_policy` | 큐 정책 (JSON) | `string` | `null` | ❌ |
| `lambda_trigger` | Lambda 트리거 설정 | `object` | `null` | ❌ |
| `create_iam_policy` | IAM 정책 생성 여부 | `bool` | `false` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `visible_messages_alarm_threshold` | 가시 메시지 수 알람 임계값 | `number` | `10` | ❌ |
| `oldest_message_age_alarm_threshold` | 가장 오래된 메시지 연령 알람 임계값 (초) | `number` | `600` | ❌ |
| `dlq_messages_alarm_threshold` | DLQ 메시지 수 알람 임계값 | `number` | `1` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `queue_id` | SQS 큐 ID | `string` |
| `queue_arn` | SQS 큐 ARN | `string` |
| `queue_name` | SQS 큐 이름 | `string` |
| `queue_url` | SQS 큐 URL | `string` |
| `dlq_id` | DLQ ID | `string` |
| `dlq_arn` | DLQ ARN | `string` |
| `dlq_url` | DLQ URL | `string` |
| `fifo_queue` | FIFO 큐 여부 | `bool` |
| `visibility_timeout_seconds` | 가시성 타임아웃 (초) | `number` |
| `message_retention_seconds` | 메시지 보존 시간 (초) | `number` |
| `iam_policy_arn` | SQS 접근 IAM 정책 ARN | `string` |
| `lambda_event_source_mapping_uuid` | Lambda 이벤트 소스 매핑 UUID | `string` |
| `queue_attributes` | 큐 속성 정보 | `object` |
| `dlq_attributes` | DLQ 속성 정보 | `object` |

## 일반적인 사용 사례

### 1. 비동기 작업 처리

```hcl
module "async_job_queue" {
  source = "../../modules/integration/sqs"
  
  project_name = "web-app"
  environment  = "prod"
  
  queue_name = "background-jobs"
  
  # 긴 작업을 위한 설정
  visibility_timeout_seconds = 900  # 15분
  message_retention_seconds  = 604800  # 7일
  
  # Lambda 워커와 연결
  lambda_trigger = {
    function_name = module.job_worker.function_name
    batch_size   = 5
    enabled      = true
  }
}
```

### 2. 이벤트 버퍼링

```hcl
module "event_buffer" {
  source = "../../modules/integration/sqs"
  
  queue_name = "analytics-events"
  
  # 대량 이벤트 처리용
  max_message_size          = 262144
  receive_wait_time_seconds = 20
  
  # 배치 처리 최적화
  lambda_trigger = {
    function_name = module.analytics_processor.function_name
    batch_size   = 100  # 대량 처리
    enabled      = true
  }
}
```

### 3. 시스템 간 디커플링

```hcl
module "integration_queue" {
  source = "../../modules/integration/sqs"
  
  queue_name = "system-integration"
  
  # 외부 시스템 호출용 정책
  queue_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.external_system_role_arn
      }
      Action = ["SQS:SendMessage", "SQS:ReceiveMessage"]
      Resource = "*"
    }]
  })
}
```

## 모범 사례

### 성능 최적화

```hcl
# ✅ 좋은 예: 성능 최적화 설정
module "optimized_queue" {
  source = "../../modules/integration/sqs"
  
  # Long Polling 활성화 (비용 절약 + 지연시간 감소)
  receive_wait_time_seconds = 20
  
  # 적절한 가시성 타임아웃 (Lambda 타임아웃의 6배)
  visibility_timeout_seconds = 300
  
  # 배치 크기 최적화
  lambda_trigger = {
    function_name = module.processor.function_name
    batch_size   = 10  # 처리량과 지연시간의 균형
    enabled      = true
    scaling_config = {
      maximum_concurrency = 100
    }
  }
}

# ❌ 피해야 할 예
# receive_wait_time_seconds = 0  # Short polling (비효율적)
# visibility_timeout_seconds = 30  # Lambda 타임아웃보다 작음
```

### 오류 처리 및 복구

```hcl
module "resilient_queue" {
  source = "../../modules/integration/sqs"
  
  # 적절한 재시도 설정
  create_dlq        = true
  max_receive_count = 3
  
  # DLQ 메시지 보존 기간 연장
  dlq_message_retention_seconds = 1209600  # 14일
  
  # 재시도 정책
  redrive_policy = jsonencode({
    deadLetterTargetArn = module.error_analysis_queue.queue_arn
    maxReceiveCount    = 3
  })
  
  # 오류 모니터링
  create_cloudwatch_alarms = true
  dlq_messages_alarm_threshold = 1  # DLQ에 메시지가 들어오면 즉시 알림
}
```

### 보안 강화

```hcl
module "secure_queue" {
  source = "../../modules/integration/sqs"
  
  # 암호화 활성화
  kms_master_key_id = module.app_kms.key_id
  
  # 최소 권한 정책
  queue_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.allowed_role_arns
      }
      Action = [
        "SQS:SendMessage",
        "SQS:ReceiveMessage",
        "SQS:DeleteMessage"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "ReceiptHandleIsInvalid"

```hcl
# 해결책: 가시성 타임아웃을 처리 시간보다 길게 설정
module "queue" {
  source = "../../modules/integration/sqs"
  
  # Lambda 함수가 5분이면 30분으로 설정
  visibility_timeout_seconds = 1800  # Lambda 타임아웃의 6배
}
```

#### 2. "MessageNotInflight"

```hcl
# 해결책: 메시지 중복 처리 방지
# 애플리케이션에서 메시지 ID 중복 체크 로직 구현
```

#### 3. "QueueLimitExceeded"

```hcl
# 해결책: 리전당 큐 수 제한 확인 (1,000개)
# 필요시 AWS 지원을 통해 한도 증가 요청
```

#### 4. FIFO 큐 성능 이슈

```hcl
module "high_throughput_fifo" {
  source = "../../modules/integration/sqs"
  
  fifo_queue = true
  
  # 처리량 제한을 메시지 그룹별로 설정
  fifo_throughput_limit = "perMessageGroupId"
  deduplication_scope  = "messageGroup"
  
  # 메시지 그룹을 다양하게 사용하여 병렬 처리
}
```

## 제한 사항

- 메시지 크기 최대 256KB
- 큐당 처리중 메시지 최대 120,000개 (표준 큐)
- FIFO 큐는 초당 3,000개 트랜잭션 제한
- 메시지 보존 기간 최대 14일
- 가시성 타임아웃 최대 12시간
- 지연 큐 최대 15분

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.