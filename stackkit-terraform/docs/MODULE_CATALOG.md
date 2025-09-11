# StackKit Terraform 모듈 카탈로그

StackKit 인프라 패키지에서 사용 가능한 모든 Terraform 모듈의 종합 카탈로그입니다.

## 목차

- [개요](#개요)
- [모듈 카테고리](#모듈-카테고리)
- [컴퓨팅 모듈](#컴퓨팅-모듈)
  - [EC2](#ec2)
  - [ECS](#ecs)
  - [Lambda](#lambda)
- [네트워킹 모듈](#네트워킹-모듈)
  - [VPC](#vpc)
  - [Application Load Balancer](#application-load-balancer)
  - [CloudFront](#cloudfront)
  - [Route53](#route53)
- [데이터베이스 모듈](#데이터베이스-모듈)
  - [RDS](#rds)
  - [DynamoDB](#dynamodb)
  - [ElastiCache](#elasticache)
- [스토리지 모듈](#스토리지-모듈)
  - [S3](#s3)
- [보안 모듈](#보안-모듈)
  - [IAM](#iam)
  - [KMS](#kms)
  - [Secrets Manager](#secrets-manager)
- [모니터링 모듈](#모니터링-모듈)
  - [CloudWatch](#cloudwatch)
  - [SNS](#sns)
  - [EventBridge](#eventbridge)
- [통합 모듈](#통합-모듈)
  - [SQS](#sqs)
- [엔터프라이즈 모듈](#엔터프라이즈-모듈)
  - [Compliance](#compliance)
  - [Team Boundaries](#team-boundaries)
- [모듈 사용 가이드라인](#모듈-사용-가이드라인)
- [버전 호환성](#버전-호환성)

## 개요

StackKit Terraform 모듈은 AWS 인프라 구성 요소의 사전 구성된 모범 사례 구현을 제공합니다. 각 모듈은 재사용 가능하고 안전하며 AWS Well-Architected Framework 원칙을 따르도록 설계되었습니다.

### 주요 기능
- **기본 보안**: 모든 모듈은 보안 모범 사례를 구현합니다
- **비용 최적화**: 내장된 비용 관리 및 최적화 기능
- **규정 준수 지원**: 엔터프라이즈급 규정 준수 및 거버넌스 제어
- **확장 가능한 설계**: 소규모 애플리케이션부터 엔터프라이즈 워크로드까지 지원
- **포괄적인 문서화**: 상세한 예제 및 사용 가이드라인

## 모듈 카테고리

| 카테고리 | 모듈 | 목적 |
|----------|---------|---------|
| **컴퓨팅** | ec2, ecs, lambda | 애플리케이션 호스팅 및 실행 |
| **네트워킹** | vpc, alb, cloudfront, route53 | 네트워크 인프라 및 트래픽 관리 |
| **데이터베이스** | rds, dynamodb, elasticache | 데이터 저장 및 캐싱 |
| **스토리지** | s3 | 객체 저장소 및 정적 자산 |
| **보안** | iam, kms, secrets-manager | 신원, 접근 및 암호화 관리 |
| **모니터링** | cloudwatch, sns, eventbridge | 관찰성 및 이벤트 기반 아키텍처 |
| **통합** | sqs | 메시지 큐잉 및 서비스 통합 |
| **엔터프라이즈** | compliance, team-boundaries | 거버넌스 및 조직 제어 |

---

## 컴퓨팅 모듈

### EC2

**모듈 경로**: `modules/compute/ec2`

**목적**: 보안 그룹, 키 페어, 오토 스케일링 및 로드 밸런싱과 같은 선택적 기능을 포함한 EC2 인스턴스를 프로비저닝합니다.

**주요 기능**:
- 다양한 인스턴스 유형 지원
- 자동 보안 그룹 구성
- 기본적으로 EBS 볼륨 암호화
- CloudWatch 모니터링 통합
- Auto-scaling 그룹 지원
- Spot 인스턴스 지원

**필수 변수**:
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group creation"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script for instance initialization"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "enable_spot_instance" {
  description = "Use spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

**Outputs**:
```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.this.id
}
```

**Usage Example**:
```hcl
module "web_server" {
  source = "../../modules/compute/ec2"

  instance_type = "t3.medium"
  ami_id        = "ami-0abcdef1234567890"
  subnet_id     = module.vpc.private_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  key_name      = "my-key-pair"

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = "production"
  }))

  tags = {
    Name        = "web-server"
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- VPC module (for subnet_id and vpc_id)
- Optional: IAM module (for instance profiles)

---

### ECS

**Module Path**: `modules/compute/ecs`

**Purpose**: Creates ECS cluster with Fargate or EC2 launch types, including service definitions, task definitions, and load balancer integration.

**Key Features**:
- Fargate and EC2 launch type support
- Application Load Balancer integration
- Auto-scaling configuration
- Service discovery integration
- Container insights monitoring
- Blue/green deployment support

**Required Variables**:
```hcl
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "task_definition" {
  description = "Task definition configuration"
  type = object({
    family                   = string
    cpu                     = number
    memory                  = number
    container_definitions   = string
    execution_role_arn      = string
    task_role_arn          = optional(string)
  })
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS service"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
```

**Optional Variables**:
```hcl
variable "launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for the service"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "target_group_arn" {
  description = "Target group ARN for load balancer"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 80
}

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery"
  type        = bool
  default     = false
}
```

**Outputs**:
```hcl
output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}
```

**Usage Example**:
```hcl
module "api_service" {
  source = "../../modules/compute/ecs"

  cluster_name = "production-cluster"
  service_name = "api-service"

  task_definition = {
    family = "api-task"
    cpu    = 512
    memory = 1024
    container_definitions = jsonencode([
      {
        name  = "api"
        image = "myapp/api:latest"
        portMappings = [
          {
            containerPort = 8080
            hostPort      = 8080
            protocol      = "tcp"
          }
        ]
        environment = [
          {
            name  = "NODE_ENV"
            value = "production"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = "/ecs/api-service"
            "awslogs-region"        = "us-west-2"
            "awslogs-stream-prefix" = "ecs"
          }
        }
      }
    ])
    execution_role_arn = module.iam.ecs_execution_role_arn
    task_role_arn      = module.iam.ecs_task_role_arn
  }

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_group.id]
  target_group_arn   = module.alb.target_group_arn
  container_port     = 8080

  enable_auto_scaling = true
  min_capacity       = 2
  max_capacity       = 10
}
```

**Dependencies**:
- VPC module (for subnet_ids)
- IAM module (for execution and task roles)
- ALB module (for load balancing)
- CloudWatch module (for logging)

---

### Lambda

**Module Path**: `modules/compute/lambda`

**Purpose**: Creates AWS Lambda functions with associated IAM roles, CloudWatch logs, and optional API Gateway integration.

**Key Features**:
- Multiple runtime support
- Environment variable management
- VPC configuration support
- Dead letter queue integration
- X-Ray tracing support
- Provisioned concurrency options
- Layer support

**Required Variables**:
```hcl
variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Runtime for the Lambda function"
  type        = string
}

variable "handler" {
  description = "Function handler"
  type        = string
}

variable "source_code" {
  description = "Source code configuration"
  type = object({
    type = string # "zip_file", "s3_bucket", or "image_uri"
    content = optional(string) # For zip_file type
    s3_bucket = optional(string)
    s3_key = optional(string)
    s3_object_version = optional(string)
    image_uri = optional(string)
  })
}
```

**Optional Variables**:
```hcl
variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "memory_size" {
  description = "Amount of memory in MB"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 3
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for the function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions"
  type        = number
  default     = -1
}

variable "layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

variable "dead_letter_config" {
  description = "Dead letter queue configuration"
  type = object({
    target_arn = string
  })
  default = null
}
```

**Outputs**:
```hcl
output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.name
}
```

**Usage Example**:
```hcl
module "api_handler" {
  source = "../../modules/compute/lambda"

  function_name = "api-handler"
  description   = "API request handler"
  runtime       = "python3.9"
  handler       = "handler.main"
  memory_size   = 512
  timeout       = 30

  source_code = {
    type = "zip_file"
    content = data.archive_file.lambda_zip.output_base64sha256
  }

  environment_variables = {
    ENVIRONMENT = "production"
    DB_HOST     = module.rds.endpoint
    REDIS_HOST  = module.elasticache.primary_endpoint
  }

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  enable_tracing = true
  
  layers = [
    "arn:aws:lambda:us-west-2:123456789012:layer:my-python-layer:1"
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- IAM module (for execution roles)
- VPC module (if VPC configuration is used)
- CloudWatch module (for logging)

---

## Networking Modules

### VPC

**Module Path**: `modules/networking/vpc`

**Purpose**: Creates a VPC with public and private subnets, NAT gateways, internet gateway, and route tables following AWS best practices.

**Key Features**:
- Multi-AZ subnet distribution
- Public and private subnet separation
- NAT gateway for private subnet internet access
- Customizable CIDR blocks
- Flow logs integration
- VPC endpoints support
- DNS resolution enabled

**Required Variables**:
```hcl
variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}
```

**Optional Variables**:
```hcl
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN gateway"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "enable_flow_log" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_log_destination_type" {
  description = "Type of flow log destination (cloud-watch-logs or s3)"
  type        = string
  default     = "cloud-watch-logs"
}
```

**Outputs**:
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_ids" {
  description = "IDs of the public route tables"
  value       = aws_route_table.public[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}
```

**Usage Example**:
```hcl
module "vpc" {
  source = "../../modules/networking/vpc"

  name               = "production-vpc"
  cidr               = "10.0.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_log        = true

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**: None (foundational module)

---

### Application Load Balancer

**Module Path**: `modules/networking/alb`

**Purpose**: Creates an Application Load Balancer with listeners, target groups, and SSL certificate integration.

**Key Features**:
- HTTP and HTTPS listener support
- SSL/TLS certificate management
- Health check configuration
- Sticky sessions support
- WAF integration ready
- Cross-zone load balancing
- Access logging

**Required Variables**:
```hcl
variable "name" {
  description = "Name of the load balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the load balancer"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
```

**Optional Variables**:
```hcl
variable "internal" {
  description = "Create an internal load balancer"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Connection idle timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_http2" {
  description = "Enable HTTP/2"
  type        = bool
  default     = true
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
  default     = null
}

variable "target_groups" {
  description = "Target group configurations"
  type = list(object({
    name                 = string
    port                 = number
    protocol             = string
    target_type          = optional(string, "instance")
    health_check_path    = optional(string, "/health")
    health_check_matcher = optional(string, "200")
  }))
  default = []
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs"
  type        = string
  default     = null
}

variable "enable_waf" {
  description = "Enable WAF association"
  type        = bool
  default     = false
}
```

**Outputs**:
```hcl
output "arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Route53 zone ID of the load balancer"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "listener_arns" {
  description = "ARNs of the listeners"
  value       = { for k, v in aws_lb_listener.this : k => v.arn }
}
```

**Usage Example**:
```hcl
module "alb" {
  source = "../../modules/networking/alb"

  name               = "production-alb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.alb.id]

  ssl_certificate_arn = module.acm.certificate_arn
  access_logs_bucket  = module.s3.bucket_id

  target_groups = [
    {
      name                 = "web-servers"
      port                 = 80
      protocol             = "HTTP"
      health_check_path    = "/health"
      health_check_matcher = "200"
    },
    {
      name                 = "api-servers"
      port                 = 8080
      protocol             = "HTTP"
      health_check_path    = "/api/health"
      health_check_matcher = "200,404"
    }
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- VPC module (for vpc_id and subnet_ids)
- ACM module (for SSL certificates)
- S3 module (for access logs)

---

### CloudFront

**Module Path**: `modules/networking/cloudfront`

**Purpose**: Creates a CloudFront distribution with customizable origins, behaviors, and caching policies.

**Key Features**:
- Multiple origin support
- Custom caching behaviors
- SSL certificate integration
- Geographic restrictions
- WAF integration
- Access logging
- Origin failover support

**Required Variables**:
```hcl
variable "distribution_config" {
  description = "CloudFront distribution configuration"
  type = object({
    comment             = string
    default_root_object = optional(string, "index.html")
    enabled             = optional(bool, true)
    price_class         = optional(string, "PriceClass_All")
  })
}

variable "origins" {
  description = "List of origins"
  type = list(object({
    domain_name = string
    origin_id   = string
    origin_path = optional(string, "")
    custom_origin_config = optional(object({
      http_port              = optional(number, 80)
      https_port             = optional(number, 443)
      origin_protocol_policy = optional(string, "https-only")
      origin_ssl_protocols   = optional(list(string), ["TLSv1.2"])
    }))
    s3_origin_config = optional(object({
      origin_access_identity = string
    }))
  }))
}
```

**Optional Variables**:
```hcl
variable "default_cache_behavior" {
  description = "Default cache behavior"
  type = object({
    target_origin_id       = string
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)
    cache_policy_id        = optional(string)
    origin_request_policy_id = optional(string)
  })
  default = null
}

variable "custom_error_responses" {
  description = "Custom error response configurations"
  type = list(object({
    error_code         = number
    response_code      = optional(number)
    response_page_path = optional(string)
  }))
  default = []
}

variable "web_acl_id" {
  description = "WAF Web ACL ID"
  type        = string
  default     = null
}

variable "ssl_certificate" {
  description = "SSL certificate configuration"
  type = object({
    acm_certificate_arn            = optional(string)
    cloudfront_default_certificate = optional(bool, true)
    ssl_support_method             = optional(string, "sni-only")
    minimum_protocol_version       = optional(string, "TLSv1.2_2021")
  })
  default = {}
}

variable "geo_restriction" {
  description = "Geographic restriction configuration"
  type = object({
    restriction_type = optional(string, "none")
    locations        = optional(list(string), [])
  })
  default = {}
}
```

**Outputs**:
```hcl
output "id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "Route53 zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "status" {
  description = "Status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.status
}
```

**Usage Example**:
```hcl
module "cdn" {
  source = "../../modules/networking/cloudfront"

  distribution_config = {
    comment             = "Production CDN"
    default_root_object = "index.html"
    enabled             = true
    price_class         = "PriceClass_100"
  }

  origins = [
    {
      domain_name = module.s3.bucket_domain_name
      origin_id   = "S3-${module.s3.bucket_id}"
      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
      }
    },
    {
      domain_name = module.alb.dns_name
      origin_id   = "ALB-api"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
      }
    }
  ]

  default_cache_behavior = {
    target_origin_id       = "S3-${module.s3.bucket_id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/404.html"
    }
  ]

  ssl_certificate = {
    acm_certificate_arn      = module.acm.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- S3 module (for origin configuration)
- ALB module (for dynamic content origin)
- ACM module (for SSL certificates)

---

### Route53

**Module Path**: `modules/networking/route53`

**Purpose**: Creates Route53 hosted zones and DNS records with health check support.

**Key Features**:
- Hosted zone management
- Multiple record type support
- Health check integration
- Alias record support
- Traffic routing policies
- DNSSEC support

**Required Variables**:
```hcl
variable "zone_name" {
  description = "Name of the hosted zone"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "private_zone" {
  description = "Create a private hosted zone"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for private hosted zone"
  type        = string
  default     = null
}

variable "records" {
  description = "DNS records to create"
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string), [])
    alias = optional(object({
      name                   = string
      zone_id               = string
      evaluate_target_health = optional(bool, true)
    }))
    health_check_id = optional(string)
  }))
  default = []
}

variable "health_checks" {
  description = "Health checks configuration"
  type = list(object({
    fqdn                     = string
    port                     = optional(number, 443)
    type                     = optional(string, "HTTPS")
    resource_path            = optional(string, "/")
    failure_threshold        = optional(number, 3)
    request_interval         = optional(number, 30)
    cloudwatch_alarm_region  = optional(string, "us-east-1")
    cloudwatch_alarm_name    = optional(string)
    insufficient_data_health = optional(string, "Failure")
  }))
  default = []
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for the hosted zone"
  type        = bool
  default     = false
}
```

**Outputs**:
```hcl
output "zone_id" {
  description = "ID of the hosted zone"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.this.name_servers
}

output "zone_arn" {
  description = "ARN of the hosted zone"
  value       = aws_route53_zone.this.arn
}

output "health_check_ids" {
  description = "IDs of the health checks"
  value       = { for k, v in aws_route53_health_check.this : k => v.id }
}

output "record_names" {
  description = "Names of the created DNS records"
  value       = { for k, v in aws_route53_record.this : k => v.name }
}
```

**Usage Example**:
```hcl
module "dns" {
  source = "../../modules/networking/route53"

  zone_name = "example.com"

  records = [
    {
      name = "www"
      type = "A"
      alias = {
        name                   = module.cloudfront.domain_name
        zone_id               = module.cloudfront.hosted_zone_id
        evaluate_target_health = false
      }
    },
    {
      name = "api"
      type = "A"
      alias = {
        name                   = module.alb.dns_name
        zone_id               = module.alb.zone_id
        evaluate_target_health = true
      }
    },
    {
      name = "@"
      type = "MX"
      ttl  = 300
      records = [
        "10 mail.example.com"
      ]
    }
  ]

  health_checks = [
    {
      fqdn          = "api.example.com"
      port          = 443
      type          = "HTTPS"
      resource_path = "/health"
    }
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- CloudFront module (for CDN aliases)
- ALB module (for load balancer aliases)

---

## Database Modules

### RDS

**Module Path**: `modules/database/rds`

**Purpose**: Creates RDS instances or clusters with automated backups, monitoring, and security configurations.

**Key Features**:
- MySQL, PostgreSQL, MariaDB support
- Multi-AZ deployment support
- Automated backup configuration
- Read replica support
- Parameter group customization
- Security group management
- Performance Insights integration

**Required Variables**:
```hcl
variable "identifier" {
  description = "Database identifier"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
```

**Optional Variables**:
```hcl
variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1)"
  type        = string
  default     = "gp2"
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 60
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the database"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database"
  type        = list(string)
  default     = []
}
```

**Outputs**:
```hcl
output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "arn" {
  description = "Database ARN"
  value       = aws_db_instance.this.arn
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.this.name
}
```

**Usage Example**:
```hcl
module "database" {
  source = "../../modules/database/rds"

  identifier        = "production-db"
  engine           = "postgres"
  engine_version   = "13.7"
  instance_class   = "db.r5.large"
  allocated_storage = 100
  storage_type     = "gp3"

  db_name  = "myapp"
  username = "dbadmin"
  password = var.db_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  multi_az                     = true
  storage_encrypted           = true
  backup_retention_period     = 30
  deletion_protection         = true
  performance_insights_enabled = true

  allowed_security_groups = [
    module.ecs.security_group_id,
    module.lambda.security_group_id
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- VPC module (for vpc_id and subnet_ids)
- KMS module (for encryption keys)

---

### DynamoDB

**Module Path**: `modules/database/dynamodb`

**Purpose**: Creates DynamoDB tables with global secondary indexes, encryption, and backup configurations.

**Key Features**:
- On-demand and provisioned billing modes
- Global secondary index support
- Point-in-time recovery
- Server-side encryption
- Stream configuration
- Auto-scaling support
- Global table support

**Required Variables**:
```hcl
variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "hash_key" {
  description = "Hash key for the table"
  type        = string
}

variable "attributes" {
  description = "List of table attributes"
  type = list(object({
    name = string
    type = string
  }))
}
```

**Optional Variables**:
```hcl
variable "range_key" {
  description = "Range key for the table"
  type        = string
  default     = null
}

variable "billing_mode" {
  description = "Billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  description = "Read capacity units (required if billing_mode is PROVISIONED)"
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Write capacity units (required if billing_mode is PROVISIONED)"
  type        = number
  default     = null
}

variable "global_secondary_indexes" {
  description = "Global secondary indexes"
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = optional(string, "ALL")
    read_capacity   = optional(number)
    write_capacity  = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "Local secondary indexes"
  type = list(object({
    name            = string
    range_key       = string
    projection_type = optional(string, "ALL")
  }))
  default = []
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "enable_streams" {
  description = "Enable DynamoDB streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "ttl_attribute" {
  description = "TTL attribute name"
  type        = string
  default     = null
}
```

**Outputs**:
```hcl
output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.this.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.this.id
}

output "stream_arn" {
  description = "ARN of the DynamoDB stream"
  value       = aws_dynamodb_table.this.stream_arn
}

output "stream_label" {
  description = "Label of the DynamoDB stream"
  value       = aws_dynamodb_table.this.stream_label
}
```

**Usage Example**:
```hcl
module "user_table" {
  source = "../../modules/database/dynamodb"

  table_name = "users"
  hash_key   = "user_id"
  range_key  = "created_at"

  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "created_at"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name     = "email-index"
      hash_key = "email"
    },
    {
      name      = "status-created-index"
      hash_key  = "status"
      range_key = "created_at"
    }
  ]

  billing_mode                   = "PAY_PER_REQUEST"
  enable_encryption             = true
  enable_point_in_time_recovery = true
  enable_streams               = true
  stream_view_type            = "NEW_AND_OLD_IMAGES"
  ttl_attribute               = "expires_at"

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- KMS module (for encryption keys)

---

### ElastiCache

**Module Path**: `modules/database/elasticache`

**Purpose**: Creates ElastiCache Redis or Memcached clusters with replication groups and parameter groups.

**Key Features**:
- Redis and Memcached support
- Replication group configuration
- Multi-AZ support
- Automatic failover
- Backup and restore
- Parameter group customization
- Security group management

**Required Variables**:
```hcl
variable "cluster_id" {
  description = "ElastiCache cluster identifier"
  type        = string
}

variable "engine" {
  description = "Cache engine (redis or memcached)"
  type        = string
}

variable "node_type" {
  description = "Cache node type"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
```

**Optional Variables**:
```hcl
variable "engine_version" {
  description = "Cache engine version"
  type        = string
  default     = null
}

variable "port" {
  description = "Port number"
  type        = number
  default     = null
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for Memcached)"
  type        = number
  default     = 1
}

variable "parameter_group_name" {
  description = "Name of the parameter group"
  type        = string
  default     = null
}

variable "parameter_group_parameters" {
  description = "Parameters for custom parameter group"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for Redis cluster mode"
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group"
  type        = number
  default     = 1
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Auth token for Redis AUTH"
  type        = string
  default     = null
  sensitive   = true
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for snapshots"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance"
  type        = string
  default     = "sun:05:00-sun:09:00"
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the cache"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cache"
  type        = list(string)
  default     = []
}
```

**Outputs**:
```hcl
output "cluster_id" {
  description = "ElastiCache cluster identifier"
  value       = try(aws_elasticache_cluster.this[0].cluster_id, aws_elasticache_replication_group.this[0].id)
}

output "primary_endpoint" {
  description = "Primary endpoint"
  value       = try(aws_elasticache_replication_group.this[0].primary_endpoint_address, aws_elasticache_cluster.this[0].cluster_address)
}

output "reader_endpoint" {
  description = "Reader endpoint (Redis only)"
  value       = try(aws_elasticache_replication_group.this[0].reader_endpoint_address, null)
}

output "port" {
  description = "Port number"
  value       = try(aws_elasticache_replication_group.this[0].port, aws_elasticache_cluster.this[0].port)
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "Cache subnet group name"
  value       = aws_elasticache_subnet_group.this.name
}
```

**Usage Example**:
```hcl
module "redis" {
  source = "../../modules/database/elasticache"

  cluster_id = "production-redis"
  engine     = "redis"
  node_type  = "cache.r6g.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  engine_version              = "6.2"
  num_node_groups            = 2
  replicas_per_node_group    = 1
  multi_az_enabled           = true
  automatic_failover_enabled = true

  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
  auth_token                 = var.redis_auth_token

  snapshot_retention_limit = 7
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:09:00"

  parameter_group_parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]

  allowed_security_groups = [
    module.ecs.security_group_id,
    module.lambda.security_group_id
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- VPC module (for vpc_id and subnet_ids)

---

## Storage Modules

### S3

**Module Path**: `modules/storage/s3`

**Purpose**: Creates S3 buckets with versioning, encryption, lifecycle policies, and access controls.

**Key Features**:
- Server-side encryption
- Versioning support
- Lifecycle policy management
- Access logging
- Cross-region replication
- Static website hosting
- CORS configuration

**Required Variables**:
```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "encryption_configuration" {
  description = "Server-side encryption configuration"
  type = object({
    rule = object({
      apply_server_side_encryption_by_default = object({
        sse_algorithm     = string
        kms_master_key_id = optional(string)
      })
      bucket_key_enabled = optional(bool, true)
    })
  })
  default = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
    }
  }
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type = list(object({
    id     = string
    status = string
    expiration = optional(object({
      days = number
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    transition = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules for the bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

variable "website_configuration" {
  description = "Website configuration"
  type = object({
    index_document = optional(string, "index.html")
    error_document = optional(string, "error.html")
  })
  default = null
}

variable "public_access_block" {
  description = "Public access block configuration"
  type = object({
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)
  })
  default = {}
}

variable "bucket_policy" {
  description = "Bucket policy JSON"
  type        = string
  default     = null
}

variable "replication_configuration" {
  description = "Replication configuration"
  type = object({
    role = string
    rules = list(object({
      id     = string
      status = string
      destination = object({
        bucket        = string
        storage_class = optional(string, "STANDARD")
      })
    }))
  })
  default = null
}

variable "notification_configuration" {
  description = "Notification configuration"
  type = object({
    lambda_functions = optional(list(object({
      lambda_function_arn = string
      events              = list(string)
      filter_prefix       = optional(string)
      filter_suffix       = optional(string)
    })), [])
    topics = optional(list(object({
      topic_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
    queues = optional(list(object({
      queue_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
  })
  default = null
}

variable "access_log_bucket" {
  description = "Target bucket for access logs"
  type        = string
  default     = null
}

variable "access_log_prefix" {
  description = "Prefix for access logs"
  type        = string
  default     = "access-logs/"
}
```

**Outputs**:
```hcl
output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "Website endpoint"
  value       = try(aws_s3_bucket_website_configuration.this[0].website_endpoint, null)
}

output "website_domain" {
  description = "Website domain"
  value       = try(aws_s3_bucket_website_configuration.this[0].website_domain, null)
}
```

**Usage Example**:
```hcl
module "app_assets" {
  source = "../../modules/storage/s3"

  bucket_name        = "myapp-assets-production"
  versioning_enabled = true

  encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.kms.key_id
      }
      bucket_key_enabled = true
    }
  }

  lifecycle_rules = [
    {
      id     = "delete_old_versions"
      status = "Enabled"
      noncurrent_version_expiration = {
        days = 30
      }
    },
    {
      id     = "transition_to_ia"
      status = "Enabled"
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]

  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "POST"]
      allowed_origins = ["https://myapp.com"]
      max_age_seconds = 3600
    }
  ]

  notification_configuration = {
    lambda_functions = [
      {
        lambda_function_arn = module.image_processor.function_arn
        events             = ["s3:ObjectCreated:*"]
        filter_prefix      = "uploads/"
        filter_suffix      = ".jpg"
      }
    ]
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- KMS module (for encryption)
- Lambda module (for event notifications)

---

## Security Modules

### IAM

**Module Path**: `modules/security/iam`

**Purpose**: Creates IAM roles, policies, users, and groups with least privilege access patterns.

**Key Features**:
- Role and policy creation
- Cross-account assume role support
- Service-linked role support
- Policy attachment management
- User and group management
- Access key management
- MFA enforcement

**Required Variables**:
```hcl
variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "assume_role_policy" {
  description = "Assume role policy document"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds"
  type        = number
  default     = 3600
}

variable "path" {
  description = "Path for the IAM role"
  type        = string
  default     = "/"
}

variable "permissions_boundary" {
  description = "ARN of the policy used as permissions boundary"
  type        = string
  default     = null
}

variable "inline_policies" {
  description = "Inline policies to attach to the role"
  type = list(object({
    name   = string
    policy = string
  }))
  default = []
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "custom_policies" {
  description = "Custom policies to create and attach"
  type = list(object({
    name        = string
    description = optional(string, "")
    policy      = string
  }))
  default = []
}

variable "instance_profile" {
  description = "Create an instance profile for EC2"
  type        = bool
  default     = false
}
```

**Outputs**:
```hcl
output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_unique_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.this.unique_id
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = try(aws_iam_instance_profile.this[0].arn, null)
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = try(aws_iam_instance_profile.this[0].name, null)
}

output "policy_arns" {
  description = "ARNs of the created custom policies"
  value       = { for k, v in aws_iam_policy.custom : k => v.arn }
}
```

**Usage Example**:
```hcl
# ECS Task Role
module "ecs_task_role" {
  source = "../../modules/security/iam"

  role_name = "ecs-task-role"
  description = "IAM role for ECS tasks"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  custom_policies = [
    {
      name        = "s3-access-policy"
      description = "Allow access to S3 bucket"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject"
            ]
            Resource = "${module.s3.bucket_arn}/*"
          }
        ]
      })
    }
  ]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

# Lambda Execution Role
module "lambda_role" {
  source = "../../modules/security/iam"

  role_name = "lambda-execution-role"
  description = "IAM role for Lambda execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]

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
              "dynamodb:Query",
              "dynamodb:Scan"
            ]
            Resource = module.dynamodb.table_arn
          }
        ]
      })
    }
  ]
}
```

**Dependencies**: None (foundational module)

---

### KMS

**Module Path**: `modules/security/kms`

**Purpose**: Creates KMS keys with proper key policies, aliases, and rotation configuration.

**Key Features**:
- Customer managed keys
- Key rotation support
- Key policy management
- Alias creation
- Grant management
- Multi-region key support

**Required Variables**:
```hcl
variable "description" {
  description = "Description of the KMS key"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "key_usage" {
  description = "Usage of the key (ENCRYPT_DECRYPT or SIGN_VERIFY)"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "key_spec" {
  description = "Key spec for the KMS key"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Duration in days before key is deleted"
  type        = number
  default     = 7
}

variable "alias_name" {
  description = "Alias for the KMS key"
  type        = string
  default     = null
}

variable "key_policy" {
  description = "Key policy JSON document"
  type        = string
  default     = null
}

variable "allowed_services" {
  description = "AWS services allowed to use the key"
  type        = list(string)
  default     = []
}

variable "allowed_roles" {
  description = "IAM roles allowed to use the key"
  type        = list(string)
  default     = []
}

variable "allowed_users" {
  description = "IAM users allowed to use the key"
  type        = list(string)
  default     = []
}

variable "admin_roles" {
  description = "IAM roles with admin permissions on the key"
  type        = list(string)
  default     = []
}

variable "admin_users" {
  description = "IAM users with admin permissions on the key"
  type        = list(string)
  default     = []
}
```

**Outputs**:
```hcl
output "key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.this.arn
}

output "alias_arn" {
  description = "ARN of the key alias"
  value       = try(aws_kms_alias.this[0].arn, null)
}

output "alias_name" {
  description = "Name of the key alias"
  value       = try(aws_kms_alias.this[0].name, null)
}
```

**Usage Example**:
```hcl
module "application_key" {
  source = "../../modules/security/kms"

  description           = "KMS key for application data encryption"
  enable_key_rotation   = true
  deletion_window_in_days = 30
  alias_name           = "alias/myapp-production"

  allowed_services = [
    "s3.amazonaws.com",
    "rds.amazonaws.com",
    "dynamodb.amazonaws.com"
  ]

  allowed_roles = [
    module.ecs_role.role_arn,
    module.lambda_role.role_arn
  ]

  admin_roles = [
    "arn:aws:iam::123456789012:role/AdminRole"
  ]

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**: None (foundational module)

---

### Secrets Manager

**Module Path**: `modules/security/secrets-manager`

**Purpose**: Creates AWS Secrets Manager secrets with automatic rotation and access controls.

**Key Features**:
- Secret creation and management
- Automatic rotation support
- Version management
- Cross-region replication
- Resource-based policies
- Lambda rotation function integration

**Required Variables**:
```hcl
variable "name" {
  description = "Name of the secret"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "secret_string" {
  description = "Secret string value"
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_binary" {
  description = "Secret binary value (base64 encoded)"
  type        = string
  default     = null
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Recovery window for deleted secret"
  type        = number
  default     = 7
}

variable "automatic_rotation" {
  description = "Enable automatic rotation"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "Lambda function ARN for rotation"
  type        = string
  default     = null
}

variable "rotation_rules" {
  description = "Rotation rules configuration"
  type = object({
    automatically_after_days = number
  })
  default = null
}

variable "replica_regions" {
  description = "Regions to replicate the secret to"
  type = list(object({
    region     = string
    kms_key_id = optional(string)
  }))
  default = []
}

variable "resource_policy" {
  description = "Resource-based policy for the secret"
  type        = string
  default     = null
}
```

**Outputs**:
```hcl
output "secret_arn" {
  description = "ARN of the secret"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "ID of the secret"
  value       = aws_secretsmanager_secret.this.id
}

output "version_id" {
  description = "Version ID of the secret"
  value       = try(aws_secretsmanager_secret_version.this[0].version_id, null)
}
```

**Usage Example**:
```hcl
# Database credentials
module "db_credentials" {
  source = "../../modules/security/secrets-manager"

  name        = "myapp/database/credentials"
  description = "Database credentials for production"

  secret_string = jsonencode({
    username = "dbadmin"
    password = var.db_password
    engine   = "postgres"
    host     = module.rds.endpoint
    port     = module.rds.port
    dbname   = module.rds.database_name
  })

  kms_key_id = module.kms.key_id

  automatic_rotation = true
  rotation_lambda_arn = module.rotation_lambda.function_arn
  rotation_rules = {
    automatically_after_days = 30
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

# API keys
module "api_keys" {
  source = "../../modules/security/secrets-manager"

  name        = "myapp/api/keys"
  description = "Third-party API keys"

  secret_string = jsonencode({
    stripe_key    = var.stripe_api_key
    sendgrid_key  = var.sendgrid_api_key
    analytics_key = var.analytics_api_key
  })

  kms_key_id = module.kms.key_id

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- KMS module (for encryption)
- Lambda module (for rotation functions)

---

## Monitoring Modules

### CloudWatch

**Module Path**: `modules/monitoring/cloudwatch`

**Purpose**: Creates CloudWatch log groups, metrics, alarms, and dashboards for comprehensive monitoring.

**Key Features**:
- Log group management
- Custom metric creation
- Alarm configuration
- Dashboard creation
- Log retention policies
- Metric filters
- Composite alarms

**Required Variables**:
```hcl
variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = null
}

variable "metric_filters" {
  description = "Metric filters for the log group"
  type = list(object({
    name           = string
    pattern        = string
    metric_name    = string
    metric_namespace = string
    metric_value   = optional(string, "1")
  }))
  default = []
}

variable "alarms" {
  description = "CloudWatch alarms configuration"
  type = list(object({
    name                = string
    description         = optional(string, "")
    metric_name         = string
    namespace           = string
    statistic           = optional(string, "Sum")
    period              = optional(number, 300)
    evaluation_periods  = optional(number, 2)
    threshold           = number
    comparison_operator = string
    alarm_actions       = optional(list(string), [])
    ok_actions         = optional(list(string), [])
    treat_missing_data  = optional(string, "notBreaching")
    dimensions         = optional(map(string), {})
  }))
  default = []
}

variable "dashboard_config" {
  description = "Dashboard configuration"
  type = object({
    name = string
    widgets = list(object({
      type   = string
      x      = number
      y      = number
      width  = number
      height = number
      properties = map(any)
    }))
  })
  default = null
}
```

**Outputs**:
```hcl
output "log_group_name" {
  description = "Name of the log group"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the log group"
  value       = aws_cloudwatch_log_group.this.arn
}

output "alarm_arns" {
  description = "ARNs of the CloudWatch alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.arn }
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = try("https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.this[0].dashboard_name}", null)
}
```

**Usage Example**:
```hcl
module "application_monitoring" {
  source = "../../modules/monitoring/cloudwatch"

  log_group_name    = "/aws/ecs/myapp"
  retention_in_days = 30
  kms_key_id       = module.kms.key_id

  metric_filters = [
    {
      name             = "error-count"
      pattern          = "[timestamp, request_id, ERROR]"
      metric_name      = "ErrorCount"
      metric_namespace = "MyApp/Application"
    },
    {
      name             = "response-time"
      pattern          = "[timestamp, request_id, response_time>1000]"
      metric_name      = "HighResponseTime"
      metric_namespace = "MyApp/Performance"
    }
  ]

  alarms = [
    {
      name                = "high-error-rate"
      description         = "Alert when error rate is high"
      metric_name         = "ErrorCount"
      namespace           = "MyApp/Application"
      statistic           = "Sum"
      period              = 300
      evaluation_periods  = 2
      threshold           = 10
      comparison_operator = "GreaterThanThreshold"
      alarm_actions       = [module.sns.topic_arn]
    },
    {
      name                = "high-response-time"
      description         = "Alert when response time is high"
      metric_name         = "HighResponseTime"
      namespace           = "MyApp/Performance"
      threshold           = 5
      comparison_operator = "GreaterThanThreshold"
      alarm_actions       = [module.sns.topic_arn]
    }
  ]

  dashboard_config = {
    name = "MyApp-Production-Dashboard"
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["MyApp/Application", "ErrorCount"],
            ["MyApp/Performance", "HighResponseTime"]
          ]
          period = 300
          stat   = "Sum"
          region = "us-west-2"
          title  = "Application Metrics"
        }
      }
    ]
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- SNS module (for alarm notifications)
- KMS module (for log encryption)

---

### SNS

**Module Path**: `modules/monitoring/sns`

**Purpose**: Creates SNS topics with subscriptions for notifications and event publishing.

**Key Features**:
- Topic creation and management
- Multiple subscription types
- Message encryption
- Dead letter queue support
- Message filtering
- Cross-region publishing
- Delivery status logging

**Required Variables**:
```hcl
variable "topic_name" {
  description = "Name of the SNS topic"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "display_name" {
  description = "Display name for the topic"
  type        = string
  default     = null
}

variable "kms_master_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "delivery_policy" {
  description = "Delivery policy for the topic"
  type        = string
  default     = null
}

variable "policy" {
  description = "Access policy for the topic"
  type        = string
  default     = null
}

variable "subscriptions" {
  description = "List of subscriptions"
  type = list(object({
    protocol               = string
    endpoint              = string
    confirmation_timeout_in_minutes = optional(number, 1)
    endpoint_auto_confirms = optional(bool, false)
    filter_policy         = optional(string)
    delivery_policy       = optional(string)
    raw_message_delivery  = optional(bool, false)
  }))
  default = []
}

variable "enable_logging" {
  description = "Enable delivery status logging"
  type        = bool
  default     = false
}

variable "success_feedback_role_arn" {
  description = "IAM role ARN for success feedback"
  type        = string
  default     = null
}

variable "failure_feedback_role_arn" {
  description = "IAM role ARN for failure feedback"
  type        = string
  default     = null
}

variable "success_feedback_sample_rate" {
  description = "Sample rate for success feedback"
  type        = number
  default     = 100
}
```

**Outputs**:
```hcl
output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.this.arn
}

output "topic_id" {
  description = "ID of the SNS topic"
  value       = aws_sns_topic.this.id
}

output "subscription_arns" {
  description = "ARNs of the subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.this : k => v.arn }
}
```

**Usage Example**:
```hcl
module "alerts_topic" {
  source = "../../modules/monitoring/sns"

  topic_name   = "production-alerts"
  display_name = "Production Alerts"

  kms_master_key_id = module.kms.key_id

  subscriptions = [
    {
      protocol = "email"
      endpoint = "alerts@mycompany.com"
    },
    {
      protocol = "sms"
      endpoint = "+1234567890"
    },
    {
      protocol = "lambda"
      endpoint = module.alert_processor.function_arn
    }
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = "SNS:Publish"
        Resource = "*"
      }
    ]
  })

  enable_logging = true
  success_feedback_role_arn = module.sns_logging_role.role_arn
  failure_feedback_role_arn = module.sns_logging_role.role_arn

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- Lambda module (for Lambda subscriptions)
- IAM module (for delivery status logging)
- KMS module (for encryption)

---

### EventBridge

**Module Path**: `modules/monitoring/eventbridge`

**Purpose**: Creates EventBridge custom buses, rules, and targets for event-driven architecture.

**Key Features**:
- Custom event bus creation
- Event rule configuration
- Multiple target types
- Event replay capability
- Schema registry integration
- Cross-account event routing
- Dead letter queue support

**Required Variables**:
```hcl
variable "bus_name" {
  description = "Name of the EventBridge bus"
  type        = string
  default     = "default"
}
```

**Optional Variables**:
```hcl
variable "event_source_name" {
  description = "Name of the event source"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "rules" {
  description = "EventBridge rules configuration"
  type = list(object({
    name                = string
    description         = optional(string, "")
    event_pattern       = optional(string)
    schedule_expression = optional(string)
    state              = optional(string, "ENABLED")
    targets = list(object({
      id        = string
      arn       = string
      role_arn  = optional(string)
      input     = optional(string)
      input_path = optional(string)
      input_transformer = optional(object({
        input_paths_map = optional(map(string))
        input_template  = string
      }))
      dead_letter_config = optional(object({
        arn = string
      }))
      retry_policy = optional(object({
        maximum_retry_attempts = optional(number, 185)
        maximum_event_age_in_seconds = optional(number, 1800)
      }))
    }))
  }))
  default = []
}

variable "archive_config" {
  description = "Event archive configuration"
  type = object({
    name             = string
    description      = optional(string, "")
    retention_days   = optional(number, 0)
    event_pattern    = optional(string)
  })
  default = null
}
```

**Outputs**:
```hcl
output "bus_name" {
  description = "Name of the EventBridge bus"
  value       = var.bus_name == "default" ? "default" : aws_cloudwatch_event_bus.this[0].name
}

output "bus_arn" {
  description = "ARN of the EventBridge bus"
  value       = var.bus_name == "default" ? "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default" : aws_cloudwatch_event_bus.this[0].arn
}

output "rule_arns" {
  description = "ARNs of the EventBridge rules"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.arn }
}

output "archive_arn" {
  description = "ARN of the event archive"
  value       = try(aws_cloudwatch_event_archive.this[0].arn, null)
}
```

**Usage Example**:
```hcl
module "application_events" {
  source = "../../modules/monitoring/eventbridge"

  bus_name          = "myapp-production"
  event_source_name = "myapp.orders"
  kms_key_id       = module.kms.key_id

  rules = [
    {
      name        = "order-created"
      description = "Process new orders"
      event_pattern = jsonencode({
        source      = ["myapp.orders"]
        detail-type = ["Order Created"]
        detail = {
          status = ["pending"]
        }
      })
      targets = [
        {
          id       = "process-order-lambda"
          arn      = module.order_processor.function_arn
          role_arn = module.eventbridge_role.role_arn
        },
        {
          id  = "order-analytics"
          arn = module.analytics_queue.queue_arn
          input_transformer = {
            input_paths_map = {
              order_id = "$.detail.order_id"
              customer = "$.detail.customer_id"
            }
            input_template = jsonencode({
              event_type = "order_created"
              order_id   = "<order_id>"
              customer   = "<customer>"
              timestamp  = "<aws.events.event.ingestion-time>"
            })
          }
        }
      ]
    },
    {
      name                = "daily-report"
      description         = "Generate daily reports"
      schedule_expression = "cron(0 6 * * ? *)"
      targets = [
        {
          id       = "report-generator"
          arn      = module.report_generator.function_arn
          role_arn = module.eventbridge_role.role_arn
        }
      ]
    }
  ]

  archive_config = {
    name           = "order-events-archive"
    description    = "Archive of order-related events"
    retention_days = 30
    event_pattern = jsonencode({
      source = ["myapp.orders"]
    })
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- Lambda module (for Lambda targets)
- SQS module (for queue targets)
- IAM module (for execution roles)
- KMS module (for encryption)

---

## Integration Modules

### SQS

**Module Path**: `modules/integration/sqs`

**Purpose**: Creates SQS queues with dead letter queues, encryption, and visibility timeout configuration.

**Key Features**:
- Standard and FIFO queue support
- Dead letter queue integration
- Message encryption
- Visibility timeout configuration
- Message retention settings
- Redrive policy support
- Queue policy management

**Required Variables**:
```hcl
variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "fifo_queue" {
  description = "Create a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication (FIFO only)"
  type        = bool
  default     = false
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Message retention period in seconds"
  type        = number
  default     = 1209600 # 14 days
}

variable "max_message_size" {
  description = "Maximum message size in bytes"
  type        = number
  default     = 262144 # 256 KB
}

variable "delay_seconds" {
  description = "Delay in seconds for message delivery"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time in seconds"
  type        = number
  default     = 0
}

variable "kms_master_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "KMS data key reuse period"
  type        = number
  default     = 300
}

variable "dead_letter_queue_config" {
  description = "Dead letter queue configuration"
  type = object({
    max_receive_count = number
    create_dlq        = optional(bool, true)
  })
  default = null
}

variable "policy" {
  description = "Queue access policy"
  type        = string
  default     = null
}
```

**Outputs**:
```hcl
output "queue_id" {
  description = "ID of the SQS queue"
  value       = aws_sqs_queue.this.id
}

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.this.id
}

output "dead_letter_queue_id" {
  description = "ID of the dead letter queue"
  value       = try(aws_sqs_queue.dead_letter[0].id, null)
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue"
  value       = try(aws_sqs_queue.dead_letter[0].arn, null)
}
```

**Usage Example**:
```hcl
module "order_queue" {
  source = "../../modules/integration/sqs"

  queue_name                     = "order-processing"
  visibility_timeout_seconds     = 300
  message_retention_seconds      = 1209600 # 14 days
  receive_wait_time_seconds      = 20 # Enable long polling
  kms_master_key_id             = module.kms.key_id

  dead_letter_queue_config = {
    max_receive_count = 3
    create_dlq        = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

module "user_events_fifo" {
  source = "../../modules/integration/sqs"

  queue_name                    = "user-events.fifo"
  fifo_queue                   = true
  content_based_deduplication  = true
  visibility_timeout_seconds   = 60
  kms_master_key_id           = module.kms.key_id

  dead_letter_queue_config = {
    max_receive_count = 5
    create_dlq        = true
  }

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

**Dependencies**:
- KMS module (for encryption)

---

## Enterprise Modules

### Compliance

**Module Path**: `modules/enterprise/compliance`

**Purpose**: Implements compliance controls and monitoring for regulatory requirements (SOC2, HIPAA, PCI-DSS).

**Key Features**:
- AWS Config rules deployment
- CloudTrail configuration
- GuardDuty enablement
- Security Hub integration
- Compliance dashboard creation
- Automated remediation
- Audit trail management

**Required Variables**:
```hcl
variable "compliance_framework" {
  description = "Compliance framework (soc2, hipaa, pci-dss, gdpr)"
  type        = string
}

variable "organization_name" {
  description = "Organization name for compliance reporting"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub"
  type        = bool
  default     = true
}

variable "config_bucket_name" {
  description = "S3 bucket for Config snapshots"
  type        = string
  default     = null
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket for CloudTrail logs"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "SNS topic for compliance notifications"
  type        = string
  default     = null
}

variable "custom_config_rules" {
  description = "Custom Config rules"
  type = list(object({
    name                 = string
    description          = optional(string, "")
    source_identifier    = string
    input_parameters     = optional(string)
    maximum_execution_frequency = optional(string, "TwentyFour_Hours")
  }))
  default = []
}

variable "remediation_configurations" {
  description = "Remediation configurations for Config rules"
  type = list(object({
    config_rule_name    = string
    action_type         = string
    action_version      = string
    action_parameters   = optional(map(string), {})
    automatic           = optional(bool, false)
    maximum_automatic_attempts = optional(number, 3)
  }))
  default = []
}
```

**Outputs**:
```hcl
output "config_configuration_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = try(aws_config_configuration_recorder.this[0].name, null)
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = try(aws_cloudtrail.this[0].arn, null)
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "security_hub_arn" {
  description = "ARN of Security Hub"
  value       = try(aws_securityhub_account.this[0].id, null)
}

output "compliance_dashboard_url" {
  description = "URL of the compliance dashboard"
  value       = try(aws_cloudwatch_dashboard.compliance[0].dashboard_name, null)
}
```

**Usage Example**:
```hcl
module "soc2_compliance" {
  source = "../../modules/enterprise/compliance"

  compliance_framework = "soc2"
  organization_name    = "MyCompany Inc"

  enable_config      = true
  enable_cloudtrail  = true
  enable_guardduty   = true
  enable_security_hub = true

  config_bucket_name    = "${var.organization}-config-${var.environment}"
  cloudtrail_bucket_name = "${var.organization}-cloudtrail-${var.environment}"
  sns_topic_arn         = module.compliance_alerts.topic_arn

  custom_config_rules = [
    {
      name              = "s3-bucket-ssl-requests-only"
      description       = "Checks if S3 buckets have policies requiring SSL requests"
      source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
    },
    {
      name                        = "rds-instance-deletion-protection-enabled"
      description                 = "Checks if RDS instances have deletion protection enabled"
      source_identifier           = "RDS_INSTANCE_DELETION_PROTECTION_ENABLED"
      maximum_execution_frequency = "Six_Hours"
    }
  ]

  remediation_configurations = [
    {
      config_rule_name = "s3-bucket-public-access-prohibited"
      action_type      = "SSM_DOCUMENT"
      action_version   = "1"
      action_parameters = {
        "BucketName" = "{resourceId}"
      }
      automatic                 = true
      maximum_automatic_attempts = 2
    }
  ]

  tags = {
    Environment = "production"
    Compliance  = "SOC2"
  }
}
```

**Dependencies**:
- S3 module (for Config and CloudTrail storage)
- SNS module (for notifications)
- IAM module (for service roles)

---

### Team Boundaries

**Module Path**: `modules/enterprise/team-boundaries`

**Purpose**: Implements organizational boundaries and access controls for multi-team environments.

**Key Features**:
- Team-based IAM role creation
- Resource tagging enforcement
- Cost allocation tags
- Service Control Policies (SCPs)
- Cross-account access management
- Resource isolation
- Budget and billing controls

**Required Variables**:
```hcl
variable "teams" {
  description = "Team configuration"
  type = list(object({
    name        = string
    description = optional(string, "")
    members     = list(string)
    permissions = object({
      services = list(string)
      actions  = list(string)
      resources = optional(list(string), ["*"])
    })
    cost_center = optional(string)
    budget_limit = optional(number)
  }))
}

variable "organization_name" {
  description = "Organization name"
  type        = string
}
```

**Optional Variables**:
```hcl
variable "enable_cost_allocation_tags" {
  description = "Enable cost allocation tags"
  type        = bool
  default     = true
}

variable "enable_budget_alerts" {
  description = "Enable budget alerts"
  type        = bool
  default     = true
}

variable "budget_alert_subscribers" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}

variable "default_permissions_boundary" {
  description = "Default permissions boundary policy ARN"
  type        = string
  default     = null
}

variable "resource_prefixes" {
  description = "Resource naming prefixes by team"
  type        = map(string)
  default     = {}
}

variable "shared_resources" {
  description = "Resources shared across teams"
  type = list(object({
    arn         = string
    permissions = list(string)
    teams       = list(string)
  }))
  default = []
}

variable "cross_account_roles" {
  description = "Cross-account role configurations"
  type = list(object({
    name            = string
    trusted_account = string
    team            = string
    permissions     = list(string)
  }))
  default = []
}
```

**Outputs**:
```hcl
output "team_roles" {
  description = "IAM roles for each team"
  value       = { for k, v in aws_iam_role.team : k => v.arn }
}

output "team_groups" {
  description = "IAM groups for each team"
  value       = { for k, v in aws_iam_group.team : k => v.name }
}

output "budget_arns" {
  description = "ARNs of team budgets"
  value       = { for k, v in aws_budgets_budget.team : k => v.arn }
}

output "cost_allocation_tags" {
  description = "Cost allocation tag keys"
  value       = local.cost_allocation_tags
}
```

**Usage Example**:
```hcl
module "team_boundaries" {
  source = "../../modules/enterprise/team-boundaries"

  organization_name = "MyCompany"

  teams = [
    {
      name        = "frontend"
      description = "Frontend development team"
      members     = ["user1@company.com", "user2@company.com"]
      permissions = {
        services = ["s3", "cloudfront", "route53", "acm"]
        actions = [
          "s3:*",
          "cloudfront:*",
          "route53:*",
          "acm:*"
        ]
        resources = [
          "arn:aws:s3:::frontend-*",
          "arn:aws:cloudfront::*:distribution/*"
        ]
      }
      cost_center  = "engineering"
      budget_limit = 1000
    },
    {
      name        = "backend"
      description = "Backend development team"
      members     = ["user3@company.com", "user4@company.com"]
      permissions = {
        services = ["ec2", "rds", "lambda", "ecs", "dynamodb"]
        actions = [
          "ec2:*",
          "rds:*",
          "lambda:*",
          "ecs:*",
          "dynamodb:*"
        ]
      }
      cost_center  = "engineering"
      budget_limit = 2000
    },
    {
      name        = "data"
      description = "Data engineering team"
      members     = ["user5@company.com"]
      permissions = {
        services = ["s3", "athena", "glue", "kinesis", "redshift"]
        actions = [
          "s3:*",
          "athena:*",
          "glue:*",
          "kinesis:*",
          "redshift:*"
        ]
      }
      cost_center  = "data"
      budget_limit = 3000
    }
  ]

  enable_cost_allocation_tags = true
  enable_budget_alerts       = true
  budget_alert_subscribers   = ["finance@company.com", "devops@company.com"]

  resource_prefixes = {
    frontend = "fe"
    backend  = "be"
    data     = "data"
  }

  shared_resources = [
    {
      arn         = module.vpc.vpc_arn
      permissions = ["ec2:DescribeVpcs", "ec2:DescribeSubnets"]
      teams       = ["frontend", "backend"]
    }
  ]

  cross_account_roles = [
    {
      name            = "production-deployer"
      trusted_account = "123456789012"
      team            = "backend"
      permissions     = ["ecs:UpdateService", "lambda:UpdateFunctionCode"]
    }
  ]

  tags = {
    Environment = "production"
    Management  = "team-boundaries"
  }
}
```

**Dependencies**:
- IAM module (for role and policy management)
- Organizations module (for SCPs, if using AWS Organizations)

---

## Module Usage Guidelines

### Best Practices

1. **Versioning**: Always pin module versions in production
   ```hcl
   module "vpc" {
     source  = "../../modules/networking/vpc"
     version = "1.2.0"
     # ... configuration
   }
   ```

2. **Tagging**: Use consistent tagging strategy across all modules
   ```hcl
   tags = {
     Environment = var.environment
     Application = var.application_name
     ManagedBy   = "terraform"
     CostCenter  = var.cost_center
   }
   ```

3. **Security**: Always enable encryption and follow least privilege principles
   ```hcl
   storage_encrypted = true
   kms_key_id       = module.kms.key_id
   ```

4. **Monitoring**: Enable monitoring and logging for all resources
   ```hcl
   enable_monitoring = true
   log_retention_days = 30
   ```

5. **Backup and Recovery**: Configure appropriate backup and recovery settings
   ```hcl
   backup_retention_period = 30
   enable_point_in_time_recovery = true
   ```

### Module Composition Patterns

#### Three-Tier Web Application
```hcl
# Networking Foundation
module "vpc" {
  source = "../../modules/networking/vpc"
  # ... configuration
}

module "alb" {
  source = "../../modules/networking/alb"
  vpc_id = module.vpc.vpc_id
  # ... configuration
}

# Compute Layer
module "web_servers" {
  source    = "../../modules/compute/ecs"
  subnet_ids = module.vpc.private_subnet_ids
  # ... configuration
}

# Data Layer
module "database" {
  source     = "../../modules/database/rds"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  # ... configuration
}

module "cache" {
  source     = "../../modules/database/elasticache"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  # ... configuration
}
```

#### Serverless Application
```hcl
# API Gateway + Lambda
module "api_lambda" {
  source = "../../modules/compute/lambda"
  # ... configuration
}

# Database
module "dynamodb" {
  source = "../../modules/database/dynamodb"
  # ... configuration
}

# Event Processing
module "event_queue" {
  source = "../../modules/integration/sqs"
  # ... configuration
}

module "event_processor" {
  source = "../../modules/compute/lambda"
  # ... configuration
}
```

### Development Workflow

1. **Local Development**: Use `terraform plan` to validate changes
2. **Testing**: Use separate environments for testing module changes
3. **Staging**: Deploy to staging environment before production
4. **Production**: Use blue/green or rolling deployments

### Troubleshooting Common Issues

1. **Dependency Errors**: Check module dependencies and ensure proper ordering
2. **Permission Issues**: Verify IAM roles and policies are correctly configured
3. **Resource Limits**: Check AWS service limits and quotas
4. **Network Connectivity**: Verify security groups and NACLs allow required traffic

---

## Version Compatibility

| Module Category | Terraform Version | AWS Provider Version | Last Updated |
|-----------------|-------------------|---------------------|--------------|
| All Modules     | >= 1.0           | >= 4.0              | 2024-01-15   |

### Terraform Version Requirements
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Module Updates and Migration

For the latest updates and migration guides, see:
- [CHANGELOG.md](./CHANGELOG.md)
- [MIGRATION.md](./MIGRATION.md)
- [GitHub Releases](https://github.com/stackkit/stackkit-terraform/releases)

---

**Note**: This catalog is automatically generated and maintained. For the most up-to-date information, always refer to the individual module documentation and source code.