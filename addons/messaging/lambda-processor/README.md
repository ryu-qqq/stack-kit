# Lambda Processor Messaging Addon

## 개요

이벤트 기반 메시지 처리를 위한 enterprise-grade Lambda Terraform 모듈입니다. SQS, SNS, EventBridge와의 통합, VPC 구성, 모니터링 기능을 포함합니다.

## 버전

- **v1.0.0** - 초기 릴리즈

## 특징

- ✅ **이벤트 기반 처리** (SQS, SNS, EventBridge)
- ✅ **VPC 네트워크 격리**
- ✅ **다중 AWS 서비스 통합** (DynamoDB, S3)
- ✅ **CloudWatch 모니터링 및 알람**
- ✅ **X-Ray 분산 추적**
- ✅ **IAM 역할 및 정책 자동 생성**
- ✅ **Dead Letter Queue 지원**
- ✅ **배치 처리 최적화**
- ✅ **CloudWatch 대시보드**

## 사용법

### 기본 SQS 메시지 처리

```hcl
module "order_processor" {
  source = "./addons/messaging/lambda-processor"

  project_name  = "ecommerce"
  environment   = "prod"
  function_name = "order-processor"

  # 함수 설정
  runtime     = "python3.11"
  handler     = "app.handler"
  memory_size = 512
  timeout     = 300

  # 코드 배포
  filename         = "order-processor.zip"
  source_code_hash = filebase64sha256("order-processor.zip")

  # SQS 이벤트 소스
  sqs_config = {
    queue_arn  = module.order_queue.queue_arn
    batch_size = 10
    scaling_config = {
      maximum_concurrency = 100
    }
  }

  # 환경 변수
  environment_variables = {
    DB_TABLE_NAME = aws_dynamodb_table.orders.name
    LOG_LEVEL     = "INFO"
  }

  # DynamoDB 액세스
  dynamodb_config = {
    table_arns = [aws_dynamodb_table.orders.arn]
  }

  # 모니터링
  enable_monitoring = true
  monitoring_config = {
    error_threshold    = 5
    duration_threshold = 60000  # 60 seconds
    alarm_actions     = [aws_sns_topic.alerts.arn]
  }

  common_tags = {
    Team    = "backend"
    Service = "orders"
  }
}
```

### VPC 내 보안 처리

```hcl
module "secure_processor" {
  source = "./addons/messaging/lambda-processor"

  project_name  = "payments"
  environment   = "prod"
  function_name = "payment-processor"

  # 함수 설정
  runtime     = "python3.11"
  handler     = "secure_handler.process"
  memory_size = 1024
  timeout     = 900

  # VPC 구성
  vpc_config = {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_group_ids = [aws_security_group.lambda.id]
  }

  # 암호화
  kms_key_arn = aws_kms_key.lambda_encryption.arn

  # SQS 처리
  sqs_config = {
    queue_arn                          = module.payment_queue.queue_arn
    batch_size                         = 5
    maximum_batching_window_in_seconds = 60
    scaling_config = {
      maximum_concurrency = 50
    }
  }

  # DLQ 설정
  dead_letter_queue_arn = module.payment_dlq.queue_arn

  # X-Ray 추적
  tracing_mode = "Active"

  # 다중 서비스 통합
  dynamodb_config = {
    table_arns = [
      aws_dynamodb_table.payments.arn,
      aws_dynamodb_table.audit_log.arn
    ]
  }

  s3_config = {
    bucket_arns = [
      aws_s3_bucket.payment_files.arn,
      aws_s3_bucket.audit_files.arn
    ]
  }

  common_tags = {
    Team        = "payments"
    Compliance  = "PCI-DSS"
    Environment = "prod"
  }
}
```

### 다중 이벤트 소스 처리

```hcl
module "notification_processor" {
  source = "./addons/messaging/lambda-processor"

  project_name  = "notifications"
  environment   = "prod"
  function_name = "notification-handler"

  # 함수 설정
  runtime     = "nodejs18.x"
  handler     = "index.handler"
  memory_size = 256
  timeout     = 60

  # S3 배포
  s3_bucket = aws_s3_bucket.lambda_code.bucket
  s3_key    = "notification-handler.zip"

  # SNS 트리거
  sns_config = {
    topic_arns = [
      module.user_events.topic_arn,
      module.system_events.topic_arn
    ]
  }

  # EventBridge 트리거
  eventbridge_config = {
    rule_arns = [
      aws_cloudwatch_event_rule.scheduled_notifications.arn
    ]
  }

  # 처리 결과를 다른 SNS로 발송
  additional_iam_policies = [
    {
      Effect = "Allow"
      Action = ["sns:Publish"]
      Resource = [
        module.email_notifications.topic_arn,
        module.sms_notifications.topic_arn
      ]
    }
  ]

  # 대시보드 생성
  create_dashboard = true

  common_tags = {
    Team = "platform"
  }
}
```

### 고성능 배치 처리

```hcl
module "batch_processor" {
  source = "./addons/messaging/lambda-processor"

  project_name  = "analytics"
  environment   = "prod"
  function_name = "data-processor"

  # 고성능 설정
  runtime                       = "python3.11"
  architectures                = ["arm64"]  # 20% 비용 절약
  memory_size                   = 3008
  timeout                       = 900
  reserved_concurrent_executions = 100

  # 컨테이너 이미지 사용
  package_type = "Image"
  image_uri    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/data-processor:latest"

  # 대량 배치 처리
  sqs_config = {
    queue_arn                          = module.data_queue.queue_arn
    batch_size                         = 100
    maximum_batching_window_in_seconds = 300
    scaling_config = {
      maximum_concurrency = 50
    }
  }

  # 환경 변수
  environment_variables = {
    BATCH_SIZE      = "1000"
    PARALLEL_WORKERS = "4"
    S3_BUCKET      = aws_s3_bucket.processed_data.bucket
  }

  # S3 액세스
  s3_config = {
    bucket_arns = [
      aws_s3_bucket.raw_data.arn,
      aws_s3_bucket.processed_data.arn
    ]
  }

  # 성능 모니터링
  monitoring_config = {
    duration_threshold              = 300000  # 5 minutes
    concurrent_executions_threshold = 80
    create_concurrency_alarm       = true
    alarm_actions                  = [aws_sns_topic.performance_alerts.arn]
  }

  common_tags = {
    Team        = "data"
    Performance = "high"
  }
}
```

### Lambda Layers와 함께

```hcl
# Lambda Layer 생성
resource "aws_lambda_layer_version" "shared_libs" {
  filename   = "shared-libs.zip"
  layer_name = "shared-libs"

  compatible_runtimes = ["python3.11"]
}

module "enhanced_processor" {
  source = "./addons/messaging/lambda-processor"

  project_name  = "enhanced"
  environment   = "prod"
  function_name = "enhanced-processor"

  # 함수 설정
  runtime     = "python3.11"
  handler     = "app.handler"
  memory_size = 512

  # 레이어 사용
  layers = [
    aws_lambda_layer_version.shared_libs.arn,
    "arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPythonV2:21"
  ]

  # SQS 처리
  sqs_config = {
    queue_arn = module.events_queue.queue_arn
    filter_criteria = {
      filters = [
        {
          pattern = jsonencode({
            eventType = ["IMPORTANT", "CRITICAL"]
          })
        }
      ]
    }
  }

  common_tags = {
    Team = "platform"
  }
}
```

## Variables

### 필수 Variables

| Name | Description | Type |
|------|-------------|------|
| `project_name` | 프로젝트 이름 | `string` |
| `environment` | 환경 (dev/staging/prod) | `string` |
| `function_name` | Lambda 함수 이름 | `string` |

### 선택적 Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `runtime` | Lambda 런타임 | `string` | `"python3.11"` |
| `handler` | 함수 핸들러 | `string` | `"index.handler"` |
| `memory_size` | 메모리 크기 (MB) | `number` | `512` |
| `timeout` | 타임아웃 (초) | `number` | `60` |
| `vpc_config` | VPC 설정 | `object` | `null` |
| `sqs_config` | SQS 이벤트 소스 설정 | `object` | `null` |
| `enable_monitoring` | 모니터링 활성화 | `bool` | `true` |

전체 변수 목록은 `variables.tf` 파일을 참조하세요.

## Outputs

| Name | Description |
|------|-------------|
| `function_arn` | Lambda 함수 ARN |
| `function_name` | Lambda 함수 이름 |
| `iam_role_arn` | IAM 역할 ARN |
| `sqs_event_source_mapping` | SQS 이벤트 소스 매핑 정보 |
| `cloudwatch_alarms` | CloudWatch 알람 정보 |

전체 출력 목록은 `outputs.tf` 파일을 참조하세요.

## 이벤트 소스 연동

### SQS 연동

```hcl
sqs_config = {
  queue_arn                          = "arn:aws:sqs:region:account:queue-name"
  batch_size                         = 10      # 1-10 (standard), 1-10000 (FIFO)
  maximum_batching_window_in_seconds = 60      # 0-300 seconds
  enabled                           = true
  
  scaling_config = {
    maximum_concurrency = 100  # 2-1000
  }
  
  filter_criteria = {
    filters = [
      {
        pattern = jsonencode({
          eventType = ["ORDER_PLACED", "ORDER_CANCELLED"]
        })
      }
    ]
  }
}
```

### SNS 연동

```hcl
sns_config = {
  topic_arns = [
    "arn:aws:sns:region:account:topic-name-1",
    "arn:aws:sns:region:account:topic-name-2"
  ]
}
```

### EventBridge 연동

```hcl
eventbridge_config = {
  rule_arns = [
    "arn:aws:events:region:account:rule/scheduled-rule",
    "arn:aws:events:region:account:rule/api-gateway-rule"
  ]
}
```

## AWS 서비스 통합

### DynamoDB

```hcl
dynamodb_config = {
  table_arns = [
    "arn:aws:dynamodb:region:account:table/users",
    "arn:aws:dynamodb:region:account:table/orders"
  ]
}
```

자동으로 부여되는 권한:
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`
- `dynamodb:Query`
- `dynamodb:Scan`

### S3

```hcl
s3_config = {
  bucket_arns = [
    "arn:aws:s3:::my-data-bucket",
    "arn:aws:s3:::my-processed-bucket"
  ]
}
```

자동으로 부여되는 권한:
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`

## VPC 구성

### 네트워크 격리

```hcl
vpc_config = {
  subnet_ids = [
    "subnet-12345678",  # Private subnet A
    "subnet-87654321"   # Private subnet B
  ]
  security_group_ids = [
    "sg-lambda-processor"
  ]
}
```

### 보안 그룹 예제

```hcl
resource "aws_security_group" "lambda_processor" {
  name_prefix = "lambda-processor-"
  vpc_id      = var.vpc_id

  # 아웃바운드 HTTPS (API 호출용)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 HTTP (내부 서비스용)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 데이터베이스 액세스
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
  }

  tags = {
    Name = "lambda-processor-sg"
  }
}
```

## 모니터링

### CloudWatch 알람

자동으로 생성되는 알람:

1. **Errors**: 함수 실행 오류
2. **Duration**: 실행 시간 초과
3. **Throttles**: 동시 실행 제한 초과
4. **Concurrent Executions**: 높은 동시 실행 수 (선택적)

### CloudWatch 대시보드

`create_dashboard = true`로 설정하면 다음을 포함한 대시보드가 생성됩니다:

- Lambda 메트릭 (호출, 오류, 기간, 스로틀, 동시 실행)
- 최근 로그 (최근 100개 항목)

### X-Ray 분산 추적

```hcl
tracing_mode = "Active"
```

X-Ray를 활성화하면:
- 함수 실행 추적
- 다운스트림 서비스 호출 추적
- 성능 병목 지점 식별
- 오류 원인 분석

## 성능 최적화

### 메모리 및 CPU

```hcl
memory_size = 1024  # 메모리 증가 시 CPU도 비례적으로 증가
architectures = ["arm64"]  # Graviton2: 20% 비용 절약, 19% 성능 향상
```

### 동시 실행 제어

```hcl
reserved_concurrent_executions = 100  # 예약 동시성
```

### 콜드 스타트 최적화

```hcl
# 런타임별 콜드 스타트 시간:
# - Python: ~200ms
# - Node.js: ~150ms  
# - Java: ~800ms (SnapStart로 ~200ms)
# - .NET: ~500ms
# - Go: ~300ms

# VPC 사용 시 추가 1-3초 소요
vpc_config = null  # 필요시에만 VPC 사용
```

## 보안

### IAM 최소 권한

모듈은 요청된 서비스에 대해서만 최소 권한을 부여합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ],
      "Resource": "arn:aws:sqs:region:account:queue-name"
    }
  ]
}
```

### 암호화

1. **코드 암호화**: KMS로 환경 변수 암호화
2. **전송 중 암호화**: HTTPS 강제
3. **저장 중 암호화**: 함수 코드 자동 암호화

### VPC 격리

```hcl
vpc_config = {
  subnet_ids         = [private_subnet_ids]
  security_group_ids = [restrictive_sg_ids]
}
```

## 오류 처리

### Dead Letter Queue

```hcl
dead_letter_queue_arn = aws_sqs_queue.dlq.arn
```

실패한 함수 실행은 DLQ로 자동 전송됩니다.

### 재시도 정책

SQS 이벤트 소스의 경우:
- 자동 재시도: SQS redrive policy 사용
- 배치 실패 시: 개별 메시지별 재처리

### 오류 알람

```hcl
monitoring_config = {
  error_threshold = 5      # 5분 내 5개 오류
  alarm_actions  = [sns_topic_arn]
}
```

## 비용 최적화

### 아키텍처 선택

```hcl
architectures = ["arm64"]  # 20% 비용 절약
```

### 메모리 최적화

```bash
# AWS Lambda Power Tuning 도구 사용 권장
# https://github.com/alexcasalboni/aws-lambda-power-tuning
```

### 로그 보존 기간

```hcl
log_retention_days = 7  # 비용 절약을 위해 짧은 보존 기간
```

## 모범 사례

1. **배치 크기**: SQS 처리 시 적절한 배치 크기 설정 (10-100)
2. **타임아웃**: 실제 처리 시간보다 약간 여유 있게 설정
3. **메모리**: CPU 집약적 작업은 메모리 증가로 성능 향상
4. **VPC**: 꼭 필요한 경우만 사용 (콜드 스타트 지연)
5. **모니터링**: 알람으로 이상 상황 즉시 감지
6. **DLQ**: 실패한 메시지 추적 및 재처리
7. **레이어**: 공통 라이브러리는 레이어로 분리

## 제한사항

- 최대 실행 시간: 15분
- 최대 메모리: 10,240MB
- 최대 패키지 크기: 250MB (압축 해제 시)
- 최대 환경 변수: 4KB
- 최대 레이어: 5개
- VPC 사용 시 콜드 스타트 지연 발생

## 문제 해결

### 일반적인 문제

**권한 오류**:
```bash
# IAM 정책 확인
aws iam get-role-policy --role-name <role-name> --policy-name <policy-name>
```

**VPC 연결 문제**:
```bash
# 보안 그룹 및 라우팅 테이블 확인
aws ec2 describe-security-groups --group-ids <sg-id>
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
```

**성능 문제**:
```bash
# X-Ray 추적 활성화
tracing_mode = "Active"

# CloudWatch Insights로 로그 분석
aws logs start-query --log-group-name "/aws/lambda/function-name" \
  --start-time 1609459200 --end-time 1609545600 \
  --query-string "fields @timestamp, @duration | filter @duration > 5000"
```

## 라이센스

MIT License

## 지원

Issues 및 기여는 GitHub 저장소를 통해 환영합니다.