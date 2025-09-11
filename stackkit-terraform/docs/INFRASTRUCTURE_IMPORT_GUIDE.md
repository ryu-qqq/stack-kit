# 인프라 임포트 가이드

**StackKit 모듈을 사용하여 기존 AWS 인프라를 Terraform 관리로 임포트하는 종합 가이드**

## 목차

1. [임포트 전략 계획](#임포트-전략-계획)
2. [임포트 전 준비](#임포트-전-준비)
3. [단계별 임포트 프로세스](#단계별-임포트-프로세스)
4. [모듈별 임포트 가이드](#모듈별-임포트-가이드)
5. [일반적인 문제와 해결책](#일반적인-문제와-해결책)
6. [임포트 후 검증](#임포트-후-검증)
7. [자동화 및 도구](#자동화-및-도구)

---

## 임포트 전략 계획

### 인프라 평가

임포트 프로세스를 시작하기 전에 기존 AWS 인프라에 대한 종합적인 평가를 수행하세요:

```bash
# AWS 계정의 모든 리소스 검색
aws resourcegroupstaggingapi get-resources --region us-east-1 > resources-inventory.json

# 상세한 VPC 정보 확인
aws ec2 describe-vpcs --region us-east-1
aws ec2 describe-subnets --region us-east-1
aws ec2 describe-route-tables --region us-east-1
aws ec2 describe-security-groups --region us-east-1

# 모든 EC2 인스턴스 목록 조회
aws ec2 describe-instances --region us-east-1

# 데이터베이스 리소스
aws rds describe-db-instances --region us-east-1
aws rds describe-db-clusters --region us-east-1

# 로드 밸런서
aws elbv2 describe-load-balancers --region us-east-1
aws elb describe-load-balancers --region us-east-1
```

### 임포트 우선순위 매트릭스

위험도와 종속성 계층 구조를 기반으로 임포트 우선순위를 정합니다:

| 우선순위 | 리소스 유형 | 위험 수준 | 종속성 | 타임라인 |
|----------|---------------|------------|--------------|----------|
| 1 | VPC, 서브넷, IGW | 낮음 | 없음 | 1주차 |
| 2 | 보안 그룹 | 낮음 | VPC | 1주차 |
| 3 | 라우팅 테이블, NACL | 중간 | VPC, 서브넷 | 2주차 |
| 4 | IAM 역할, 정책 | 중간 | 없음 | 2주차 |
| 5 | S3 버킷 | 낮음 | 없음 | 2주차 |
| 6 | EC2 인스턴스 | 높음 | VPC, SG, IAM | 3주차 |
| 7 | RDS 데이터베이스 | 높음 | VPC, SG, 서브넷 | 3주차 |
| 8 | 로드 밸런서 | 중간 | VPC, SG, EC2 | 4주차 |
| 9 | CloudFront | 낮음 | S3, ALB | 4주차 |
| 10 | Route53 | 낮음 | ALB, CloudFront | 4주차 |

### Risk Assessment Framework

```yaml
risk_categories:
  low:
    impact: "Minimal service disruption"
    rollback_time: "< 15 minutes"
    examples: ["S3 buckets", "VPC", "CloudFront"]
  
  medium:
    impact: "Potential brief downtime"
    rollback_time: "15-60 minutes"
    examples: ["Load balancers", "Security groups", "Route tables"]
  
  high:
    impact: "Service disruption likely"
    rollback_time: "1-4 hours"
    examples: ["EC2 instances", "RDS databases", "Auto Scaling Groups"]
```

### Rollback Strategy

```bash
#!/bin/bash
# rollback-import.sh - Emergency rollback script

BACKUP_DIR="/tmp/terraform-import-backup"
STATE_BACKUP="${BACKUP_DIR}/terraform.tfstate.backup"

echo "🚨 Emergency Rollback Initiated"

# 1. Stop all Terraform operations
pkill -f "terraform"

# 2. Restore previous state
if [ -f "$STATE_BACKUP" ]; then
    cp "$STATE_BACKUP" terraform.tfstate
    echo "✅ State restored from backup"
else
    echo "❌ No state backup found"
    exit 1
fi

# 3. Remove imported resources from state (don't destroy)
terraform state list | grep "imported_" | while read resource; do
    terraform state rm "$resource"
    echo "🔄 Removed $resource from state"
done

echo "✅ Rollback complete - verify infrastructure manually"
```

---

## Pre-Import Preparation

### Backup Strategies

```bash
#!/bin/bash
# backup-pre-import.sh

BACKUP_DIR="/tmp/terraform-import-backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating pre-import backups..."

# 1. Terraform state backup
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "$BACKUP_DIR/terraform.tfstate.backup"
    echo "✅ Terraform state backed up"
fi

# 2. Configuration backup
tar -czf "$BACKUP_DIR/terraform-configs.tar.gz" *.tf *.tfvars modules/ 2>/dev/null || true
echo "✅ Terraform configurations backed up"

# 3. AWS resource snapshots
aws ec2 describe-instances > "$BACKUP_DIR/ec2-instances.json"
aws rds describe-db-instances > "$BACKUP_DIR/rds-instances.json"
aws elbv2 describe-load-balancers > "$BACKUP_DIR/load-balancers.json"
aws s3api list-buckets > "$BACKUP_DIR/s3-buckets.json"
echo "✅ AWS resource snapshots created"

# 4. Create resource inventory
aws resourcegroupstaggingapi get-resources --region us-east-1 > "$BACKUP_DIR/resource-inventory.json"
echo "✅ Resource inventory created"

echo "📦 Backup location: $BACKUP_DIR"
```

### State Management Setup

```hcl
# backend.tf - Remote state configuration for import process
terraform {
  backend "s3" {
    bucket         = "stackkit-terraform-state"
    key            = "infrastructure-import/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "stackkit-terraform-locks"
    encrypt        = true
  }
}

# Create separate workspace for import
resource "null_resource" "import_workspace" {
  provisioner "local-exec" {
    command = "terraform workspace new import-$(date +%Y%m%d) || terraform workspace select import-$(date +%Y%m%d)"
  }
}
```

### Resource Discovery Tools

```bash
#!/bin/bash
# discover-resources.sh - Automated resource discovery

echo "🔍 Discovering AWS resources for import..."

# Function to safely run AWS CLI commands
aws_safe() {
    local service=$1
    local command=$2
    local region=${3:-us-east-1}
    
    echo "Discovering ${service}..."
    aws $service $command --region $region 2>/dev/null || echo "❌ Failed to discover ${service}"
}

# Network resources
aws_safe "ec2" "describe-vpcs"
aws_safe "ec2" "describe-subnets"
aws_safe "ec2" "describe-internet-gateways"
aws_safe "ec2" "describe-nat-gateways"
aws_safe "ec2" "describe-route-tables"
aws_safe "ec2" "describe-security-groups"

# Compute resources
aws_safe "ec2" "describe-instances"
aws_safe "autoscaling" "describe-auto-scaling-groups"
aws_safe "ec2" "describe-launch-templates"

# Storage resources
aws_safe "s3api" "list-buckets"
aws_safe "ec2" "describe-volumes"

# Database resources
aws_safe "rds" "describe-db-instances"
aws_safe "rds" "describe-db-clusters"
aws_safe "rds" "describe-db-subnet-groups"

# Load balancing
aws_safe "elbv2" "describe-load-balancers"
aws_safe "elbv2" "describe-target-groups"
aws_safe "elb" "describe-load-balancers"

# DNS and CDN
aws_safe "route53" "list-hosted-zones"
aws_safe "cloudfront" "list-distributions"

# Security
aws_safe "iam" "list-roles"
aws_safe "iam" "list-policies"

echo "✅ Resource discovery complete"
```

---

## Step-by-Step Import Process

### Phase 1: Resource Identification

```bash
#!/bin/bash
# identify-import-targets.sh

# Create import mapping file
cat > import-mapping.json << EOF
{
  "vpc": {
    "resource_type": "aws_vpc",
    "aws_id": "vpc-0123456789abcdef0",
    "terraform_address": "module.networking.aws_vpc.main"
  },
  "subnets": [
    {
      "resource_type": "aws_subnet",
      "aws_id": "subnet-0123456789abcdef0",
      "terraform_address": "module.networking.aws_subnet.private[0]"
    }
  ],
  "security_groups": [
    {
      "resource_type": "aws_security_group",
      "aws_id": "sg-0123456789abcdef0",
      "terraform_address": "module.security.aws_security_group.web"
    }
  ]
}
EOF
```

### Phase 2: Configuration Creation

```hcl
# import-configurations.tf - Temporary file for import process

# VPC Configuration
module "imported_networking" {
  source = "./modules/networking"
  
  # Match existing VPC configuration
  vpc_cidr = "10.0.0.0/16"  # From AWS console
  
  private_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
  
  public_subnet_cidrs = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]
  
  availability_zones = ["us-east-1a", "us-east-1b"]
  
  tags = {
    Environment = "production"
    Project     = "imported-infrastructure"
    ImportDate  = "2024-01-15"
  }
}

# EC2 Configuration
module "imported_compute" {
  source = "./modules/compute"
  
  # Match existing instance configuration
  instance_type = "t3.medium"  # From AWS console
  ami_id        = "ami-0c55b159cbfafe1d0"  # Current AMI
  key_name      = "production-key"
  
  vpc_id              = module.imported_networking.vpc_id
  private_subnet_ids  = module.imported_networking.private_subnet_ids
  security_group_ids  = [module.imported_security.web_sg_id]
  
  tags = {
    Name        = "imported-web-server"
    Environment = "production"
    ImportDate  = "2024-01-15"
  }
}
```

### Phase 3: Import Execution

```bash
#!/bin/bash
# execute-import.sh

set -e  # Exit on any error

echo "🚀 Starting Terraform import process..."

# Import function with error handling
import_resource() {
    local tf_address=$1
    local aws_id=$2
    local resource_type=$3
    
    echo "📦 Importing $resource_type: $aws_id -> $tf_address"
    
    if terraform import "$tf_address" "$aws_id"; then
        echo "✅ Successfully imported $resource_type"
    else
        echo "❌ Failed to import $resource_type"
        echo "🔄 Rolling back..."
        terraform state rm "$tf_address" 2>/dev/null || true
        return 1
    fi
}

# Network resources (order matters!)
import_resource "module.imported_networking.aws_vpc.main" "vpc-0123456789abcdef0" "VPC"
import_resource "module.imported_networking.aws_internet_gateway.main" "igw-0123456789abcdef0" "Internet Gateway"
import_resource "module.imported_networking.aws_subnet.private[0]" "subnet-0123456789abcdef0" "Private Subnet 1"
import_resource "module.imported_networking.aws_subnet.private[1]" "subnet-0123456789abcdef1" "Private Subnet 2"
import_resource "module.imported_networking.aws_subnet.public[0]" "subnet-0123456789abcdef2" "Public Subnet 1"
import_resource "module.imported_networking.aws_subnet.public[1]" "subnet-0123456789abcdef3" "Public Subnet 2"

# Security groups
import_resource "module.imported_security.aws_security_group.web" "sg-0123456789abcdef0" "Web Security Group"
import_resource "module.imported_security.aws_security_group.database" "sg-0123456789abcdef1" "Database Security Group"

# EC2 instances
import_resource "module.imported_compute.aws_instance.web[0]" "i-0123456789abcdef0" "Web Server 1"
import_resource "module.imported_compute.aws_instance.web[1]" "i-0123456789abcdef1" "Web Server 2"

echo "🎉 Import process completed successfully!"
```

### Phase 4: State Validation

```bash
#!/bin/bash
# validate-import.sh

echo "🔍 Validating imported infrastructure..."

# Check for drift
echo "📊 Running terraform plan to check for drift..."
if terraform plan -detailed-exitcode; then
    echo "✅ No configuration drift detected"
else
    exit_code=$?
    if [ $exit_code -eq 2 ]; then
        echo "⚠️  Configuration drift detected - review changes"
        terraform plan -out=drift.plan
    else
        echo "❌ Error in terraform plan"
        exit 1
    fi
fi

# Validate state consistency
echo "🏗️  Validating state consistency..."
terraform validate

# Check resource counts
expected_resources=25  # Adjust based on your import
actual_resources=$(terraform state list | wc -l)

if [ $actual_resources -eq $expected_resources ]; then
    echo "✅ Resource count matches expected: $actual_resources"
else
    echo "⚠️  Resource count mismatch. Expected: $expected_resources, Actual: $actual_resources"
fi

# Generate import report
echo "📋 Generating import report..."
cat > import-report.md << EOF
# Infrastructure Import Report

**Date**: $(date)
**Resources Imported**: $actual_resources
**Status**: $([ $actual_resources -eq $expected_resources ] && echo "✅ Success" || echo "⚠️  Needs Review")

## Imported Resources
\`\`\`
$(terraform state list)
\`\`\`

## Configuration Drift
$([ -f drift.plan ] && echo "⚠️ Drift detected - see drift.plan" || echo "✅ No drift detected")

## Next Steps
- [ ] Review and apply any configuration changes
- [ ] Update resource tags for consistency
- [ ] Test resource modifications in staging
- [ ] Document any manual configuration requirements
EOF

echo "📋 Import report generated: import-report.md"
```

---

## Module-Specific Import Guides

### VPC and Networking Resources

```hcl
# networking-import.tf
module "imported_vpc" {
  source = "../../modules/networking"
  
  # Required: Match existing VPC configuration exactly
  vpc_cidr                 = "10.0.0.0/16"
  enable_dns_hostnames     = true
  enable_dns_support       = true
  
  # Subnets - must match existing CIDR blocks
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  # Optional: Update tags after import
  tags = {
    Name         = "production-vpc"
    Environment  = "production"
    ManagedBy    = "terraform"
    ImportedFrom = "aws-console"
    ImportDate   = "2024-01-15"
  }
}
```

```bash
# Import VPC networking resources
#!/bin/bash

# VPC and basic networking
terraform import module.imported_vpc.aws_vpc.main vpc-0123456789abcdef0
terraform import module.imported_vpc.aws_internet_gateway.main igw-0123456789abcdef0
terraform import module.imported_vpc.aws_route_table.public rt-0123456789abcdef0

# Subnets (use array indexing)
terraform import 'module.imported_vpc.aws_subnet.private[0]' subnet-0123456789abcdef0
terraform import 'module.imported_vpc.aws_subnet.private[1]' subnet-0123456789abcdef1
terraform import 'module.imported_vpc.aws_subnet.private[2]' subnet-0123456789abcdef2

terraform import 'module.imported_vpc.aws_subnet.public[0]' subnet-0123456789abcdef3
terraform import 'module.imported_vpc.aws_subnet.public[1]' subnet-0123456789abcdef4
terraform import 'module.imported_vpc.aws_subnet.public[2]' subnet-0123456789abcdef5

# NAT Gateways and Elastic IPs
terraform import 'module.imported_vpc.aws_eip.nat[0]' eipalloc-0123456789abcdef0
terraform import 'module.imported_vpc.aws_nat_gateway.main[0]' nat-0123456789abcdef0
```

### EC2 Instances and Auto Scaling Groups

```hcl
# compute-import.tf
module "imported_compute" {
  source = "../../modules/compute"
  
  # Instance configuration - match existing
  instance_type = "t3.large"
  ami_id        = "ami-0c55b159cbfafe1d0"
  key_name      = "production-keypair"
  
  # Network configuration
  vpc_id             = module.imported_vpc.vpc_id
  subnet_ids         = module.imported_vpc.private_subnet_ids
  security_group_ids = [module.imported_security.web_sg_id]
  
  # Auto Scaling configuration
  asg_config = {
    min_size         = 2
    max_size         = 10
    desired_capacity = 4
    health_check_type = "ELB"
    health_check_grace_period = 300
  }
  
  # Load balancer target group
  target_group_arns = [module.imported_alb.target_group_arn]
  
  tags = {
    Name        = "web-servers"
    Environment = "production"
    Application = "webapp"
  }
}
```

```bash
# Import EC2 and ASG resources
#!/bin/bash

# Individual EC2 instances
terraform import 'module.imported_compute.aws_instance.web[0]' i-0123456789abcdef0
terraform import 'module.imported_compute.aws_instance.web[1]' i-0123456789abcdef1

# Launch template
terraform import module.imported_compute.aws_launch_template.web lt-0123456789abcdef0

# Auto Scaling Group
terraform import module.imported_compute.aws_autoscaling_group.web web-asg-production

# Auto Scaling Policies
terraform import module.imported_compute.aws_autoscaling_policy.scale_up web-scale-up-policy
terraform import module.imported_compute.aws_autoscaling_policy.scale_down web-scale-down-policy
```

### RDS Databases

```hcl
# database-import.tf
module "imported_database" {
  source = "../../modules/database"
  
  # Database configuration - match existing exactly
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.r5.xlarge"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true
  
  db_name  = "production_db"
  username = "admin"
  
  # Network configuration
  vpc_id             = module.imported_vpc.vpc_id
  db_subnet_group_name = "production-db-subnet-group"
  vpc_security_group_ids = [module.imported_security.database_sg_id]
  
  # Backup configuration
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"
  
  # Performance Insights
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  tags = {
    Name        = "production-database"
    Environment = "production"
    BackupType  = "automated"
  }
}
```

```bash
# Import RDS resources
#!/bin/bash

# RDS instance
terraform import module.imported_database.aws_db_instance.main production-db-instance

# DB subnet group
terraform import module.imported_database.aws_db_subnet_group.main production-db-subnet-group

# Parameter group (if custom)
terraform import module.imported_database.aws_db_parameter_group.main production-db-params

# Option group (if exists)
terraform import module.imported_database.aws_db_option_group.main production-db-options

# DB cluster (for Aurora)
# terraform import module.imported_database.aws_rds_cluster.main production-aurora-cluster
```

### S3 Buckets

```hcl
# storage-import.tf
module "imported_storage" {
  source = "../../modules/storage"
  
  # S3 bucket configuration
  bucket_name = "production-app-assets-bucket"
  
  # Versioning and lifecycle
  versioning_enabled = true
  
  lifecycle_rules = [
    {
      id     = "transition-to-ia"
      status = "Enabled"
      transitions = [
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
  
  # Public access settings
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  # Server-side encryption
  sse_algorithm     = "AES256"
  kms_master_key_id = null
  
  tags = {
    Name         = "production-assets"
    Environment  = "production"
    ContentType  = "static-assets"
  }
}
```

```bash
# Import S3 resources
#!/bin/bash

# S3 bucket
terraform import module.imported_storage.aws_s3_bucket.main production-app-assets-bucket

# Bucket versioning
terraform import module.imported_storage.aws_s3_bucket_versioning.main production-app-assets-bucket

# Bucket encryption
terraform import module.imported_storage.aws_s3_bucket_server_side_encryption_configuration.main production-app-assets-bucket

# Public access block
terraform import module.imported_storage.aws_s3_bucket_public_access_block.main production-app-assets-bucket

# Bucket policy (if exists)
terraform import module.imported_storage.aws_s3_bucket_policy.main production-app-assets-bucket

# Lifecycle configuration
terraform import module.imported_storage.aws_s3_bucket_lifecycle_configuration.main production-app-assets-bucket
```

### ALB/ELB Load Balancers

```hcl
# load-balancer-import.tf
module "imported_alb" {
  source = "../../modules/load-balancer"
  
  # Load balancer configuration
  name               = "production-web-alb"
  load_balancer_type = "application"
  
  vpc_id     = module.imported_vpc.vpc_id
  subnet_ids = module.imported_vpc.public_subnet_ids
  
  security_group_ids = [module.imported_security.alb_sg_id]
  
  # Listeners and target groups
  listeners = [
    {
      port     = 80
      protocol = "HTTP"
      default_action = {
        type = "redirect"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
    },
    {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2019-07"
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
      default_action = {
        type             = "forward"
        target_group_arn = module.imported_alb.target_group_arn
      }
    }
  ]
  
  target_groups = [
    {
      name     = "web-servers-tg"
      port     = 80
      protocol = "HTTP"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        path                = "/health"
        matcher             = "200"
      }
    }
  ]
  
  tags = {
    Name        = "production-web-alb"
    Environment = "production"
  }
}
```

```bash
# Import ALB resources
#!/bin/bash

# Application Load Balancer
terraform import module.imported_alb.aws_lb.main arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/production-web-alb/1234567890123456

# Target Group
terraform import module.imported_alb.aws_lb_target_group.web arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-servers-tg/1234567890123456

# Listeners
terraform import 'module.imported_alb.aws_lb_listener.http' arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/production-web-alb/1234567890123456/1234567890123456
terraform import 'module.imported_alb.aws_lb_listener.https' arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/production-web-alb/1234567890123456/1234567890123457

# Target Group Attachments
terraform import 'module.imported_alb.aws_lb_target_group_attachment.web[0]' arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-servers-tg/1234567890123456/i-0123456789abcdef0
```

### IAM Roles and Policies

```hcl
# iam-import.tf
module "imported_iam" {
  source = "../../modules/iam"
  
  # EC2 instance role
  ec2_roles = [
    {
      name = "EC2-WebServer-Role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
              Service = "ec2.amazonaws.com"
            }
          }
        ]
      })
      
      policies = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
      
      inline_policies = [
        {
          name = "S3Access"
          policy = jsonencode({
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Action = [
                  "s3:GetObject",
                  "s3:PutObject"
                ]
                Resource = "arn:aws:s3:::production-app-assets-bucket/*"
              }
            ]
          })
        }
      ]
    }
  ]
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

```bash
# Import IAM resources
#!/bin/bash

# IAM Role
terraform import module.imported_iam.aws_iam_role.ec2_webserver EC2-WebServer-Role

# Instance Profile
terraform import module.imported_iam.aws_iam_instance_profile.ec2_webserver EC2-WebServer-Role

# Policy Attachments
terraform import module.imported_iam.aws_iam_role_policy_attachment.cloudwatch_agent EC2-WebServer-Role/arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
terraform import module.imported_iam.aws_iam_role_policy_attachment.ssm_managed EC2-WebServer-Role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Inline Policy
terraform import module.imported_iam.aws_iam_role_policy.s3_access EC2-WebServer-Role:S3Access
```

### CloudFront Distributions

```hcl
# cdn-import.tf
module "imported_cdn" {
  source = "../../modules/cdn"
  
  # CloudFront distribution configuration
  distribution_config = {
    comment             = "Production web application CDN"
    default_root_object = "index.html"
    enabled             = true
    price_class         = "PriceClass_All"
    
    origins = [
      {
        domain_name = "production-web-alb-1234567890.us-east-1.elb.amazonaws.com"
        origin_id   = "ALB-production-web"
        
        custom_origin_config = {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    ]
    
    default_cache_behavior = {
      target_origin_id         = "ALB-production-web"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      
      forwarded_values = {
        query_string = false
        headers      = ["Host"]
        cookies = {
          forward = "none"
        }
      }
    }
    
    restrictions = {
      geo_restriction = {
        restriction_type = "none"
      }
    }
    
    viewer_certificate = {
      acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2019"
    }
  }
  
  tags = {
    Name        = "production-web-cdn"
    Environment = "production"
  }
}
```

```bash
# Import CloudFront resources
#!/bin/bash

# CloudFront Distribution
terraform import module.imported_cdn.aws_cloudfront_distribution.main E1234567890123

# Origin Access Identity (if used)
terraform import module.imported_cdn.aws_cloudfront_origin_access_identity.main E1234567890123
```

### Route53 DNS Records

```hcl
# dns-import.tf
module "imported_dns" {
  source = "../../modules/dns"
  
  # Hosted zone configuration
  domain_name = "example.com"
  
  # DNS records
  records = [
    {
      name = ""
      type = "A"
      alias = {
        name                   = "d1234567890123.cloudfront.net"
        zone_id               = "Z2FDTNDATAQYW2"  # CloudFront zone ID
        evaluate_target_health = false
      }
    },
    {
      name = "www"
      type = "CNAME"
      ttl  = 300
      records = ["example.com"]
    },
    {
      name = "api"
      type = "A"
      alias = {
        name                   = "production-web-alb-1234567890.us-east-1.elb.amazonaws.com"
        zone_id               = "Z35SXDOTRQ7X7K"  # ALB zone ID for us-east-1
        evaluate_target_health = true
      }
    }
  ]
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

```bash
# Import Route53 resources
#!/bin/bash

# Hosted Zone
terraform import module.imported_dns.aws_route53_zone.main Z1234567890123

# DNS Records
terraform import 'module.imported_dns.aws_route53_record.root' Z1234567890123_example.com_A
terraform import 'module.imported_dns.aws_route53_record.www' Z1234567890123_www.example.com_CNAME
terraform import 'module.imported_dns.aws_route53_record.api' Z1234567890123_api.example.com_A
```

---

## Common Challenges and Solutions

### Resource Dependencies

**Challenge**: Import order matters due to resource dependencies

```bash
# WRONG - This will fail
terraform import module.compute.aws_instance.web i-0123456789abcdef0
terraform import module.networking.aws_vpc.main vpc-0123456789abcdef0

# RIGHT - Import in dependency order
terraform import module.networking.aws_vpc.main vpc-0123456789abcdef0
terraform import module.networking.aws_subnet.private subnet-0123456789abcdef0
terraform import module.compute.aws_instance.web i-0123456789abcdef0
```

**Solution**: Dependency-aware import script

```bash
#!/bin/bash
# dependency-aware-import.sh

declare -A DEPENDENCY_LEVELS=(
    [0]="vpc internet_gateway"
    [1]="subnet route_table security_group"
    [2]="nat_gateway eip"
    [3]="instance rds_instance"
    [4]="load_balancer target_group"
    [5]="route53_record cloudfront_distribution"
)

for level in $(seq 0 5); do
    echo "🔄 Importing level $level resources..."
    for resource_type in ${DEPENDENCY_LEVELS[$level]}; do
        import_resources_of_type "$resource_type"
    done
done
```

### Naming Conflicts

**Challenge**: Terraform resource names must be unique but AWS resources may have similar names

```hcl
# WRONG - Duplicate names
resource "aws_security_group" "web" { ... }
resource "aws_security_group" "web" { ... }

# RIGHT - Use descriptive, unique names
resource "aws_security_group" "web_frontend" { ... }
resource "aws_security_group" "web_backend" { ... }
```

**Solution**: Naming convention strategy

```bash
#!/bin/bash
# generate-unique-names.sh

# Function to generate unique Terraform resource names
generate_tf_name() {
    local aws_resource_id=$1
    local resource_type=$2
    local environment=$3
    
    # Extract meaningful parts from AWS resource
    case $resource_type in
        "aws_security_group")
            # sg-0123abc -> security_group_0123abc
            echo "${resource_type}_${aws_resource_id#sg-}"
            ;;
        "aws_instance")
            # i-0123abc -> instance_0123abc
            echo "${resource_type}_${aws_resource_id#i-}"
            ;;
        *)
            echo "${resource_type}_${aws_resource_id//[-.]/_}"
            ;;
    esac
}

# Usage
tf_name=$(generate_tf_name "sg-0123456789abcdef0" "aws_security_group" "production")
echo "Terraform name: $tf_name"
```

### Configuration Drift

**Challenge**: Imported resources may not match Terraform configuration exactly

```bash
# Detect and resolve configuration drift
terraform plan -detailed-exitcode
if [ $? -eq 2 ]; then
    echo "⚠️  Configuration drift detected"
    
    # Generate plan file for review
    terraform plan -out=drift.plan
    
    # Show what changes would be made
    terraform show drift.plan
    
    # Option 1: Update Terraform to match AWS
    # Edit .tf files to match existing AWS configuration
    
    # Option 2: Update AWS to match Terraform (DANGEROUS)
    # terraform apply drift.plan
fi
```

**Solution**: Configuration alignment strategy

```bash
#!/bin/bash
# align-configuration.sh

echo "🔍 Analyzing configuration drift..."

# Extract current AWS configuration
aws ec2 describe-instances --instance-ids i-0123456789abcdef0 \
    --query 'Reservations[0].Instances[0]' > current-instance-config.json

# Compare with Terraform configuration
terraform show -json terraform.tfstate \
    | jq '.values.root_module.resources[] | select(.address=="module.compute.aws_instance.web")' \
    > terraform-instance-config.json

# Generate alignment report
python3 << EOF
import json

# Load configurations
with open('current-instance-config.json') as f:
    aws_config = json.load(f)

with open('terraform-instance-config.json') as f:
    tf_config = json.load(f)

# Compare configurations
print("🔍 Configuration Differences:")
print(f"AWS Instance Type: {aws_config.get('InstanceType')}")
print(f"Terraform Instance Type: {tf_config['values'].get('instance_type')}")

if aws_config.get('InstanceType') != tf_config['values'].get('instance_type'):
    print("❌ Instance type mismatch - update Terraform configuration")
else:
    print("✅ Instance type matches")
EOF

# Clean up
rm current-instance-config.json terraform-instance-config.json
```

### Import Failures and Recovery

**Challenge**: Import process may fail partway through

```bash
#!/bin/bash
# robust-import-with-recovery.sh

set -e

# Import state tracking
IMPORT_LOG="/tmp/terraform-import.log"
FAILED_IMPORTS="/tmp/failed-imports.list"

# Clear previous logs
> "$IMPORT_LOG"
> "$FAILED_IMPORTS"

# Robust import function
robust_import() {
    local tf_address=$1
    local aws_id=$2
    local description=$3
    
    echo "📦 Importing: $description" | tee -a "$IMPORT_LOG"
    echo "   Address: $tf_address" | tee -a "$IMPORT_LOG"
    echo "   AWS ID: $aws_id" | tee -a "$IMPORT_LOG"
    
    if terraform import "$tf_address" "$aws_id" 2>&1 | tee -a "$IMPORT_LOG"; then
        echo "✅ Success: $description" | tee -a "$IMPORT_LOG"
        return 0
    else
        echo "❌ Failed: $description" | tee -a "$IMPORT_LOG"
        echo "$tf_address|$aws_id|$description" >> "$FAILED_IMPORTS"
        
        # Clean up failed import
        terraform state rm "$tf_address" 2>/dev/null || true
        
        return 1
    fi
}

# Retry mechanism for failed imports
retry_failed_imports() {
    if [ ! -s "$FAILED_IMPORTS" ]; then
        echo "✅ No failed imports to retry"
        return 0
    fi
    
    echo "🔄 Retrying failed imports..."
    
    while IFS='|' read -r tf_address aws_id description; do
        echo "🔄 Retrying: $description"
        
        # Check if resource still exists in AWS
        case "$tf_address" in
            *aws_instance*)
                if aws ec2 describe-instances --instance-ids "$aws_id" >/dev/null 2>&1; then
                    robust_import "$tf_address" "$aws_id" "$description (retry)"
                else
                    echo "⚠️  Resource no longer exists in AWS: $aws_id"
                fi
                ;;
            *aws_vpc*)
                if aws ec2 describe-vpcs --vpc-ids "$aws_id" >/dev/null 2>&1; then
                    robust_import "$tf_address" "$aws_id" "$description (retry)"
                else
                    echo "⚠️  Resource no longer exists in AWS: $aws_id"
                fi
                ;;
        esac
    done < "$FAILED_IMPORTS"
}

# Execute imports with error handling
echo "🚀 Starting robust import process..."

# Import resources
robust_import "module.networking.aws_vpc.main" "vpc-0123456789abcdef0" "Production VPC"
robust_import "module.compute.aws_instance.web" "i-0123456789abcdef0" "Web Server Instance"

# Retry failed imports
retry_failed_imports

# Generate final report
echo "📋 Import Summary:"
echo "Total attempts: $(wc -l < "$IMPORT_LOG" | xargs)"
echo "Failed imports: $(wc -l < "$FAILED_IMPORTS" | xargs)"

if [ -s "$FAILED_IMPORTS" ]; then
    echo "❌ Some imports failed. Check $FAILED_IMPORTS for details."
    exit 1
else
    echo "✅ All imports completed successfully!"
fi
```

---

## Post-Import Validation

### Comprehensive Plan Verification

```bash
#!/bin/bash
# comprehensive-validation.sh

echo "🔍 Post-import validation starting..."

# 1. Configuration validation
echo "📋 Step 1: Terraform configuration validation"
if terraform validate; then
    echo "✅ Configuration is valid"
else
    echo "❌ Configuration validation failed"
    exit 1
fi

# 2. Plan verification (should show no changes)
echo "📋 Step 2: Plan verification"
terraform plan -detailed-exitcode -out=verification.plan

case $? in
    0)
        echo "✅ No changes required - perfect alignment"
        ;;
    1)
        echo "❌ Error in terraform plan"
        exit 1
        ;;
    2)
        echo "⚠️  Changes detected - reviewing..."
        terraform show verification.plan
        
        echo "Do you want to apply these changes? (y/n)"
        read -r response
        if [ "$response" = "y" ]; then
            terraform apply verification.plan
        else
            echo "⚠️  Manual review required"
        fi
        ;;
esac

# 3. State consistency check
echo "📋 Step 3: State consistency verification"
terraform state list > state-resources.list
echo "📊 Resources in state: $(wc -l < state-resources.list)"

# 4. Resource tagging validation
echo "📋 Step 4: Resource tagging validation"
check_resource_tags() {
    local resource_type=$1
    
    echo "Checking tags for $resource_type resources..."
    
    terraform state list | grep "$resource_type" | while read -r resource; do
        tags=$(terraform state show "$resource" | grep -A 10 "tags.*=" | grep -E '"[^"]+"\s*=' | wc -l)
        if [ "$tags" -lt 3 ]; then
            echo "⚠️  $resource has fewer than 3 tags"
        else
            echo "✅ $resource is properly tagged"
        fi
    done
}

check_resource_tags "aws_instance"
check_resource_tags "aws_vpc"
check_resource_tags "aws_s3_bucket"

# 5. Security validation
echo "📋 Step 5: Security configuration validation"
security_check() {
    # Check for overly permissive security groups
    terraform state list | grep "aws_security_group" | while read -r sg; do
        # Extract security group rules
        terraform state show "$sg" | grep -E "cidr_blocks.*0\.0\.0\.0/0" && 
            echo "⚠️  $sg allows traffic from 0.0.0.0/0"
    done
    
    # Check for unencrypted resources
    terraform state list | grep -E "(aws_s3_bucket|aws_rds|aws_ebs)" | while read -r resource; do
        encryption=$(terraform state show "$resource" | grep -i encrypt || echo "not found")
        if [[ "$encryption" == "not found" ]]; then
            echo "⚠️  $resource may not have encryption configured"
        fi
    done
}

security_check

echo "✅ Post-import validation complete"
```

### Resource Tagging Standardization

```bash
#!/bin/bash
# standardize-tags.sh

echo "🏷️  Standardizing resource tags..."

# Define standard tags
STANDARD_TAGS='
{
  "Environment": "production",
  "ManagedBy": "terraform",
  "Project": "web-application",
  "Owner": "devops-team",
  "CostCenter": "engineering",
  "ImportDate": "'$(date +%Y-%m-%d)'"
}'

# Function to update tags for a resource type
update_resource_tags() {
    local resource_type=$1
    local aws_service=$2
    
    echo "Updating tags for $resource_type resources..."
    
    terraform state list | grep "$resource_type" | while read -r tf_resource; do
        # Extract AWS resource ID
        aws_id=$(terraform state show "$tf_resource" | grep -E "^\s*id\s*=" | cut -d'"' -f2)
        
        if [ -n "$aws_id" ]; then
            echo "📝 Updating tags for $tf_resource ($aws_id)"
            
            case $aws_service in
                "ec2")
                    aws ec2 create-tags --resources "$aws_id" --tags \
                        Key=Environment,Value=production \
                        Key=ManagedBy,Value=terraform \
                        Key=Project,Value=web-application \
                        Key=ImportDate,Value="$(date +%Y-%m-%d)"
                    ;;
                "s3")
                    aws s3api put-bucket-tagging --bucket "$aws_id" --tagging "$STANDARD_TAGS"
                    ;;
                "rds")
                    aws rds add-tags-to-resource --resource-name "$aws_id" \
                        --tags Key=Environment,Value=production \
                               Key=ManagedBy,Value=terraform \
                               Key=Project,Value=web-application \
                               Key=ImportDate,Value="$(date +%Y-%m-%d)"
                    ;;
            esac
        fi
    done
}

# Update tags for different resource types
update_resource_tags "aws_instance" "ec2"
update_resource_tags "aws_vpc" "ec2"
update_resource_tags "aws_subnet" "ec2"
update_resource_tags "aws_security_group" "ec2"
update_resource_tags "aws_s3_bucket" "s3"
update_resource_tags "aws_db_instance" "rds"

echo "✅ Tag standardization complete"

# Refresh Terraform state to reflect tag changes
echo "🔄 Refreshing Terraform state..."
terraform refresh

echo "📊 Generating tag compliance report..."
terraform state list | while read -r resource; do
    echo "Resource: $resource"
    terraform state show "$resource" | grep -A 20 "tags.*=" || echo "  No tags found"
    echo "---"
done > tag-compliance-report.txt

echo "📋 Tag compliance report generated: tag-compliance-report.txt"
```

### Performance Impact Assessment

```bash
#!/bin/bash
# performance-assessment.sh

echo "📊 Assessing performance impact of import..."

# Capture baseline metrics
BASELINE_FILE="/tmp/baseline-metrics.json"
CURRENT_FILE="/tmp/current-metrics.json"

capture_metrics() {
    local output_file=$1
    
    # CloudWatch metrics for key resources
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ec2_cpu_utilization": $(aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=i-0123456789abcdef0 \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[0].Average' --output text 2>/dev/null || echo "null"),
  "rds_cpu_utilization": $(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=production-db \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[0].Average' --output text 2>/dev/null || echo "null"),
  "alb_request_count": $(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=app/production-web-alb/1234567890123456 \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' --output text 2>/dev/null || echo "null")
}
EOF
}

# Capture baseline before any changes
echo "📊 Capturing baseline metrics..."
capture_metrics "$BASELINE_FILE"

# Wait for any changes to take effect
echo "⏳ Waiting for metrics to stabilize..."
sleep 300  # 5 minutes

# Capture current metrics
echo "📊 Capturing current metrics..."
capture_metrics "$CURRENT_FILE"

# Compare metrics
echo "📈 Performance Impact Analysis:"
python3 << EOF
import json
import sys

try:
    with open('$BASELINE_FILE') as f:
        baseline = json.load(f)
    with open('$CURRENT_FILE') as f:
        current = json.load(f)
    
    print("📊 Metric Comparison:")
    print(f"Baseline Time: {baseline['timestamp']}")
    print(f"Current Time:  {current['timestamp']}")
    print()
    
    metrics = ['ec2_cpu_utilization', 'rds_cpu_utilization', 'alb_request_count']
    
    for metric in metrics:
        baseline_val = baseline.get(metric, 'null')
        current_val = current.get(metric, 'null')
        
        if baseline_val != 'null' and current_val != 'null':
            baseline_num = float(baseline_val)
            current_num = float(current_val)
            change = ((current_num - baseline_num) / baseline_num) * 100
            
            status = "✅" if abs(change) < 5 else "⚠️" if abs(change) < 15 else "🚨"
            print(f"{status} {metric.replace('_', ' ').title()}: {baseline_num:.2f} -> {current_num:.2f} ({change:+.1f}%)")
        else:
            print(f"❓ {metric.replace('_', ' ').title()}: Insufficient data")
            
except Exception as e:
    print(f"❌ Error analyzing metrics: {e}")
    sys.exit(1)
EOF

# Application-level health checks
echo "🔍 Application health verification..."
health_check() {
    local endpoint=$1
    local expected_status=$2
    
    echo "Testing: $endpoint"
    response=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint")
    
    if [ "$response" = "$expected_status" ]; then
        echo "✅ $endpoint returned $response"
    else
        echo "❌ $endpoint returned $response (expected $expected_status)"
    fi
}

# Test application endpoints
health_check "https://example.com/health" "200"
health_check "https://api.example.com/status" "200"

# Database connectivity test
echo "🗄️  Database connectivity test..."
if command -v mysql >/dev/null 2>&1; then
    mysql -h production-db.cluster-abc123.us-east-1.rds.amazonaws.com -u admin -p"$DB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Database connection successful"
    else
        echo "❌ Database connection failed"
    fi
else
    echo "⚠️  MySQL client not available for testing"
fi

echo "📋 Performance assessment complete"
```

---

## Automation and Tooling

### Bulk Import Script

```bash
#!/bin/bash
# bulk-import-automation.sh

set -e

# Configuration
CONFIG_FILE="import-config.yaml"
LOG_DIR="/tmp/terraform-import-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/import_$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting bulk import automation"

# Parse configuration file
parse_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "❌ Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Convert YAML to JSON for easier parsing
    python3 -c "
import yaml, json, sys
with open('$CONFIG_FILE', 'r') as f:
    data = yaml.safe_load(f)
print(json.dumps(data, indent=2))
" > /tmp/import-config.json
}

# Import orchestration
orchestrate_imports() {
    local config_file="/tmp/import-config.json"
    
    # Get import phases
    phases=$(jq -r '.import_phases | keys[]' "$config_file")
    
    for phase in $phases; do
        log "📋 Starting Phase $phase"
        
        # Get resources for this phase
        resources=$(jq -r ".import_phases[\"$phase\"][]" "$config_file")
        
        for resource_config in $resources; do
            tf_address=$(echo "$resource_config" | jq -r '.terraform_address')
            aws_id=$(echo "$resource_config" | jq -r '.aws_id')
            description=$(echo "$resource_config" | jq -r '.description // "No description"')
            
            log "📦 Importing: $description"
            log "   Terraform Address: $tf_address"
            log "   AWS ID: $aws_id"
            
            if terraform import "$tf_address" "$aws_id" >> "$LOG_FILE" 2>&1; then
                log "✅ Success: $description"
            else
                log "❌ Failed: $description"
                
                # Optional: Continue or halt on failure
                if [ "${HALT_ON_FAILURE:-true}" = "true" ]; then
                    log "🛑 Halting due to import failure"
                    exit 1
                fi
            fi
        done
        
        # Phase validation
        log "🔍 Validating Phase $phase"
        if terraform plan -detailed-exitcode >> "$LOG_FILE" 2>&1; then
            log "✅ Phase $phase validation passed"
        else
            log "⚠️  Phase $phase has configuration drift"
        fi
        
        # Optional: Wait between phases
        if [ "${PHASE_DELAY:-0}" -gt 0 ]; then
            log "⏳ Waiting ${PHASE_DELAY} seconds before next phase"
            sleep "${PHASE_DELAY}"
        fi
    done
}

# Validation and reporting
generate_report() {
    local report_file="$LOG_DIR/import_report_$TIMESTAMP.md"
    
    log "📋 Generating import report"
    
    cat > "$report_file" << EOF
# Infrastructure Import Report

**Date**: $(date)
**Operator**: $(whoami)
**Environment**: $(terraform workspace show)

## Import Summary

\`\`\`bash
$(grep -E "(✅|❌)" "$LOG_FILE" | sort | uniq -c)
\`\`\`

## Resources in State

\`\`\`
$(terraform state list | wc -l) total resources
\`\`\`

## Configuration Status

\`\`\`bash
$(terraform plan -detailed-exitcode >/dev/null 2>&1 && echo "✅ No drift detected" || echo "⚠️ Configuration drift detected")
\`\`\`

## Detailed Log

See: $LOG_FILE

## Next Steps

- [ ] Review configuration drift
- [ ] Update resource tags
- [ ] Test application functionality
- [ ] Update documentation
- [ ] Schedule drift monitoring

EOF

    log "📄 Report generated: $report_file"
}

# Main execution
main() {
    log "🔧 Parsing configuration"
    parse_config
    
    log "🏗️  Creating pre-import backup"
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "terraform.tfstate.backup.$TIMESTAMP"
        log "✅ State backup created"
    fi
    
    log "🎯 Starting orchestrated import"
    orchestrate_imports
    
    log "📊 Final validation"
    terraform validate
    
    log "📋 Generating report"
    generate_report
    
    log "🎉 Bulk import automation complete"
}

# Example configuration file (import-config.yaml)
create_example_config() {
    cat > "$CONFIG_FILE" << 'EOF'
import_phases:
  "1_networking":
    - terraform_address: "module.networking.aws_vpc.main"
      aws_id: "vpc-0123456789abcdef0"
      description: "Production VPC"
    - terraform_address: "module.networking.aws_subnet.private[0]"
      aws_id: "subnet-0123456789abcdef0"
      description: "Private Subnet AZ-a"
    
  "2_security":
    - terraform_address: "module.security.aws_security_group.web"
      aws_id: "sg-0123456789abcdef0"
      description: "Web Security Group"
    
  "3_compute":
    - terraform_address: "module.compute.aws_instance.web[0]"
      aws_id: "i-0123456789abcdef0"
      description: "Web Server Instance"

settings:
  halt_on_failure: true
  phase_delay: 30
  backup_state: true
EOF
    
    log "📝 Example configuration created: $CONFIG_FILE"
}

# Script arguments handling
case "${1:-}" in
    "init")
        create_example_config
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [init]"
        echo "  init: Create example configuration file"
        echo "  (no args): Run bulk import"
        exit 1
        ;;
esac
```

### Terraformer Integration

```bash
#!/bin/bash
# terraformer-integration.sh

# Install and use Terraformer for automated discovery and import

log() {
    echo "$(date '+%H:%M:%S') - $1"
}

# Install Terraformer if not present
install_terraformer() {
    if ! command -v terraformer >/dev/null 2>&1; then
        log "📥 Installing Terraformer..."
        
        case "$(uname -s)" in
            "Darwin")
                brew install terraformer
                ;;
            "Linux")
                curl -LO https://github.com/GoogleCloudPlatform/terraformer/releases/download/0.8.24/terraformer-linux-amd64
                chmod +x terraformer-linux-amd64
                sudo mv terraformer-linux-amd64 /usr/local/bin/terraformer
                ;;
        esac
        
        log "✅ Terraformer installed"
    fi
}

# Generate Terraform configurations using Terraformer
generate_configs() {
    local aws_region=${1:-us-east-1}
    local output_dir="terraformer-output"
    
    log "🏗️  Generating Terraform configurations for region: $aws_region"
    
    # Create output directory
    mkdir -p "$output_dir"
    cd "$output_dir"
    
    # Initialize Terraform
    terraform init
    
    # Generate configurations for different resource types
    local resources=("vpc" "subnet" "security_group" "ec2_instance" "rds" "s3" "elb" "route53")
    
    for resource in "${resources[@]}"; do
        log "📦 Generating $resource configurations..."
        
        terraformer import aws \
            --resources="$resource" \
            --regions="$aws_region" \
            --profile="default" \
            --output="$output_dir" \
            --verbose || {
            log "⚠️  Failed to import $resource - continuing..."
            continue
        }
    done
    
    log "✅ Configuration generation complete"
    cd ..
}

# Merge generated configurations with existing modules
merge_with_modules() {
    local terraformer_dir="terraformer-output"
    local modules_dir="../modules"
    
    log "🔄 Merging generated configurations with existing modules..."
    
    # Process each generated resource file
    find "$terraformer_dir" -name "*.tf" | while read -r tf_file; do
        resource_type=$(basename "$tf_file" .tf)
        
        case $resource_type in
            "vpc"|"subnet"|"internet_gateway")
                target_module="$modules_dir/networking"
                ;;
            "security_group")
                target_module="$modules_dir/security"
                ;;
            "ec2_instance"|"launch_template")
                target_module="$modules_dir/compute"
                ;;
            "rds_instance"|"rds_cluster")
                target_module="$modules_dir/database"
                ;;
            "s3_bucket")
                target_module="$modules_dir/storage"
                ;;
            *)
                log "⚠️  Unknown resource type: $resource_type"
                continue
                ;;
        esac
        
        if [ -d "$target_module" ]; then
            log "📝 Processing $resource_type -> $target_module"
            
            # Create backup of existing module
            cp -r "$target_module" "${target_module}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Merge configurations (simplified - manual review needed)
            cat "$tf_file" >> "$target_module/imported_resources.tf"
            
            log "✅ Merged $resource_type into $target_module"
        else
            log "❌ Target module not found: $target_module"
        fi
    done
}

# Clean and optimize generated configurations
optimize_configs() {
    local output_dir="terraformer-output"
    
    log "🔧 Optimizing generated configurations..."
    
    # Remove provider configurations (use existing ones)
    find "$output_dir" -name "provider.tf" -delete
    
    # Consolidate variables
    find "$output_dir" -name "*.tf" -exec grep -l "variable" {} \; | while read -r file; do
        grep "variable" "$file" >> "$output_dir/consolidated_variables.tf"
        sed -i '/^variable/,/^}/d' "$file"
    done
    
    # Format configurations
    terraform fmt -recursive "$output_dir"
    
    log "✅ Configuration optimization complete"
}

# Main execution
main() {
    local region=${1:-us-east-1}
    
    log "🚀 Starting Terraformer integration for region: $region"
    
    install_terraformer
    generate_configs "$region"
    merge_with_modules
    optimize_configs
    
    log "🎉 Terraformer integration complete"
    log "📝 Review generated configurations in terraformer-output/"
    log "⚠️  Manual review and testing required before using in production"
}

# Usage information
usage() {
    echo "Usage: $0 [AWS_REGION]"
    echo "Example: $0 us-east-1"
    exit 1
}

# Execute based on arguments
if [ $# -eq 0 ]; then
    main "us-east-1"
elif [ $# -eq 1 ]; then
    main "$1"
else
    usage
fi
```

### Custom Import Tools

```python
#!/usr/bin/env python3
# custom-import-tool.py

"""
Custom tool for intelligent Terraform import workflows
"""

import json
import subprocess
import sys
import yaml
import argparse
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime
import boto3
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ImportTask:
    terraform_address: str
    aws_resource_id: str
    resource_type: str
    description: str
    dependencies: List[str]
    priority: int

class TerraformImportOrchestrator:
    def __init__(self, config_file: str, region: str = 'us-east-1'):
        self.config_file = config_file
        self.region = region
        self.aws_session = boto3.Session(region_name=region)
        self.import_tasks: List[ImportTask] = []
        self.completed_tasks: List[str] = []
        self.failed_tasks: List[str] = []
        
    def load_config(self):
        """Load import configuration from YAML file"""
        try:
            with open(self.config_file, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            sys.exit(1)
    
    def discover_resources(self) -> Dict[str, List[Dict]]:
        """Automatically discover AWS resources for import"""
        logger.info("🔍 Discovering AWS resources...")
        
        resources = {
            'vpcs': [],
            'subnets': [],
            'security_groups': [],
            'instances': [],
            'rds_instances': [],
            's3_buckets': []
        }
        
        # VPCs
        ec2 = self.aws_session.client('ec2')
        try:
            vpcs = ec2.describe_vpcs()['Vpcs']
            for vpc in vpcs:
                if not vpc.get('IsDefault', False):  # Skip default VPC
                    resources['vpcs'].append({
                        'id': vpc['VpcId'],
                        'cidr': vpc['CidrBlock'],
                        'tags': vpc.get('Tags', [])
                    })
        except Exception as e:
            logger.warning(f"Failed to discover VPCs: {e}")
        
        # EC2 Instances
        try:
            instances = ec2.describe_instances()
            for reservation in instances['Reservations']:
                for instance in reservation['Instances']:
                    if instance['State']['Name'] != 'terminated':
                        resources['instances'].append({
                            'id': instance['InstanceId'],
                            'type': instance['InstanceType'],
                            'vpc_id': instance.get('VpcId'),
                            'subnet_id': instance.get('SubnetId'),
                            'tags': instance.get('Tags', [])
                        })
        except Exception as e:
            logger.warning(f"Failed to discover EC2 instances: {e}")
        
        # RDS Instances
        rds = self.aws_session.client('rds')
        try:
            db_instances = rds.describe_db_instances()['DBInstances']
            for db in db_instances:
                resources['rds_instances'].append({
                    'id': db['DBInstanceIdentifier'],
                    'class': db['DBInstanceClass'],
                    'engine': db['Engine'],
                    'vpc_id': db.get('DBSubnetGroup', {}).get('VpcId'),
                    'tags': db.get('TagList', [])
                })
        except Exception as e:
            logger.warning(f"Failed to discover RDS instances: {e}")
        
        logger.info(f"✅ Discovery complete: {sum(len(v) for v in resources.values())} resources found")
        return resources
    
    def generate_import_plan(self, resources: Dict[str, List[Dict]]) -> List[ImportTask]:
        """Generate ordered import plan based on dependencies"""
        tasks = []
        
        # Priority-based ordering
        priority_map = {
            'vpc': 1,
            'subnet': 2,
            'security_group': 3,
            'instance': 4,
            'rds_instance': 5,
            's3_bucket': 1  # Independent resource
        }
        
        # Generate VPC import tasks
        for i, vpc in enumerate(resources['vpcs']):
            tasks.append(ImportTask(
                terraform_address=f"module.networking.aws_vpc.imported_{i}",
                aws_resource_id=vpc['id'],
                resource_type='aws_vpc',
                description=f"VPC {vpc['id']} ({vpc['cidr']})",
                dependencies=[],
                priority=priority_map['vpc']
            ))
        
        # Generate instance import tasks
        for i, instance in enumerate(resources['instances']):
            dependencies = []
            if instance.get('vpc_id'):
                # Find corresponding VPC task
                vpc_tasks = [t for t in tasks if t.aws_resource_id == instance['vpc_id']]
                if vpc_tasks:
                    dependencies.append(vpc_tasks[0].terraform_address)
            
            tasks.append(ImportTask(
                terraform_address=f"module.compute.aws_instance.imported_{i}",
                aws_resource_id=instance['id'],
                resource_type='aws_instance',
                description=f"EC2 {instance['id']} ({instance['type']})",
                dependencies=dependencies,
                priority=priority_map['instance']
            ))
        
        # Sort by priority and dependencies
        return sorted(tasks, key=lambda x: (x.priority, len(x.dependencies)))
    
    def execute_import(self, task: ImportTask) -> bool:
        """Execute single import task"""
        logger.info(f"📦 Importing: {task.description}")
        
        # Check dependencies
        for dep in task.dependencies:
            if dep not in self.completed_tasks:
                logger.warning(f"⚠️  Dependency not completed: {dep}")
                return False
        
        # Execute terraform import
        cmd = ['terraform', 'import', task.terraform_address, task.aws_resource_id]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode == 0:
                logger.info(f"✅ Import successful: {task.terraform_address}")
                self.completed_tasks.append(task.terraform_address)
                return True
            else:
                logger.error(f"❌ Import failed: {task.terraform_address}")
                logger.error(f"Error: {result.stderr}")
                self.failed_tasks.append(task.terraform_address)
                return False
                
        except subprocess.TimeoutExpired:
            logger.error(f"⏱️  Import timeout: {task.terraform_address}")
            self.failed_tasks.append(task.terraform_address)
            return False
        except Exception as e:
            logger.error(f"💥 Import exception: {e}")
            self.failed_tasks.append(task.terraform_address)
            return False
    
    def validate_import(self) -> bool:
        """Validate imported resources"""
        logger.info("🔍 Validating imported resources...")
        
        try:
            # Run terraform plan
            result = subprocess.run(
                ['terraform', 'plan', '-detailed-exitcode'],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                logger.info("✅ No configuration drift detected")
                return True
            elif result.returncode == 2:
                logger.warning("⚠️  Configuration drift detected:")
                logger.warning(result.stdout)
                return True  # Still valid, just has changes
            else:
                logger.error("❌ Validation failed")
                logger.error(result.stderr)
                return False
                
        except Exception as e:
            logger.error(f"💥 Validation exception: {e}")
            return False
    
    def generate_report(self):
        """Generate import report"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        report = f"""# Infrastructure Import Report

**Date**: {timestamp}
**Region**: {self.region}
**Configuration**: {self.config_file}

## Import Summary

- **Completed**: {len(self.completed_tasks)}
- **Failed**: {len(self.failed_tasks)}
- **Success Rate**: {len(self.completed_tasks) / (len(self.completed_tasks) + len(self.failed_tasks)) * 100:.1f}%

## Completed Imports

```
{chr(10).join(self.completed_tasks)}
```

## Failed Imports

```
{chr(10).join(self.failed_tasks)}
```

## Next Steps

- [ ] Review failed imports and retry if necessary
- [ ] Update Terraform configurations to match imported resources
- [ ] Test plan and apply to verify configuration
- [ ] Update resource tags and documentation
"""
        
        report_file = f"import_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(report_file, 'w') as f:
            f.write(report)
        
        logger.info(f"📋 Report generated: {report_file}")
    
    def run(self, discovery_mode: bool = False):
        """Main orchestration workflow"""
        logger.info("🚀 Starting Terraform import orchestration")
        
        if discovery_mode:
            # Auto-discovery mode
            resources = self.discover_resources()
            tasks = self.generate_import_plan(resources)
        else:
            # Configuration-driven mode
            config = self.load_config()
            tasks = [
                ImportTask(**task_config)
                for task_config in config.get('import_tasks', [])
            ]
        
        logger.info(f"📋 Generated {len(tasks)} import tasks")
        
        # Execute imports
        success_count = 0
        for task in tasks:
            if self.execute_import(task):
                success_count += 1
        
        # Validate results
        self.validate_import()
        
        # Generate report
        self.generate_report()
        
        logger.info(f"🎉 Import orchestration complete: {success_count}/{len(tasks)} successful")
        
        return success_count == len(tasks)

def main():
    parser = argparse.ArgumentParser(description='Terraform Import Orchestrator')
    parser.add_argument('--config', required=True, help='Configuration file path')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--discovery', action='store_true', help='Auto-discovery mode')
    parser.add_argument('--dry-run', action='store_true', help='Show plan without executing')
    
    args = parser.parse_args()
    
    orchestrator = TerraformImportOrchestrator(args.config, args.region)
    
    if args.dry_run:
        logger.info("🏃 Dry run mode - showing import plan only")
        if args.discovery:
            resources = orchestrator.discover_resources()
            tasks = orchestrator.generate_import_plan(resources)
        else:
            config = orchestrator.load_config()
            tasks = [ImportTask(**task_config) for task_config in config.get('import_tasks', [])]
        
        print(f"\n📋 Import Plan ({len(tasks)} tasks):")
        for i, task in enumerate(tasks, 1):
            print(f"{i}. {task.description}")
            print(f"   Address: {task.terraform_address}")
            print(f"   AWS ID: {task.aws_resource_id}")
            print(f"   Dependencies: {task.dependencies}")
            print()
    else:
        success = orchestrator.run(discovery_mode=args.discovery)
        sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
```

---

## Conclusion

This comprehensive guide provides a structured approach to importing existing AWS infrastructure into Terraform management using StackKit modules. Key takeaways:

### Critical Success Factors
1. **Thorough Planning**: Always assess and plan imports before execution
2. **Dependency Awareness**: Respect resource dependencies during import
3. **Backup Strategy**: Always have rollback plans and state backups
4. **Iterative Approach**: Import in phases, validate each step
5. **Post-Import Validation**: Thoroughly test imported infrastructure

### Best Practices Summary
- Start with low-risk resources (VPC, S3) before high-risk ones (EC2, RDS)
- Use consistent naming conventions for Terraform resources
- Maintain comprehensive logging throughout the process
- Implement automated validation and drift detection
- Document all manual configurations not captured by Terraform

### Automation Benefits
- Reduces human error through scripted imports
- Provides consistent, repeatable processes
- Enables bulk operations for large infrastructures
- Includes validation and reporting capabilities
- Supports rollback scenarios

Remember that importing infrastructure is just the first step. Ongoing management requires:
- Regular drift detection and remediation
- Consistent resource tagging and documentation
- Integration with CI/CD pipelines for future changes
- Monitoring and alerting for infrastructure changes
- Team training on Terraform best practices

For complex environments, consider engaging with AWS Professional Services or certified Terraform consultants to ensure a smooth transition to infrastructure as code.