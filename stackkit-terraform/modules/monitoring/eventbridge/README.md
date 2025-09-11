# EventBridge 모듈

AWS EventBridge (Amazon CloudWatch Events)를 사용한 이벤트 기반 아키텍처 구성을 위한 Terraform 모듈입니다.

## 기능

- EventBridge 규칙 및 타겟 생성
- 커스텀 이벤트 버스 지원
- 다양한 이벤트 소스 및 타겟 연결
- 스케줄 기반 이벤트 (cron, rate expressions)
- 이벤트 패턴 매칭 및 필터링
- API 대상 및 연결 관리
- 이벤트 아카이브 및 재생 기능
- 교차 계정 이벤트 라우팅
- CloudWatch 모니터링 및 알람

## 사용법

### 기본 사용 (스케줄링)

```hcl
module "scheduled_events" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 스케줄 기반 규칙
  rules = [
    {
      name                = "daily-backup"
      description         = "Daily backup trigger"
      schedule_expression = "cron(0 2 * * ? *)"  # 매일 오전 2시
      is_enabled         = true
      
      targets = [
        {
          arn = module.backup_lambda.function_arn
          input = jsonencode({
            backup_type = "daily"
            retention_days = 30
          })
        }
      ]
    },
    {
      name                = "health-check"
      description         = "Health check every 5 minutes"
      schedule_expression = "rate(5 minutes)"
      is_enabled         = true
      
      targets = [
        {
          arn = module.health_check_lambda.function_arn
        }
      ]
    }
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "automation"
  }
}
```

### 고급 설정 (이벤트 패턴)

```hcl
module "event_processing" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "order-system"
  environment  = "prod"
  
  # 커스텀 이벤트 버스 생성
  create_custom_bus = true
  bus_name         = "order-events"
  event_source_name = "mycompany.orders"
  kms_key_id       = module.eventbridge_kms.key_id
  
  # 이벤트 패턴 기반 규칙
  rules = [
    {
      name        = "order-created"
      description = "Handle new order events"
      event_pattern = jsonencode({
        source      = ["mycompany.orders"]
        detail-type = ["Order Created"]
        detail = {
          status = ["pending"]
          amount = {
            numeric = [">", 100]
          }
        }
      })
      is_enabled = true
      
      targets = [
        # Lambda 함수 처리
        {
          arn = module.order_processor.function_arn
          input_transformer = {
            input_paths = {
              orderId = "$.detail.orderId"
              amount  = "$.detail.amount"
              customer = "$.detail.customer"
            }
            input_template = jsonencode({
              order_id = "<orderId>"
              amount   = "<amount>"
              customer_id = "<customer>"
              processed_at = "$AWS_REGION"
            })
          }
        },
        # SQS 큐로 전송
        {
          arn = module.order_queue.queue_arn
          sqs_parameters = {
            message_group_id = "order-processing"
          }
        },
        # SNS 알림
        {
          arn = module.order_notifications.topic_arn
        }
      ]
    },
    {
      name        = "high-value-orders"
      description = "Special handling for high-value orders"
      event_pattern = jsonencode({
        source      = ["mycompany.orders"]
        detail-type = ["Order Created"]
        detail = {
          amount = {
            numeric = [">", 1000]
          }
        }
      })
      
      targets = [
        {
          arn = module.fraud_detection.function_arn
          retry_policy = {
            maximum_event_age_in_seconds = 3600
            maximum_retry_attempts      = 3
          }
          dead_letter_queue_arn = module.fraud_dlq.queue_arn
        }
      ]
    }
  ]
  
  common_tags = {
    Project      = "order-system"
    Environment  = "prod"
    Component    = "event-processing"
    CriticalPath = "yes"
  }
}
```

### API 대상 통합 (Webhook)

```hcl
module "webhook_events" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "integration-hub"
  environment  = "prod"
  
  # API 연결 설정
  connections = [
    {
      name               = "webhook-connection"
      description        = "Connection to external webhook"
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "X-API-Key"
          value = var.webhook_api_key
        }
      }
    },
    {
      name               = "oauth-connection"
      description        = "OAuth connection to external API"
      authorization_type = "OAUTH_CLIENT_CREDENTIALS"
      auth_parameters = {
        oauth = {
          authorization_endpoint = "https://api.example.com/oauth/token"
          http_method           = "POST"
          client_parameters = {
            client_id = var.oauth_client_id
          }
          oauth_http_parameters = {
            body_parameters = {
              grant_type = "client_credentials"
              scope     = "api:write"
            }
          }
        }
      }
    }
  ]
  
  # API 대상 설정
  api_destinations = [
    {
      name                = "external-webhook"
      description         = "Send events to external system"
      invocation_endpoint = "https://api.example.com/webhook"
      http_method        = "POST"
      invocation_rate_limit_per_second = 10
      connection_name    = "webhook-connection"
    }
  ]
  
  # 웹훅 이벤트 규칙
  rules = [
    {
      name        = "user-events"
      description = "Forward user events to external system"
      event_pattern = jsonencode({
        source      = ["myapp.users"]
        detail-type = ["User Created", "User Updated", "User Deleted"]
      })
      
      targets = [
        {
          arn = "arn:aws:events:::api-destination/external-webhook/*"
          role_arn = aws_iam_role.eventbridge_api_destination.arn
          http_parameters = {
            header_parameters = {
              "X-Event-Source" = "aws-eventbridge"
              "X-Timestamp"    = "$AWS_EVENTS_EVENT_INGESTION_TIME"
            }
          }
        }
      ]
    }
  ]
  
  common_tags = {
    Project = "integration-hub"
    Environment = "prod"
    IntegrationType = "webhook"
  }
}
```

### 이벤트 아카이브 및 재생

```hcl
module "event_archiving" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "audit-system"
  environment  = "prod"
  
  # 아카이브 설정
  archives = [
    {
      name           = "audit-events-archive"
      description    = "Archive all audit events"
      retention_days = 2555  # 7년 보존
      event_pattern = jsonencode({
        source = ["myapp.audit"]
      })
    },
    {
      name           = "compliance-archive"
      description    = "Compliance events archive"
      retention_days = 365   # 1년 보존
      event_pattern = jsonencode({
        source = ["myapp.compliance"]
        detail-type = ["Compliance Event"]
      })
    }
  ]
  
  # 재생 설정 (필요시)
  replays = [
    {
      name             = "incident-replay"
      description      = "Replay events from incident timeframe"
      archive_name     = "audit-events-archive"
      event_start_time = "2024-01-01T00:00:00Z"
      event_end_time   = "2024-01-02T00:00:00Z"
      destination = {
        arn = module.incident_analysis.topic_arn
      }
    }
  ]
  
  common_tags = {
    Project = "audit-system"
    Environment = "prod"
    Purpose = "compliance"
  }
}
```

### 교차 리전 이벤트 복제

```hcl
module "cross_region_events" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "global-app"
  environment  = "prod"
  
  # 리전 간 복제 규칙
  rules = [
    {
      name        = "replicate-to-backup-region"
      description = "Replicate critical events to backup region"
      event_pattern = jsonencode({
        source = ["myapp.critical"]
      })
      
      targets = [
        {
          arn = "arn:aws:events:us-west-2:${data.aws_caller_identity.current.account_id}:event-bus/backup-events"
          role_arn = aws_iam_role.cross_region_eventbridge.arn
        }
      ]
    }
  ]
  
  common_tags = {
    Project = "global-app"
    Environment = "prod"
    DisasterRecovery = "enabled"
  }
}
```

### 마이크로서비스 간 이벤트 라우팅

```hcl
locals {
  services = ["user", "order", "payment", "notification"]
}

module "service_events" {
  source = "../../modules/monitoring/eventbridge"
  
  project_name = "microservices"
  environment  = "prod"
  
  create_custom_bus = true
  bus_name         = "service-events"
  
  # 서비스별 이벤트 라우팅 규칙
  rules = [
    # 사용자 서비스 이벤트
    {
      name        = "user-service-events"
      description = "Route user service events"
      event_pattern = jsonencode({
        source = ["microservices.user"]
      })
      
      targets = [
        # 알림 서비스로 전송
        {
          arn = module.notification_queue.queue_arn
          input_path = "$.detail"
        },
        # 분석용 Kinesis로 전송
        {
          arn = module.analytics_stream.stream_arn
          kinesis_parameters = {
            partition_key_path = "$.detail.userId"
          }
        }
      ]
    },
    # 주문 서비스 이벤트
    {
      name        = "order-service-events"  
      description = "Route order service events"
      event_pattern = jsonencode({
        source = ["microservices.order"]
        detail-type = ["Order Status Changed"]
      })
      
      targets = [
        # 결제 서비스 트리거
        {
          arn = module.payment_processor.function_arn
          input_transformer = {
            input_paths = {
              orderId = "$.detail.orderId"
              amount  = "$.detail.totalAmount"
            }
            input_template = jsonencode({
              order_id = "<orderId>"
              amount   = "<amount>"
              action   = "process_payment"
            })
          }
        }
      ]
    }
  ]
  
  common_tags = {
    Project = "microservices"
    Environment = "prod"
    Architecture = "event-driven"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `create_custom_bus` | 커스텀 이벤트 버스 생성 여부 | `bool` | `false` | ❌ |
| `bus_name` | 이벤트 버스 이름 | `string` | `"default"` | ❌ |
| `event_source_name` | 이벤트 소스 이름 (커스텀 버스용) | `string` | `null` | ❌ |
| `kms_key_id` | KMS 키 ID (이벤트 버스 암호화용) | `string` | `null` | ❌ |
| `rules` | EventBridge 규칙 설정 리스트 | `list(object)` | `[]` | ❌ |
| `connections` | EventBridge 연결 설정 (API 대상용) | `list(object)` | `[]` | ❌ |
| `api_destinations` | EventBridge API 대상 설정 | `list(object)` | `[]` | ❌ |
| `archives` | EventBridge 아카이브 설정 | `list(object)` | `[]` | ❌ |
| `replays` | EventBridge 재생 설정 | `list(object)` | `[]` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `invocation_alarm_threshold` | 호출 알람 임계값 (최소 호출 수) | `number` | `1` | ❌ |
| `failure_alarm_threshold` | 실패 알람 임계값 | `number` | `1` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `event_bus_name` | EventBridge 버스 이름 | `string` |
| `event_bus_arn` | EventBridge 버스 ARN | `string` |
| `rule_names` | EventBridge 규칙 이름 리스트 | `list(string)` |
| `rule_arns` | EventBridge 규칙 ARN 리스트 | `list(string)` |
| `rule_details` | EventBridge 규칙 상세 정보 | `list(object)` |
| `target_ids` | EventBridge 대상 ID 리스트 | `list(string)` |
| `connection_names` | EventBridge 연결 이름 리스트 | `list(string)` |
| `api_destination_names` | EventBridge API 대상 이름 리스트 | `list(string)` |
| `archive_names` | EventBridge 아카이브 이름 리스트 | `list(string)` |
| `replay_names` | EventBridge 재생 이름 리스트 | `list(string)` |
| `eventbridge_configuration` | EventBridge 설정 요약 | `object` |

## 일반적인 사용 사례

### 1. 자동화 스케줄링

```hcl
module "automation" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    # 주간 리포트 생성
    {
      name                = "weekly-report"
      description         = "Generate weekly reports"
      schedule_expression = "cron(0 9 ? * MON *)"  # 매주 월요일 9시
      targets = [
        {
          arn = module.report_generator.function_arn
        }
      ]
    },
    # 월간 정리 작업
    {
      name                = "monthly-cleanup"
      description         = "Monthly data cleanup"
      schedule_expression = "cron(0 3 1 * ? *)"  # 매월 1일 3시
      targets = [
        {
          arn = module.cleanup_lambda.function_arn
        }
      ]
    }
  ]
}
```

### 2. 시스템 모니터링

```hcl
module "system_monitoring" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    {
      name        = "ec2-state-changes"
      description = "Monitor EC2 instance state changes"
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
        detail = {
          state = ["terminated", "stopped"]
        }
      })
      
      targets = [
        {
          arn = module.instance_monitor.function_arn
        }
      ]
    }
  ]
}
```

### 3. 데이터 파이프라인 오케스트레이션

```hcl
module "data_pipeline" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    {
      name        = "s3-data-arrival"
      description = "Process data when uploaded to S3"
      event_pattern = jsonencode({
        source      = ["aws.s3"]
        detail-type = ["Object Created"]
        detail = {
          bucket = {
            name = [module.data_bucket.bucket_name]
          }
        }
      })
      
      targets = [
        {
          arn = module.data_processor.state_machine_arn
          role_arn = aws_iam_role.step_functions_execution.arn
        }
      ]
    }
  ]
}
```

## 모범 사례

### 이벤트 패턴 최적화

```hcl
# ✅ 좋은 예: 구체적인 이벤트 패턴
module "optimized_events" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    {
      name = "specific-events"
      event_pattern = jsonencode({
        source      = ["myapp.orders"]
        detail-type = ["Order Created"]
        detail = {
          status = ["pending"]
          region = [data.aws_region.current.name]  # 현재 리전만
          amount = {
            numeric = [">", 0]  # 유효한 금액만
          }
        }
      })
    }
  ]
}

# ❌ 피해야 할 예: 너무 광범위한 패턴
# event_pattern = jsonencode({
#   source = ["*"]  # 모든 소스 (비효율적)
# })
```

### 오류 처리 및 재시도

```hcl
module "resilient_events" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    {
      name = "resilient-processing"
      event_pattern = jsonencode({
        source = ["myapp.critical"]
      })
      
      targets = [
        {
          arn = module.critical_processor.function_arn
          
          # 재시도 정책
          retry_policy = {
            maximum_event_age_in_seconds = 7200  # 2시간
            maximum_retry_attempts      = 3
          }
          
          # DLQ 설정
          dead_letter_queue_arn = module.processing_dlq.queue_arn
        }
      ]
    }
  ]
}
```

### 보안 및 접근 제어

```hcl
module "secure_events" {
  source = "../../modules/monitoring/eventbridge"
  
  create_custom_bus = true
  bus_name         = "secure-events"
  kms_key_id       = module.eventbridge_kms.key_id
  
  # IAM 역할을 통한 정확한 권한 제어
  rules = [
    {
      name = "secure-processing"
      event_pattern = jsonencode({
        source = ["myapp.secure"]
      })
      
      targets = [
        {
          arn = module.secure_processor.function_arn
          role_arn = aws_iam_role.eventbridge_secure_execution.arn
        }
      ]
    }
  ]
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "PutTargets" 권한 부족

```hcl
# 해결책: EventBridge가 타겟 서비스를 호출할 수 있는 IAM 역할 생성
resource "aws_iam_role" "eventbridge_execution" {
  name = "eventbridge-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_targets" {
  role = aws_iam_role.eventbridge_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction",
        "sqs:SendMessage",
        "sns:Publish"
      ]
      Resource = "*"
    }]
  })
}
```

#### 2. 이벤트가 트리거되지 않음

```hcl
# 해결책: 이벤트 패턴 디버깅
# CloudTrail에서 실제 이벤트 구조 확인 후 패턴 조정
module "debug_events" {
  source = "../../modules/monitoring/eventbridge"
  
  rules = [
    {
      name = "debug-all-events"
      event_pattern = jsonencode({
        source = ["myapp.debug"]
        # 처음에는 모든 이벤트를 받도록 설정 후 점진적으로 필터링
      })
      
      targets = [
        {
          arn = module.debug_logger.function_arn
        }
      ]
    }
  ]
}
```

#### 3. API 대상 연결 실패

```hcl
# 해결책: 연결 상태 및 인증 정보 확인
module "api_destination_fixed" {
  source = "../../modules/monitoring/eventbridge"
  
  connections = [
    {
      name = "external-api"
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "Authorization"
          value = "Bearer ${var.api_token}"  # 올바른 형식으로 설정
        }
      }
    }
  ]
}
```

## 제한 사항

- 규칙당 최대 5개의 타겟
- 이벤트 크기 최대 256KB
- 이벤트 패턴 크기 최대 2048자
- API 대상 호출 비율 제한
- 아카이브 보존 기간 최대 10년
- 재생은 아카이브된 이벤트만 가능

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.