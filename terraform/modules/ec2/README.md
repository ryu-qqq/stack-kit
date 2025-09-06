# EC2 모듈

AWS EC2 인스턴스와 관련 리소스를 생성하는 Terraform 모듈입니다.

## 기능

- EC2 인스턴스 생성 및 관리
- Auto Scaling Group 지원
- Security Group 자동 생성 또는 기존 사용
- EBS 볼륨 암호화 및 추가 볼륨 지원
- Elastic IP 할당
- User Data 스크립트 지원

## 사용법

### 기본 사용
```hcl
module "web_server" {
  source = "../../modules/ec2"
  
  project_name  = "my-app"
  environment   = "dev"
  instance_name = "web-server"
  instance_type = "t3.micro"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 고급 설정 (Auto Scaling)
```hcl
module "web_cluster" {
  source = "../../modules/ec2"
  
  project_name  = "my-app"
  environment   = "prod"
  instance_name = "web-cluster"
  instance_type = "t3.medium"
  instance_count = 3  # Auto Scaling Group 생성
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 보안 그룹 설정
  create_security_group = true
  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["10.0.0.0/16"]  # VPC 내부만
      security_groups = []
      description     = "HTTP from VPC"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["10.0.0.0/16"]
      security_groups = []
      description     = "HTTPS from VPC"
    }
  ]
  
  # 스토리지 설정
  root_volume_type = "gp3"
  root_volume_size = 50
  enable_encryption = true
  
  additional_ebs_volumes = [
    {
      device_name = "/dev/xvdf"
      volume_type = "gp3"
      volume_size = 100
    }
  ]
  
  # User Data 스크립트
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    environment = var.environment
  }))
  
  common_tags = local.common_tags
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `instance_name` | 인스턴스 이름 | `string` | - | ✅ |
| `instance_count` | 생성할 인스턴스 개수 | `number` | `1` | ❌ |
| `instance_type` | EC2 인스턴스 타입 | `string` | `"t3.micro"` | ❌ |
| `ami_id` | AMI ID (비워두면 Amazon Linux 2 최신) | `string` | `""` | ❌ |
| `key_name` | SSH 키 페어 이름 | `string` | `null` | ❌ |
| `vpc_id` | VPC ID | `string` | - | ✅ |
| `subnet_ids` | 서브넷 ID 리스트 | `list(string)` | - | ✅ |
| `security_group_ids` | 기존 보안 그룹 ID 리스트 | `list(string)` | `[]` | ❌ |
| `create_security_group` | 보안 그룹 생성 여부 | `bool` | `true` | ❌ |
| `ingress_rules` | Security Group Ingress 규칙 | `list(object)` | SSH 기본값 | ❌ |
| `associate_public_ip` | Public IP 할당 여부 | `bool` | `false` | ❌ |
| `create_eip` | Elastic IP 생성 여부 | `bool` | `false` | ❌ |
| `user_data` | User data 스크립트 | `string` | `null` | ❌ |
| `root_volume_type` | 루트 볼륨 타입 | `string` | `"gp3"` | ❌ |
| `root_volume_size` | 루트 볼륨 크기 (GB) | `number` | `20` | ❌ |
| `enable_encryption` | EBS 볼륨 암호화 활성화 | `bool` | `true` | ❌ |
| `additional_ebs_volumes` | 추가 EBS 볼륨 설정 | `list(object)` | `[]` | ❌ |
| `common_tags` | 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `instance_ids` | EC2 인스턴스 ID 리스트 | `list(string)` |
| `private_ips` | 프라이빗 IP 리스트 | `list(string)` |
| `public_ips` | 퍼블릭 IP 리스트 | `list(string)` |
| `elastic_ips` | Elastic IP 리스트 | `list(string)` |
| `security_group_id` | 생성된 보안 그룹 ID | `string` |
| `launch_template_id` | Launch Template ID (ASG 사용시) | `string` |
| `auto_scaling_group_arn` | Auto Scaling Group ARN | `string` |

## 예제

### 단일 웹 서버
```hcl
module "single_web_server" {
  source = "../../modules/ec2"
  
  project_name  = "blog"
  environment   = "dev"
  instance_name = "blog-server"
  instance_type = "t3.small"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = [module.vpc.public_subnet_ids[0]]
  
  # SSH + HTTP/HTTPS 허용
  create_security_group = true
  ingress_rules = [
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]  # ALLOW_PUBLIC_EXEMPT
      security_groups = []
      description     = "SSH access"
    },
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]  # ALLOW_PUBLIC_EXEMPT
      security_groups = []
      description     = "HTTP access"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]  # ALLOW_PUBLIC_EXEMPT
      security_groups = []
      description     = "HTTPS access"
    }
  ]
  
  # 퍼블릭 IP 할당
  associate_public_ip = true
  create_eip = true
  
  # 웹 서버 초기 설정
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from ${var.environment}!</h1>" > /var/www/html/index.html
  EOF
  )
  
  common_tags = {
    Project     = "blog"
    Environment = "dev"
    Purpose     = "web-server"
  }
}
```

### Auto Scaling 웹 클러스터
```hcl
module "web_cluster" {
  source = "../../modules/ec2"
  
  project_name  = "e-commerce"
  environment   = "prod"
  instance_name = "web-cluster"
  instance_type = "t3.large"
  instance_count = 3  # ASG 생성 트리거
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids  # 프라이빗 서브넷 사용
  
  # ALB에서 접근하는 보안 그룹
  create_security_group = true
  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [var.alb_security_group_id]
      description     = "HTTP from ALB"
    }
  ]
  
  # 고성능 스토리지
  root_volume_type = "gp3"
  root_volume_size = 100
  
  additional_ebs_volumes = [
    {
      device_name = "/dev/xvdf"
      volume_type = "gp3"
      volume_size = 200  # 애플리케이션 데이터용
    }
  ]
  
  # 애플리케이션 배포 스크립트
  user_data = base64encode(templatefile("${path.module}/deploy-app.sh", {
    app_version = var.app_version
    environment = var.environment
    db_endpoint = module.database.endpoint
  }))
  
  common_tags = {
    Project     = "e-commerce"
    Environment = "prod"
    Component   = "web-tier"
    Backup      = "required"
  }
}
```

### 데이터베이스 서버
```hcl
module "db_server" {
  source = "../../modules/ec2"
  
  project_name  = "analytics"
  environment   = "staging" 
  instance_name = "db-server"
  instance_type = "r5.xlarge"  # 메모리 최적화
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 데이터베이스 포트만 허용
  create_security_group = true
  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.app_servers.security_group_id]
      description     = "PostgreSQL from app servers"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [var.bastion_security_group_id]
      description     = "SSH from bastion"
    }
  ]
  
  # 대용량 스토리지
  root_volume_type = "gp3"
  root_volume_size = 50
  
  additional_ebs_volumes = [
    {
      device_name = "/dev/xvdf"
      volume_type = "io2"      # 고성능 IOPS
      volume_size = 500        # 데이터베이스 데이터용
    },
    {
      device_name = "/dev/xvdg"
      volume_type = "gp3"
      volume_size = 200        # 백업용
    }
  ]
  
  # PostgreSQL 설치 및 설정
  user_data = base64encode(file("${path.module}/setup-postgresql.sh"))
  
  common_tags = {
    Project      = "analytics"
    Environment  = "staging"
    Component    = "database"
    CriticalData = "yes"
  }
}
```

## 보안 권장사항

### 1. 네트워크 보안
```hcl
# ✅ 좋은 예: 프라이빗 서브넷 + 제한적 접근
module "secure_app" {
  source = "../../modules/ec2"
  
  subnet_ids = module.vpc.private_subnet_ids  # 프라이빗 서브넷 사용
  
  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [module.alb.security_group_id]  # ALB에서만
      cidr_blocks     = []
      description     = "HTTP from ALB only"
    }
  ]
}

# ❌ 피해야 할 예: 전체 인터넷 노출
# ingress_rules = [
#   {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]  # 위험!
#   }
# ]
```

### 2. 스토리지 암호화
```hcl
module "secure_storage" {
  source = "../../modules/ec2"
  
  # 모든 볼륨 암호화
  enable_encryption = true
  
  additional_ebs_volumes = [
    {
      device_name = "/dev/xvdf"
      volume_type = "gp3"
      volume_size = 100
      encrypted   = true  # 명시적 암호화
    }
  ]
}
```

## 성능 최적화

### 인스턴스 타입 선택 가이드
```hcl
# 웹 서버 (CPU 집약적)
instance_type = "c5.large"

# 데이터베이스 (메모리 집약적)  
instance_type = "r5.xlarge"

# 범용 (균형잡힌 성능)
instance_type = "t3.medium"

# 버스트 가능 (가변 워크로드)
instance_type = "t3.micro"  # 개발용
```

### 환경별 최적화
```hcl
locals {
  instance_config = {
    dev = {
      type = "t3.micro"
      count = 1
      storage = 20
    }
    staging = {
      type = "t3.small" 
      count = 2
      storage = 50
    }
    prod = {
      type = "t3.medium"
      count = 3
      storage = 100
    }
  }
}

module "optimized_instances" {
  source = "../../modules/ec2"
  
  instance_type  = local.instance_config[var.environment].type
  instance_count = local.instance_config[var.environment].count
  root_volume_size = local.instance_config[var.environment].storage
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "InvalidKeyPair.NotFound"
```hcl
# 해결책: 유효한 키 페어 확인
data "aws_key_pair" "existing" {
  key_name = "my-key-pair"
}

module "ec2" {
  key_name = data.aws_key_pair.existing.key_name
}
```

#### 2. "InvalidGroup.NotFound"
```hcl
# 해결책: VPC ID와 보안 그룹이 같은 VPC인지 확인
module "ec2" {
  vpc_id = module.vpc.vpc_id
  security_group_ids = [aws_security_group.app.id]  # 같은 VPC
}
```

#### 3. "InsufficientInstanceCapacity"
```hcl
# 해결책: 여러 가용영역 사용
module "ec2" {
  subnet_ids = module.vpc.private_subnet_ids  # 여러 서브넷
  instance_type = "t3.small"  # 더 작은 인스턴스 타입
}
```

## 제약사항

- 최대 10개 인스턴스까지 지원
- Auto Scaling Group은 인스턴스 개수가 2개 이상일 때만 생성
- 추가 EBS 볼륨은 인스턴스당 최대 5개까지

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0