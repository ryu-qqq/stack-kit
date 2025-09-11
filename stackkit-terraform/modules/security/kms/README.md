# KMS 모듈

AWS KMS (Key Management Service)를 사용한 암호화 키 생성 및 관리를 위한 Terraform 모듈입니다.

## 기능

- 고객 관리형 KMS 키 생성
- 키 별칭 및 설명 관리
- 자동 키 로테이션 설정
- 다중 리전 키 지원
- 키 정책 및 권한 관리
- 키 사용자 및 관리자 설정
- 서비스 주체 권한 부여
- 교차 계정 액세스
- Grant 기반 권한 관리
- CloudWatch 모니터링 및 알람

## 사용법

### 기본 사용 (대칭 키)

```hcl
module "app_encryption_key" {
  source = "../../modules/security/kms"
  
  project_name = "my-app"
  environment  = "dev"
  
  key_name    = "app-data-encryption"
  description = "Encryption key for application data"
  
  # 키 설정
  key_usage            = "ENCRYPT_DECRYPT"
  key_spec             = "SYMMETRIC_DEFAULT"
  enable_key_rotation  = true
  
  # 권한 설정
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AdminRole"
  ]
  
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AppRole",
    module.app_instance_profile.arn
  ]
  
  # 서비스 권한
  service_principals = [
    "s3.amazonaws.com",
    "rds.amazonaws.com",
    "secretsmanager.amazonaws.com"
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "encryption"
  }
}
```

### 고급 설정 (비대칭 키 및 서명)

```hcl
module "signing_key" {
  source = "../../modules/security/kms"
  
  project_name = "digital-signing"
  environment  = "prod"
  
  key_name    = "document-signing"
  description = "Key for digital document signing"
  
  # 비대칭 키 설정 (서명용)
  key_usage = "SIGN_VERIFY"
  key_spec  = "RSA_2048"
  
  # 로테이션 비활성화 (비대칭 키는 로테이션 미지원)
  enable_key_rotation = false
  
  # 삭제 보호 강화
  deletion_window_in_days = 30
  
  # 커스텀 키 정책
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Signing Service"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.signing_service.arn
        }
        Action = [
          "kms:Sign",
          "kms:Verify",
          "kms:GetPublicKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  # 모니터링 활성화
  create_cloudwatch_alarms = true
  usage_alarm_threshold   = 1000
  alarm_actions = [module.security_alerts.topic_arn]
  
  common_tags = {
    Project = "digital-signing"
    Environment = "prod"
    KeyType = "signing"
    Compliance = "required"
  }
}
```

### 다중 리전 키

```hcl
module "global_encryption_key" {
  source = "../../modules/security/kms"
  
  project_name = "global-app"
  environment  = "prod"
  
  key_name    = "global-encryption"
  description = "Multi-region encryption key for global application"
  
  # 다중 리전 키 설정
  multi_region = true
  
  # 키 관리자 (모든 리전에서 동일)
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GlobalAdminRole"
  ]
  
  # 글로벌 서비스 권한
  service_principals = [
    "s3.amazonaws.com",
    "dynamodb.amazonaws.com"
  ]
  
  # 리전별 조건 추가
  service_principal_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  ]
  
  common_tags = {
    Project = "global-app"
    Environment = "prod"
    Scope = "multi-region"
  }
}
```

### 교차 계정 키 공유

```hcl
module "shared_encryption_key" {
  source = "../../modules/security/kms"
  
  project_name = "shared-services"
  environment  = "prod"
  
  key_name    = "cross-account-encryption"
  description = "Shared encryption key for cross-account access"
  
  # 기본 권한 설정
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KeyAdminRole"
  ]
  
  # 교차 계정 주체
  cross_account_principals = [
    "arn:aws:iam::123456789012:root",  # 개발 계정
    "arn:aws:iam::210987654321:root"   # 스테이징 계정
  ]
  
  # Grant 기반 권한 부여
  grants = [
    {
      name              = "dev-account-grant"
      grantee_principal = "arn:aws:iam::123456789012:role/DevAppRole"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = {
        encryption_context_equals = {
          Department = "Development"
          Project    = "shared-services"
        }
      }
    },
    {
      name              = "staging-account-grant"
      grantee_principal = "arn:aws:iam::210987654321:role/StagingAppRole"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey", "ReEncrypt"]
      constraints = {
        encryption_context_subset = {
          Environment = "staging"
        }
      }
    }
  ]
  
  common_tags = {
    Project = "shared-services"
    Environment = "prod"
    Access = "cross-account"
  }
}
```

### 서비스별 전용 키

```hcl
locals {
  services = {
    "s3" = {
      description = "S3 bucket encryption"
      services    = ["s3.amazonaws.com"]
      usage_threshold = 10000
    }
    "rds" = {
      description = "RDS database encryption"  
      services    = ["rds.amazonaws.com"]
      usage_threshold = 1000
    }
    "secrets" = {
      description = "Secrets Manager encryption"
      services    = ["secretsmanager.amazonaws.com"]
      usage_threshold = 100
    }
  }
}

module "service_keys" {
  for_each = local.services
  source   = "../../modules/security/kms"
  
  project_name = "enterprise-app"
  environment  = "prod"
  
  key_name    = "${each.key}-encryption"
  description = each.value.description
  
  # 서비스별 권한
  service_principals = each.value.services
  
  # 공통 관리자
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SecurityTeamRole"
  ]
  
  # 애플리케이션 역할
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AppRole"
  ]
  
  # 서비스별 모니터링
  create_cloudwatch_alarms = true
  usage_alarm_threshold   = each.value.usage_threshold
  alarm_actions = [module.security_monitoring.topic_arn]
  
  common_tags = {
    Project = "enterprise-app"
    Environment = "prod"
    Service = each.key
  }
}
```

### 로깅 및 모니터링 강화

```hcl
module "monitored_key" {
  source = "../../modules/security/kms"
  
  project_name = "security-critical"
  environment  = "prod"
  
  key_name    = "critical-data-encryption"
  description = "Encryption key for critical security data"
  
  # 강화된 모니터링
  enable_logging           = true
  log_retention_in_days   = 365
  create_cloudwatch_alarms = true
  create_dashboard        = true
  
  # 낮은 임계값으로 사용량 모니터링
  usage_alarm_threshold = 50
  alarm_actions = [
    module.security_alerts.topic_arn,
    module.security_escalation.topic_arn
  ]
  
  # 보안팀 전용 관리
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SecurityAdminRole"
  ]
  
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/CriticalAppRole"
  ]
  
  # 엄격한 삭제 보호
  deletion_window_in_days = 30
  
  common_tags = {
    Project = "security-critical"
    Environment = "prod"
    DataClassification = "confidential"
    MonitoringLevel = "high"
  }
}
```

### 환경별 키 관리

```hcl
locals {
  kms_config = {
    dev = {
      key_rotation       = false
      deletion_window   = 7
      multi_region      = false
      monitoring        = false
      log_retention     = 7
    }
    staging = {
      key_rotation       = true
      deletion_window   = 14
      multi_region      = false
      monitoring        = true
      log_retention     = 30
    }
    prod = {
      key_rotation       = true
      deletion_window   = 30
      multi_region      = true
      monitoring        = true
      log_retention     = 365
    }
  }
}

module "environment_key" {
  source = "../../modules/security/kms"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  key_name = "app-encryption-${var.environment}"
  
  # 환경별 동적 설정
  enable_key_rotation     = local.kms_config[var.environment].key_rotation
  deletion_window_in_days = local.kms_config[var.environment].deletion_window
  multi_region           = local.kms_config[var.environment].multi_region
  
  # 모니터링 설정
  create_cloudwatch_alarms = local.kms_config[var.environment].monitoring
  enable_logging          = local.kms_config[var.environment].monitoring
  log_retention_in_days   = local.kms_config[var.environment].log_retention
  
  # 환경별 권한
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${title(var.environment)}AdminRole"
  ]
  
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${title(var.environment)}AppRole"
  ]
  
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
| `key_name` | KMS 키 이름 | `string` | - | ✅ |
| `description` | KMS 키 설명 | `string` | `null` | ❌ |
| `key_usage` | 키 사용 목적 | `string` | `"ENCRYPT_DECRYPT"` | ❌ |
| `key_spec` | 키 스펙 | `string` | `"SYMMETRIC_DEFAULT"` | ❌ |
| `enable_key_rotation` | 키 로테이션 활성화 | `bool` | `true` | ❌ |
| `deletion_window_in_days` | 키 삭제 대기 기간 (일) | `number` | `7` | ❌ |
| `multi_region` | 다중 리전 키 여부 | `bool` | `false` | ❌ |
| `policy` | 커스텀 키 정책 (JSON 문자열) | `string` | `null` | ❌ |
| `key_administrators` | 키 관리자 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `key_users` | 키 사용자 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `service_principals` | 서비스 주체 리스트 | `list(string)` | `[]` | ❌ |
| `service_principal_conditions` | 서비스 주체 조건 | `list(object)` | `[]` | ❌ |
| `cross_account_principals` | 교차 계정 주체 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `grants` | KMS 권한 부여 설정 | `list(object)` | `[]` | ❌ |
| `enable_logging` | CloudWatch 로깅 활성화 | `bool` | `false` | ❌ |
| `log_retention_in_days` | 로그 보존 기간 (일) | `number` | `7` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `usage_alarm_threshold` | 사용량 알람 임계값 | `number` | `100` | ❌ |
| `create_dashboard` | CloudWatch 대시보드 생성 여부 | `bool` | `false` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `key_id` | KMS 키 ID | `string` |
| `key_arn` | KMS 키 ARN | `string` |
| `alias_name` | KMS 키 별칭 | `string` |
| `alias_arn` | KMS 키 별칭 ARN | `string` |
| `key_usage` | 키 사용 목적 | `string` |
| `key_spec` | 키 스펙 | `string` |
| `key_rotation_enabled` | 키 로테이션 활성화 여부 | `bool` |
| `multi_region` | 다중 리전 키 여부 | `bool` |
| `grant_ids` | KMS 권한 부여 ID 리스트 | `list(string)` |
| `log_group_name` | CloudWatch 로그 그룹 이름 | `string` |
| `dashboard_url` | CloudWatch 대시보드 URL | `string` |
| `key_id_for_encryption` | 암호화에 사용할 KMS 키 ID (별칭 형태) | `string` |
| `key_arn_for_iam` | IAM 정책에서 사용할 KMS 키 ARN | `string` |

## 일반적인 사용 사례

### 1. 데이터베이스 암호화

```hcl
module "database_encryption" {
  source = "../../modules/security/kms"
  
  key_name    = "database-encryption"
  description = "Encryption key for RDS databases"
  
  service_principals = [
    "rds.amazonaws.com"
  ]
  
  key_users = [
    module.app_role.arn
  ]
}

# RDS에서 사용
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id       = module.database_encryption.key_arn
}
```

### 2. 파일 저장소 암호화

```hcl
module "s3_encryption" {
  source = "../../modules/security/kms"
  
  key_name = "s3-bucket-encryption"
  
  service_principals = [
    "s3.amazonaws.com"
  ]
}

# S3 버킷에서 사용
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.s3_encryption.key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}
```

### 3. 애플리케이션 시크릿 암호화

```hcl
module "secrets_encryption" {
  source = "../../modules/security/kms"
  
  key_name = "secrets-manager-encryption"
  
  service_principals = [
    "secretsmanager.amazonaws.com"
  ]
  
  key_users = [
    module.app_execution_role.arn
  ]
}

# Secrets Manager에서 사용
resource "aws_secretsmanager_secret" "app_secrets" {
  kms_key_id = module.secrets_encryption.key_arn
}
```

## 모범 사례

### 보안 설정

```hcl
# ✅ 좋은 예: 최소 권한 원칙
module "secure_key" {
  source = "../../modules/security/kms"
  
  # 구체적인 관리자만 지정
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdminRole"
  ]
  
  # 필요한 서비스만 허용
  service_principals = [
    "s3.amazonaws.com"
  ]
  
  # 서비스 조건 추가
  service_principal_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  ]
  
  # 로테이션 활성화
  enable_key_rotation = true
  
  # 삭제 보호
  deletion_window_in_days = 30
}

# ❌ 피해야 할 예: 과도한 권한
# key_administrators = ["*"]  # 너무 광범위
# policy with "Principal": "*"  # 모든 주체 허용
```

### 키 관리 정책

```hcl
module "well_managed_key" {
  source = "../../modules/security/kms"
  
  # 명확한 명명 규칙
  key_name = "${var.project_name}-${var.environment}-${var.purpose}"
  
  # 상세한 설명
  description = "Encryption key for ${var.purpose} in ${var.environment} environment"
  
  # 환경별 로테이션 설정
  enable_key_rotation = var.environment == "prod"
  
  # 환경별 삭제 보호
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  
  # 모니터링 활성화 (프로덕션)
  create_cloudwatch_alarms = var.environment == "prod"
  
  # 태깅 전략
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = var.purpose
    Owner       = var.team_name
    CostCenter  = var.cost_center
  }
}
```

### 비용 최적화

```hcl
# 개발환경 비용 최적화
module "cost_optimized_key" {
  source = "../../modules/security/kms"
  
  # 개발환경에서는 모니터링 최소화
  create_cloudwatch_alarms = var.environment == "prod"
  enable_logging          = var.environment == "prod"
  create_dashboard        = var.environment == "prod"
  
  # 로그 보존 기간 최소화
  log_retention_in_days = var.environment == "prod" ? 365 : 7
  
  # 삭제 대기 기간 최소화 (개발)
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "AccessDenied" (키 사용 권한 부족)

```hcl
# 해결책: 적절한 키 사용자 권한 부여
module "key_with_proper_permissions" {
  source = "../../modules/security/kms"
  
  key_users = [
    aws_iam_role.app_role.arn,
    aws_iam_user.developer.arn
  ]
  
  # 또는 Grant 사용
  grants = [
    {
      name              = "app-access"
      grantee_principal = aws_iam_role.app_role.arn
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
    }
  ]
}
```

#### 2. "InvalidKeyUsage" (잘못된 키 사용)

```hcl
# 해결책: 키 사용 목적에 맞는 스펙 선택
module "encryption_key" {
  source = "../../modules/security/kms"
  
  # 암호화용 키
  key_usage = "ENCRYPT_DECRYPT"
  key_spec  = "SYMMETRIC_DEFAULT"
}

module "signing_key" {
  source = "../../modules/security/kms"
  
  # 서명용 키
  key_usage = "SIGN_VERIFY"
  key_spec  = "RSA_2048"
  
  # 비대칭 키는 로테이션 미지원
  enable_key_rotation = false
}
```

#### 3. "KMSInvalidStateException" (키 상태 오류)

```hcl
# 해결책: 키 상태 확인 후 사용
data "aws_kms_key" "existing" {
  key_id = module.my_key.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "conditional" {
  count  = data.aws_kms_key.existing.key_state == "Enabled" ? 1 : 0
  bucket = aws_s3_bucket.main.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.my_key.key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}
```

#### 4. Multi-Region 키 복제 오류

```hcl
# 해결책: 리전별 리소스 관리
module "primary_region_key" {
  source = "../../modules/security/kms"
  
  multi_region = true
  key_name    = "global-encryption"
  
  providers = {
    aws = aws.primary
  }
}

# 보조 리전에서 복제본 생성
resource "aws_kms_replica_key" "secondary" {
  description         = "Replica of global encryption key"
  primary_key_arn    = module.primary_region_key.key_arn
  deletion_window_in_days = 7
  
  provider = aws.secondary
}
```

## 제한 사항

- 리전당 최대 100,000개 키 (고객 관리형)
- 키 사용량: 초당 5,500/8,000/10,000 요청 (리전별 상이)
- 비대칭 키는 자동 로테이션 미지원
- Multi-Region 키 생성 후 리전 변경 불가
- Grant는 키당 최대 2,500개
- 키 정책 크기 최대 32KB

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.