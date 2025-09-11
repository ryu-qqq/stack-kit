# IAM 모듈

AWS IAM (Identity and Access Management) 역할, 정책, 사용자 및 그룹을 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- IAM 역할 및 신뢰 정책 생성
- IAM 정책 생성 및 연결
- IAM 사용자 및 그룹 관리
- 인스턴스 프로필 생성
- 서비스 연결 역할 지원
- 크로스 계정 액세스 설정
- 정책 템플릿 및 조건부 액세스
- 최소 권한 원칙 적용
- 정책 문서 자동 생성

## 사용법

### 기본 사용 (서비스 역할)

```hcl
module "app_service_role" {
  source = "../../modules/security/iam"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 역할 생성
  create_role = true
  role_name   = "app-service-role"
  role_description = "Service role for application EC2 instances"
  
  # 신뢰 관계 설정
  trusted_service_principals = [
    "ec2.amazonaws.com"
  ]
  
  # 관리형 정책 연결
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  # 커스텀 인라인 정책
  inline_policies = [
    {
      name = "custom-app-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue"
            ]
            Resource = [
              "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
            ]
          }
        ]
      })
    }
  ]
  
  # 인스턴스 프로필 생성
  create_instance_profile = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "service-role"
  }
}
```

### 고급 설정 (Lambda 실행 역할)

```hcl
module "lambda_execution_role" {
  source = "../../modules/security/iam"
  
  project_name = "serverless-app"
  environment  = "prod"
  
  # Lambda 실행 역할
  create_role = true
  role_name   = "lambda-execution-role"
  role_description = "Execution role for Lambda functions"
  
  # Lambda 서비스 신뢰
  trusted_service_principals = [
    "lambda.amazonaws.com"
  ]
  
  # 기본 Lambda 실행 역할
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  
  # VPC Lambda인 경우 추가
  vpc_lambda_policy = var.lambda_in_vpc
  
  # 커스텀 정책들
  inline_policies = [
    {
      name = "dynamodb-access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:DeleteItem",
              "dynamodb:Query",
              "dynamodb:Scan"
            ]
            Resource = [
              module.app_table.table_arn,
              "${module.app_table.table_arn}/index/*"
            ]
          }
        ]
      })
    },
    {
      name = "sqs-access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "sqs:ReceiveMessage",
              "sqs:DeleteMessage",
              "sqs:GetQueueAttributes"
            ]
            Resource = module.task_queue.queue_arn
          }
        ]
      })
    }
  ]
  
  # 조건부 액세스
  assume_role_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  ]
  
  common_tags = {
    Project = "serverless-app"
    Environment = "prod"
    Component = "lambda"
  }
}
```

### 크로스 계정 액세스 역할

```hcl
module "cross_account_role" {
  source = "../../modules/security/iam"
  
  project_name = "shared-services"
  environment  = "prod"
  
  create_role = true
  role_name   = "cross-account-access"
  role_description = "Role for cross-account access from dev/staging accounts"
  
  # 다른 AWS 계정에서 assume 허용
  trusted_aws_principals = [
    "arn:aws:iam::123456789012:root",  # 개발 계정
    "arn:aws:iam::210987654321:root"   # 스테이징 계정
  ]
  
  # MFA 조건 추가
  assume_role_conditions = [
    {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    },
    {
      test     = "NumericLessThan"
      variable = "aws:MultiFactorAuthAge"
      values   = ["3600"]  # 1시간
    }
  ]
  
  # 제한된 권한만 부여
  inline_policies = [
    {
      name = "read-only-access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:ListBucket"
            ]
            Resource = [
              module.shared_bucket.bucket_arn,
              "${module.shared_bucket.bucket_arn}/*"
            ]
          }
        ]
      })
    }
  ]
  
  # 세션 제한
  max_session_duration = 3600  # 1시간
  
  common_tags = {
    Project = "shared-services"
    Environment = "prod"
    AccessType = "cross-account"
  }
}
```

### 사용자 및 그룹 관리

```hcl
module "developer_access" {
  source = "../../modules/security/iam"
  
  project_name = "development"
  environment  = "dev"
  
  # 개발자 그룹 생성
  create_group = true
  group_name   = "developers"
  group_path   = "/teams/"
  
  # 그룹 정책
  group_policies = [
    {
      name = "developer-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ec2:Describe*",
              "s3:ListBucket",
              "s3:GetObject",
              "logs:Describe*",
              "logs:Get*"
            ]
            Resource = "*"
          },
          {
            Effect = "Allow"
            Action = [
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::dev-*/*"
          }
        ]
      })
    }
  ]
  
  # 개별 사용자 생성
  create_users = true
  users = [
    {
      name = "developer1"
      path = "/teams/backend/"
      groups = ["developers"]
      tags = {
        Team = "backend"
        Level = "senior"
      }
    },
    {
      name = "developer2"
      path = "/teams/frontend/"
      groups = ["developers"]
      tags = {
        Team = "frontend"
        Level = "junior"
      }
    }
  ]
  
  # 액세스 키 생성 (선택적)
  create_access_keys = false  # 보안상 권장하지 않음
  
  common_tags = {
    Project = "development"
    Environment = "dev"
    UserType = "developer"
  }
}
```

### 정책 템플릿 사용

```hcl
module "service_policies" {
  source = "../../modules/security/iam"
  
  project_name = "microservices"
  environment  = "prod"
  
  # 정책 템플릿 활성화
  use_policy_templates = true
  
  # S3 액세스 정책 템플릿
  s3_access_policy = {
    enabled = true
    buckets = [
      module.app_bucket.bucket_name,
      module.backup_bucket.bucket_name
    ]
    permissions = ["read", "write"]
    conditions = [
      {
        test     = "StringEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      }
    ]
  }
  
  # DynamoDB 액세스 정책 템플릿
  dynamodb_access_policy = {
    enabled = true
    tables = [
      module.user_table.table_name,
      module.session_table.table_name
    ]
    permissions = ["read", "write"]
    conditions = []
  }
  
  # SNS/SQS 액세스 정책 템플릿
  messaging_access_policy = {
    enabled = true
    sns_topics = [module.notification_topic.topic_arn]
    sqs_queues = [module.task_queue.queue_arn]
    permissions = ["publish", "consume"]
  }
  
  common_tags = {
    Project = "microservices"
    Environment = "prod"
    PolicyType = "template-based"
  }
}
```

### 환경별 권한 관리

```hcl
locals {
  permission_config = {
    dev = {
      allow_console_access = true
      allow_resource_creation = true
      allow_deletion = true
      session_duration = 43200  # 12시간
    }
    staging = {
      allow_console_access = true
      allow_resource_creation = false
      allow_deletion = false
      session_duration = 14400  # 4시간
    }
    prod = {
      allow_console_access = false
      allow_resource_creation = false
      allow_deletion = false
      session_duration = 3600   # 1시간
    }
  }
}

module "environment_role" {
  source = "../../modules/security/iam"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  create_role = true
  role_name   = "app-role-${var.environment}"
  
  # 환경별 세션 제한
  max_session_duration = local.permission_config[var.environment].session_duration
  
  # 환경별 정책
  inline_policies = [
    {
      name = "environment-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = concat(
          [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:ListBucket"
              ]
              Resource = "*"
            }
          ],
          local.permission_config[var.environment].allow_resource_creation ? [
            {
              Effect = "Allow"
              Action = [
                "ec2:RunInstances",
                "ec2:CreateTags"
              ]
              Resource = "*"
            }
          ] : [],
          local.permission_config[var.environment].allow_deletion ? [
            {
              Effect = "Allow"
              Action = [
                "ec2:TerminateInstances",
                "s3:DeleteObject"
              ]
              Resource = "*"
            }
          ] : []
        )
      })
    }
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
| `create_role` | IAM 역할 생성 여부 | `bool` | `false` | ❌ |
| `role_name` | IAM 역할 이름 | `string` | `null` | ❌ |
| `role_description` | IAM 역할 설명 | `string` | `null` | ❌ |
| `trusted_service_principals` | 신뢰하는 서비스 주체 리스트 | `list(string)` | `[]` | ❌ |
| `trusted_aws_principals` | 신뢰하는 AWS 주체 리스트 | `list(string)` | `[]` | ❌ |
| `managed_policy_arns` | 연결할 관리형 정책 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `inline_policies` | 인라인 정책 리스트 | `list(object)` | `[]` | ❌ |
| `assume_role_conditions` | 역할 가정 조건 | `list(object)` | `[]` | ❌ |
| `max_session_duration` | 최대 세션 지속 시간 (초) | `number` | `3600` | ❌ |
| `create_instance_profile` | 인스턴스 프로필 생성 여부 | `bool` | `false` | ❌ |
| `create_group` | IAM 그룹 생성 여부 | `bool` | `false` | ❌ |
| `group_name` | IAM 그룹 이름 | `string` | `null` | ❌ |
| `create_users` | IAM 사용자 생성 여부 | `bool` | `false` | ❌ |
| `users` | 생성할 사용자 리스트 | `list(object)` | `[]` | ❌ |
| `use_policy_templates` | 정책 템플릿 사용 여부 | `bool` | `false` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `role_arn` | IAM 역할 ARN | `string` |
| `role_name` | IAM 역할 이름 | `string` |
| `role_unique_id` | IAM 역할 고유 ID | `string` |
| `instance_profile_arn` | 인스턴스 프로필 ARN | `string` |
| `instance_profile_name` | 인스턴스 프로필 이름 | `string` |
| `group_arn` | IAM 그룹 ARN | `string` |
| `group_name` | IAM 그룹 이름 | `string` |
| `user_arns` | 생성된 사용자 ARN 리스트 | `list(string)` |
| `policy_arns` | 생성된 정책 ARN 리스트 | `list(string)` |

## 모범 사례

### 최소 권한 원칙

```hcl
# ✅ 좋은 예: 구체적이고 제한된 권한
module "secure_role" {
  source = "../../modules/security/iam"
  
  inline_policies = [
    {
      name = "specific-s3-access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject"
            ]
            Resource = [
              "arn:aws:s3:::my-specific-bucket/readonly/*"
            ]
            Condition = {
              StringEquals = {
                "s3:x-amz-server-side-encryption" = "aws:kms"
              }
            }
          }
        ]
      })
    }
  ]
}

# ❌ 피해야 할 예: 과도한 권한
# Action = ["*"]
# Resource = ["*"]
# Principal = "*"
```

### 조건부 액세스

```hcl
module "conditional_access_role" {
  source = "../../modules/security/iam"
  
  # MFA 필수
  assume_role_conditions = [
    {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    },
    {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = ["203.0.113.0/24"]  # 회사 IP 대역
    },
    {
      test     = "DateGreaterThan"
      variable = "aws:RequestedDate"
      values   = ["2024-01-01T00:00:00Z"]
    }
  ]
}
```

### 역할 분리

```hcl
# 읽기 전용 역할
module "readonly_role" {
  source = "../../modules/security/iam"
  
  role_name = "readonly-access"
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
}

# 개발자 역할 (제한적 쓰기)
module "developer_role" {
  source = "../../modules/security/iam"
  
  role_name = "developer-access"
  
  inline_policies = [
    {
      name = "dev-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["*"]
            Resource = "*"
            Condition = {
              StringLike = {
                "aws:ResourceTag/Environment" = "dev"
              }
            }
          }
        ]
      })
    }
  ]
}

# 관리자 역할 (프로덕션 제외)
module "admin_role" {
  source = "../../modules/security/iam"
  
  role_name = "admin-access"
  
  inline_policies = [
    {
      name = "admin-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["*"]
            Resource = "*"
          },
          {
            Effect = "Deny"
            Action = ["*"]
            Resource = "*"
            Condition = {
              StringEquals = {
                "aws:ResourceTag/Environment" = "prod"
              }
            }
          }
        ]
      })
    }
  ]
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "InvalidUserType" (사용자 유형 오류)

```hcl
# 해결책: 서비스 계정은 역할 사용
module "service_role" {
  source = "../../modules/security/iam"
  
  create_role = true  # 사용자 대신 역할 사용
  trusted_service_principals = ["ec2.amazonaws.com"]
}
```

#### 2. "AccessDenied" (권한 부족)

```hcl
# 해결책: 필요한 권한 명시적 부여
module "role_with_permissions" {
  source = "../../modules/security/iam"
  
  inline_policies = [
    {
      name = "required-permissions"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "iam:PassRole"  # 역할을 다른 서비스에 전달하려면 필요
            ]
            Resource = "*"
          }
        ]
      })
    }
  ]
}
```

#### 3. "MalformedPolicyDocument"

```hcl
# 해결책: 올바른 JSON 형식 사용
module "valid_policy_role" {
  source = "../../modules/security/iam"
  
  inline_policies = [
    {
      name = "valid-policy"
      policy = jsonencode({  # jsonencode 사용
        Version = "2012-10-17"  # 올바른 버전
        Statement = [
          {
            Effect   = "Allow"     # 대문자 사용
            Action   = ["s3:GetObject"]
            Resource = ["arn:aws:s3:::bucket/*"]
          }
        ]
      })
    }
  ]
}
```

## 제한 사항

- 계정당 최대 5,000개 역할
- 계정당 최대 5,000개 사용자
- 계정당 최대 300개 그룹
- 역할/사용자당 최대 10개 관리형 정책
- 인라인 정책 크기 최대 2,048자
- 역할 세션 이름 최대 64자

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.