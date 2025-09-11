# Secrets Manager 모듈

AWS Secrets Manager를 사용한 비밀 정보 저장 및 관리를 위한 Terraform 모듈입니다.

## 기능

- Secrets Manager 시크릿 생성 및 관리
- 자동 시크릿 로테이션 설정
- KMS 암호화 지원
- 다양한 시크릿 유형 지원 (데이터베이스, API 키, 인증서 등)
- 교차 리전 복제 지원
- 리소스 정책 및 접근 제어
- 자동 시크릿 값 생성
- CloudWatch 모니터링 및 알람
- Lambda 로테이션 함수 통합

## 사용법

### 기본 사용 (단순 시크릿)

```hcl
module "api_key_secret" {
  source = "../../modules/security/secrets-manager"
  
  project_name = "my-app"
  environment  = "dev"
  
  secret_name        = "api-keys"
  description        = "External API keys for application"
  
  # 시크릿 값 (JSON 형태)
  secret_string = jsonencode({
    payment_api_key    = var.payment_api_key
    analytics_api_key  = var.analytics_api_key
    notification_key   = var.notification_key
  })
  
  # KMS 암호화
  kms_key_id = module.app_kms.key_id
  
  # 복구 설정
  recovery_window_in_days = 7
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    SecretType  = "api-keys"
  }
}
```

### 고급 설정 (데이터베이스 자격증명)

```hcl
module "database_credentials" {
  source = "../../modules/security/secrets-manager"
  
  project_name = "e-commerce"
  environment  = "prod"
  
  secret_name = "rds-master-credentials"
  description = "Master credentials for RDS PostgreSQL instance"
  
  # 자동 생성된 비밀번호 사용
  generate_secret_string = true
  secret_string_template = jsonencode({
    username = "postgres"
    engine   = "postgres"
    host     = module.rds_instance.endpoint
    port     = module.rds_instance.port
    dbname   = module.rds_instance.db_name
  })
  
  # 비밀번호 생성 규칙
  password_length  = 32
  exclude_characters = "\"@/\\"
  require_each_included_type = true
  include_space = false
  
  # 자동 로테이션 설정
  enable_rotation = true
  rotation_interval_days = 30
  rotation_lambda_arn = module.rds_rotation_lambda.function_arn
  
  # 강화된 암호화
  kms_key_id = module.database_kms.key_id
  
  # 복제 설정 (재해 복구용)
  replica_regions = [
    {
      region     = "us-west-2"
      kms_key_id = module.dr_kms.key_id
    }
  ]
  
  # 리소스 정책 (RDS만 접근 허용)
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRDSAccess"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
  
  # 모니터링 설정
  create_cloudwatch_alarms = true
  rotation_failure_alarm_enabled = true
  alarm_actions = [module.security_alerts.topic_arn]
  
  common_tags = {
    Project        = "e-commerce"
    Environment    = "prod"
    SecretType     = "database"
    CriticalData   = "yes"
    AutoRotation   = "enabled"
  }
}
```

### 멀티 시크릿 관리 (마이크로서비스)

```hcl
locals {
  services = {
    "user-service" = {
      secrets = {
        db_password     = "auto-generated"
        jwt_secret      = "auto-generated"
        external_api_key = var.user_service_api_key
      }
      rotation_days = 60
    }
    "order-service" = {
      secrets = {
        db_password      = "auto-generated"
        payment_api_key  = var.payment_api_key
        inventory_secret = "auto-generated"
      }
      rotation_days = 30
    }
    "notification-service" = {
      secrets = {
        email_api_key    = var.email_api_key
        sms_api_key      = var.sms_api_key
        push_private_key = var.push_private_key
      }
      rotation_days = 90
    }
  }
}

module "service_secrets" {
  for_each = local.services
  source   = "../../modules/security/secrets-manager"
  
  project_name = "microservices"
  environment  = "prod"
  
  secret_name = "${each.key}-secrets"
  description = "Secrets for ${each.key} microservice"
  
  # 서비스별 시크릿 구성
  secret_string = jsonencode(each.value.secrets)
  
  # 자동 생성이 필요한 경우
  generate_secret_string = contains(values(each.value.secrets), "auto-generated")
  password_length = 24
  
  # 서비스별 로테이션 주기
  enable_rotation = true
  rotation_interval_days = each.value.rotation_days
  
  # 서비스별 KMS 키
  kms_key_id = module.service_kms[each.key].key_id
  
  # 서비스별 접근 제어
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = module.service_roles[each.key].role_arn
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
  
  common_tags = {
    Project = "microservices"
    Environment = "prod"
    Service = each.key
    Architecture = "microservices"
  }
}
```

### 인증서 관리

```hcl
module "ssl_certificates" {
  source = "../../modules/security/secrets-manager"
  
  project_name = "web-platform"
  environment  = "prod"
  
  secret_name = "ssl-certificates"
  description = "SSL certificates and private keys"
  
  # 인증서 및 키 저장
  secret_string = jsonencode({
    primary_cert = {
      certificate = file("${path.module}/certs/primary.crt")
      private_key = file("${path.module}/certs/private.key")
      chain       = file("${path.module}/certs/chain.crt")
    }
    backup_cert = {
      certificate = file("${path.module}/certs/backup.crt")
      private_key = file("${path.module}/certs/backup.key")
    }
  })
  
  # 인증서는 자동 로테이션하지 않음
  enable_rotation = false
  
  # 강화된 보안
  kms_key_id = module.certificate_kms.key_id
  
  # 웹 서버만 접근 허용
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            module.web_server_role.role_arn,
            module.load_balancer_role.role_arn
          ]
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
  
  # 인증서 만료 알림
  create_cloudwatch_alarms = true
  certificate_expiry_alarm_enabled = true
  certificate_expiry_days = 30
  
  common_tags = {
    Project = "web-platform"
    Environment = "prod"
    SecretType = "certificate"
    Critical = "yes"
  }
}
```

### 환경별 설정 관리

```hcl
locals {
  env_secrets = {
    dev = {
      database_url = "postgres://dev-db:5432/myapp"
      redis_url    = "redis://dev-cache:6379"
      log_level    = "DEBUG"
    }
    staging = {
      database_url = "postgres://staging-db:5432/myapp"
      redis_url    = "redis://staging-cache:6379"
      log_level    = "INFO"
    }
    prod = {
      database_url = module.rds_instance.connection_string
      redis_url    = module.elasticache.connection_string
      log_level    = "WARN"
    }
  }
  
  secret_config = {
    dev = {
      recovery_days    = 0  # 즉시 삭제
      rotation_enabled = false
      replication      = false
    }
    staging = {
      recovery_days    = 7
      rotation_enabled = true
      replication      = false
    }
    prod = {
      recovery_days    = 30
      rotation_enabled = true
      replication      = true
    }
  }
}

module "environment_config" {
  source = "../../modules/security/secrets-manager"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  secret_name = "app-config-${var.environment}"
  description = "Application configuration for ${var.environment}"
  
  # 환경별 설정값
  secret_string = jsonencode(merge(
    local.env_secrets[var.environment],
    {
      app_secret     = random_password.app_secret.result
      jwt_secret     = random_password.jwt_secret.result
      encryption_key = random_password.encryption_key.result
    }
  ))
  
  # 환경별 복구 설정
  recovery_window_in_days = local.secret_config[var.environment].recovery_days
  
  # 환경별 로테이션
  enable_rotation = local.secret_config[var.environment].rotation_enabled
  rotation_interval_days = var.environment == "prod" ? 30 : 90
  
  # 프로덕션만 복제
  replica_regions = local.secret_config[var.environment].replication ? [
    {
      region = "us-west-2"
    }
  ] : []
  
  # 환경별 암호화
  kms_key_id = var.environment == "prod" ? module.prod_kms.key_id : null
  
  common_tags = {
    Project = "adaptive-app"
    Environment = var.environment
  }
}
```

### 교차 계정 시크릿 공유

```hcl
module "shared_secrets" {
  source = "../../modules/security/secrets-manager"
  
  project_name = "shared-infrastructure"
  environment  = "prod"
  
  secret_name = "cross-account-secrets"
  description = "Shared secrets for cross-account access"
  
  secret_string = jsonencode({
    shared_api_key = var.shared_api_key
    webhook_secret = var.webhook_secret
    integration_token = random_password.integration_token.result
  })
  
  # 교차 계정 정책
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::123456789012:root",  # 개발 계정
            "arn:aws:iam::210987654321:root",  # 스테이징 계정
            "arn:aws:iam::555666777888:root"   # 파트너 계정
          ]
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:SourceAccount" = [
              data.aws_caller_identity.current.account_id,
              "123456789012",
              "210987654321", 
              "555666777888"
            ]
          }
        }
      }
    ]
  })
  
  # 교차 리전 복제
  replica_regions = [
    {
      region = "eu-west-1"
      kms_key_id = module.eu_kms.key_id
    },
    {
      region = "ap-southeast-1"
      kms_key_id = module.apac_kms.key_id
    }
  ]
  
  common_tags = {
    Project = "shared-infrastructure"
    Environment = "prod"
    Access = "cross-account"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `secret_name` | 시크릿 이름 | `string` | - | ✅ |
| `description` | 시크릿 설명 | `string` | `null` | ❌ |
| `secret_string` | 시크릿 문자열 값 | `string` | `null` | ❌ |
| `secret_binary` | 시크릿 바이너리 값 | `string` | `null` | ❌ |
| `generate_secret_string` | 자동 시크릿 생성 여부 | `bool` | `false` | ❌ |
| `secret_string_template` | 시크릿 생성 템플릿 | `string` | `null` | ❌ |
| `password_length` | 생성할 비밀번호 길이 | `number` | `32` | ❌ |
| `exclude_characters` | 제외할 문자 | `string` | `"\"@/\\"` | ❌ |
| `include_space` | 공백 문자 포함 여부 | `bool` | `false` | ❌ |
| `require_each_included_type` | 모든 문자 유형 포함 여부 | `bool` | `true` | ❌ |
| `kms_key_id` | KMS 키 ID | `string` | `null` | ❌ |
| `recovery_window_in_days` | 복구 대기 기간 (일) | `number` | `30` | ❌ |
| `force_overwrite_replica_secret` | 복제본 시크릿 덮어쓰기 강제 | `bool` | `false` | ❌ |
| `replica_regions` | 복제 리전 설정 | `list(object)` | `[]` | ❌ |
| `policy` | 리소스 정책 (JSON) | `string` | `null` | ❌ |
| `enable_rotation` | 자동 로테이션 활성화 | `bool` | `false` | ❌ |
| `rotation_interval_days` | 로테이션 간격 (일) | `number` | `30` | ❌ |
| `rotation_lambda_arn` | 로테이션 Lambda 함수 ARN | `string` | `null` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `rotation_failure_alarm_enabled` | 로테이션 실패 알람 활성화 | `bool` | `true` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `secret_id` | Secrets Manager 시크릿 ID | `string` |
| `secret_arn` | Secrets Manager 시크릿 ARN | `string` |
| `secret_name` | 시크릿 이름 | `string` |
| `version_id` | 시크릿 버전 ID | `string` |
| `rotation_enabled` | 로테이션 활성화 여부 | `bool` |
| `rotation_lambda_arn` | 로테이션 Lambda 함수 ARN | `string` |
| `kms_key_id` | 암호화 KMS 키 ID | `string` |
| `replica_regions` | 복제 리전 리스트 | `list(string)` |
| `recovery_window_in_days` | 복구 대기 기간 | `number` |

## 일반적인 사용 사례

### 1. 애플리케이션 설정 관리

```hcl
module "app_config" {
  source = "../../modules/security/secrets-manager"
  
  secret_name = "app-configuration"
  
  secret_string = jsonencode({
    database = {
      host     = module.rds.endpoint
      port     = 5432
      username = "app_user"
      password = random_password.db_password.result
    }
    external_apis = {
      payment_key = var.payment_api_key
      email_key   = var.email_api_key
    }
    encryption = {
      jwt_secret = random_password.jwt_secret.result
      aes_key    = random_password.aes_key.result
    }
  })
}
```

### 2. OAuth 토큰 관리

```hcl
module "oauth_tokens" {
  source = "../../modules/security/secrets-manager"
  
  secret_name = "oauth-tokens"
  
  secret_string = jsonencode({
    google = {
      client_id     = var.google_client_id
      client_secret = var.google_client_secret
      refresh_token = var.google_refresh_token
    }
    github = {
      client_id     = var.github_client_id
      client_secret = var.github_client_secret
    }
  })
  
  # OAuth 토큰은 자주 로테이션
  enable_rotation = true
  rotation_interval_days = 14
}
```

### 3. 모니터링 도구 연동

```hcl
module "monitoring_secrets" {
  source = "../../modules/security/secrets-manager"
  
  secret_name = "monitoring-integration"
  
  secret_string = jsonencode({
    datadog = {
      api_key = var.datadog_api_key
      app_key = var.datadog_app_key
    }
    newrelic = {
      license_key = var.newrelic_license_key
    }
    pagerduty = {
      service_key = var.pagerduty_service_key
    }
  })
}
```

## 모범 사례

### 시크릿 구조화

```hcl
# ✅ 좋은 예: 구조화된 시크릿
module "structured_secrets" {
  source = "../../modules/security/secrets-manager"
  
  secret_string = jsonencode({
    database = {
      primary = {
        host     = "primary-db.example.com"
        username = "app_user"
        password = "generated-password"
      }
      replica = {
        host     = "replica-db.example.com"
        username = "readonly_user"
        password = "generated-password"
      }
    }
    cache = {
      redis = {
        host     = "redis.example.com"
        port     = 6379
        auth_token = "generated-token"
      }
    }
  })
}

# ❌ 피해야 할 예: 평면적 구조
# secret_string = "password1,password2,password3"
```

### 로테이션 전략

```hcl
module "rotation_optimized_secret" {
  source = "../../modules/security/secrets-manager"
  
  # 중요도에 따른 로테이션 주기
  enable_rotation = true
  rotation_interval_days = var.secret_type == "database" ? 30 : 
                          var.secret_type == "api_key" ? 60 : 90
  
  # 로테이션 람다 설정
  rotation_lambda_arn = module.rotation_lambda[var.secret_type].function_arn
  
  # 로테이션 실패시 알림
  rotation_failure_alarm_enabled = true
  alarm_actions = [module.security_alerts.topic_arn]
}
```

### 접근 제어

```hcl
module "access_controlled_secret" {
  source = "../../modules/security/secrets-manager"
  
  # 최소 권한 정책
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            module.app_role.role_arn
          ]
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          DateLessThan = {
            "aws:CurrentTime" = "2025-12-31T23:59:59Z"  # 만료 날짜
          }
        }
      }
    ]
  })
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "ResourceExistsException"

```hcl
# 해결책: 기존 시크릿 확인 후 업데이트
data "aws_secretsmanager_secret" "existing" {
  name = var.secret_name
  
  lifecycle {
    ignore_changes = [name]
  }
}

module "existing_or_new_secret" {
  source = "../../modules/security/secrets-manager"
  
  secret_name = var.secret_name
  force_overwrite_replica_secret = true
}
```

#### 2. "InvalidParameterException" (로테이션)

```hcl
# 해결책: 로테이션 함수 권한 확인
resource "aws_lambda_permission" "allow_secretsmanager" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}
```

#### 3. "AccessDenied" (KMS)

```hcl
# 해결책: KMS 키 정책에 Secrets Manager 권한 추가
resource "aws_kms_key_policy" "secrets_policy" {
  key_id = aws_kms_key.secrets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 제한 사항

- 시크릿 값 크기 최대 64KB
- 리전당 최대 500,000개 시크릿
- 시크릿 이름 최대 512자
- 로테이션 간격 최소 1일
- 복제본은 최대 5개 리전
- 리소스 정책 크기 최대 20KB

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.