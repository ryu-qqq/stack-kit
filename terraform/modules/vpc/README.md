# VPC 모듈

AWS VPC와 관련 네트워킹 리소스를 생성하는 Terraform 모듈입니다.

## 기능

- VPC 생성
- 퍼블릭/프라이빗 서브넷 생성
- Internet Gateway 및 NAT Gateway 설정
- 라우팅 테이블 및 연결
- 기본 보안 그룹 설정

## 사용법

### 기본 사용
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 고급 설정
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "prod"
  vpc_cidr     = "10.0.0.0/16"
  
  # Multi-AZ 설정
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  
  # NAT Gateway 설정
  enable_nat_gateway = true
  single_nat_gateway = false  # 각 AZ에 NAT Gateway 생성
  
  common_tags = {
    Project     = "my-app"
    Environment = "prod"
    Owner       = "platform"
    CostCenter  = "engineering"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `vpc_cidr` | VPC CIDR 블록 | `string` | `"10.0.0.0/16"` | ❌ |
| `public_subnet_cidrs` | 퍼블릭 서브넷 CIDR 리스트 | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | ❌ |
| `private_subnet_cidrs` | 프라이빗 서브넷 CIDR 리스트 | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24"]` | ❌ |
| `enable_nat_gateway` | NAT Gateway 활성화 여부 | `bool` | `true` | ❌ |
| `single_nat_gateway` | 단일 NAT Gateway 사용 여부 | `bool` | `false` | ❌ |
| `common_tags` | 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `vpc_id` | VPC ID | `string` |
| `vpc_cidr_block` | VPC CIDR 블록 | `string` |
| `public_subnet_ids` | 퍼블릭 서브넷 ID 리스트 | `list(string)` |
| `private_subnet_ids` | 프라이빗 서브넷 ID 리스트 | `list(string)` |
| `internet_gateway_id` | Internet Gateway ID | `string` |
| `nat_gateway_ids` | NAT Gateway ID 리스트 | `list(string)` |
| `public_route_table_id` | 퍼블릭 라우팅 테이블 ID | `string` |
| `private_route_table_ids` | 프라이빗 라우팅 테이블 ID 리스트 | `list(string)` |
| `default_security_group_id` | 기본 보안 그룹 ID | `string` |

## 예제

### 개발 환경 (비용 최적화)
```hcl
module "vpc_dev" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 작은 서브넷 사용
  public_subnet_cidrs  = ["10.0.1.0/26"]    # /26 = 64 IP
  private_subnet_cidrs = ["10.0.2.0/26"]
  
  # 단일 NAT Gateway로 비용 절약
  enable_nat_gateway = true
  single_nat_gateway = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    CostCenter  = "development"
  }
}
```

### 프로덕션 환경 (고가용성)
```hcl
module "vpc_prod" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "prod"
  
  # Multi-AZ 설정
  public_subnet_cidrs = [
    "10.0.1.0/24",  # ap-northeast-2a
    "10.0.2.0/24",  # ap-northeast-2b
    "10.0.3.0/24"   # ap-northeast-2c
  ]
  
  private_subnet_cidrs = [
    "10.0.11.0/24",  # ap-northeast-2a
    "10.0.12.0/24",  # ap-northeast-2b
    "10.0.13.0/24"   # ap-northeast-2c
  ]
  
  # 각 AZ별 NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = false
  
  common_tags = {
    Project      = "my-app"
    Environment  = "prod"
    CriticalData = "yes"
    Backup       = "required"
  }
}
```

### 다른 모듈과 함께 사용
```hcl
# VPC 생성
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "web-app"
  environment  = "staging"
  
  common_tags = local.common_tags
}

# VPC를 사용하는 RDS
module "database" {
  source = "../../modules/rds"
  
  project_name = "web-app"
  environment  = "staging"
  
  # VPC 출력을 입력으로 사용
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  allowed_security_groups = [module.vpc.default_security_group_id]
  
  common_tags = local.common_tags
}

# VPC를 사용하는 EC2
module "web_servers" {
  source = "../../modules/ec2"
  
  project_name = "web-app"
  environment  = "staging"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  common_tags = local.common_tags
}
```

## 네트워크 아키텍처

### 기본 구조
```
VPC (10.0.0.0/16)
├── Internet Gateway
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── NAT Gateway 1 (AZ-a)
│   └── NAT Gateway 2 (AZ-c) [optional]
├── Private Subnets (10.0.11.0/24, 10.0.12.0/24)
│   ├── Route to NAT Gateway 1
│   └── Route to NAT Gateway 2 [optional]
└── Route Tables
    ├── Public Route Table → Internet Gateway
    └── Private Route Tables → NAT Gateways
```

### 보안 고려사항
- 프라이빗 서브넷은 NAT Gateway를 통해서만 인터넷 접근
- 기본 보안 그룹은 VPC 내부 통신만 허용
- 각 서브넷은 서로 다른 가용영역에 배치

## 제약사항

- 최소 1개, 최대 6개의 퍼블릭/프라이빗 서브넷 지원
- 서브넷은 사용 가능한 가용영역 순서대로 배치
- NAT Gateway는 퍼블릭 서브넷에만 생성 가능

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.