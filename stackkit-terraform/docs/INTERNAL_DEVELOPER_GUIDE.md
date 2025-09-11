# 내부 개발자 가이드

## 목차
- [시작하기](#시작하기)
- [개발 워크플로](#개발-워크플로)
- [모듈 사용 패턴](#모듈-사용-패턴)
- [기여 가이드라인](#기여-가이드라인)
- [팀 협업](#팀-협업)
- [고급 주제](#고급-주제)

---

## 시작하기

### 레포지토리 구조

```
stackkit-terraform/
├── modules/                    # 재사용 가능한 Terraform 모듈
│   ├── compute/               # 컴퓨팅 관련 모듈 (EC2, ECS 등)
│   ├── networking/            # VPC, 서브넷, 로드 밸런서
│   ├── storage/               # S3, RDS, ElastiCache
│   ├── security/              # IAM, 보안 그룹, 인증서
│   └── monitoring/            # CloudWatch, 로깅, 알림
├── environments/              # 환경별 설정
│   ├── dev/
│   ├── staging/
│   └── prod/
├── examples/                  # 모듈 사용 예제
├── scripts/                   # 배포용 헬퍼 스크립트
├── docs/                      # 문서
└── tests/                     # 자동화된 테스트
```

### 로컬 개발 환경 설정

#### 전제 조건

특정 버전의 필수 도구들을 설치합니다:

```bash
# Terraform (필수 버전)
brew install terraform@1.6
terraform version  # v1.6.x 버전이 표시되어야 함

# AWS CLI v2
brew install awscli
aws --version      # aws-cli/2.x가 표시되어야 함

# 추가 도구들
brew install jq                 # JSON 처리
brew install pre-commit        # Git 훅
brew install tflint           # Terraform 린팅
brew install checkov          # 보안 스캐닝
```

#### 환경 설정

1. **AWS 자격 증명 설정**
```bash
# Configure AWS profiles for different environments
aws configure --profile stackkit-dev
aws configure --profile stackkit-staging  
aws configure --profile stackkit-prod

# Set default profile
export AWS_PROFILE=stackkit-dev
```

2. **Clone and Initialize Repository**
```bash
git clone https://github.com/company/stackkit-terraform.git
cd stackkit-terraform

# Install pre-commit hooks
pre-commit install

# Initialize Terraform (example for dev environment)
cd environments/dev
terraform init
```

3. **Required Environment Variables**
```bash
# Add to your ~/.bashrc or ~/.zshrc
export AWS_DEFAULT_REGION=us-west-2
export TF_VAR_environment=dev
export TF_VAR_project_name=stackkit
```

---

## Development Workflow

### Module Development Process

#### 1. Planning Phase
```bash
# Create feature branch
git checkout -b feature/new-module-name

# Create module structure
mkdir -p modules/service-name
cd modules/service-name

# Create basic module files
touch main.tf variables.tf outputs.tf versions.tf README.md
```

#### 2. Implementation Phase

**Module Structure Template:**
```hcl
# versions.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# variables.tf
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

# main.tf
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    CreatedBy   = "stackkit-terraform"
  }
}

# outputs.tf
output "resource_id" {
  description = "ID of the created resource"
  value       = aws_resource.example.id
}
```

#### 3. Testing Procedures

**Local Testing:**
```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Security scanning
checkov -d . --framework terraform

# Linting
tflint --init
tflint
```

**Integration Testing:**
```bash
# Navigate to test environment
cd environments/dev

# Plan changes
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Apply in test environment
terraform apply tfplan

# Test functionality
# Run application-specific tests here

# Clean up test resources
terraform destroy -var-file="terraform.tfvars"
```

#### 4. Code Review Guidelines

**Pre-Review Checklist:**
- [ ] Code formatted with `terraform fmt`
- [ ] All variables have descriptions and appropriate types
- [ ] Outputs are documented with descriptions
- [ ] README.md updated with usage examples
- [ ] Security scan passes (checkov)
- [ ] Integration tests pass

**Review Focus Areas:**
- Resource naming conventions
- Tag consistency
- Security best practices
- Cost optimization
- Documentation completeness

---

## Module Usage Patterns

### Basic Module Usage

```hcl
# environments/dev/main.tf
module "vpc" {
  source = "../../modules/networking/vpc"
  
  environment          = var.environment
  project_name        = var.project_name
  availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]
  
  # Network configuration
  vpc_cidr           = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  database_subnets   = ["10.0.100.0/24", "10.0.200.0/24", "10.0.300.0/24"]
  
  # Enable features
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = local.common_tags
}
```

### Module Composition Strategies

#### 1. Layered Architecture Pattern
```hcl
# Layer 1: Foundation
module "vpc" {
  source = "../../modules/networking/vpc"
  # ... configuration
}

# Layer 2: Security
module "security_groups" {
  source = "../../modules/security/security-groups"
  vpc_id = module.vpc.vpc_id
  # ... configuration
}

# Layer 3: Compute
module "application" {
  source = "../../modules/compute/ecs-service"
  
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.app_sg_id]
  # ... configuration
}
```

#### 2. Environment-Specific Configurations

```hcl
# environments/dev/terraform.tfvars
environment    = "dev"
project_name   = "stackkit"

# Development-specific settings
instance_count = 1
instance_type  = "t3.micro"
min_capacity   = 1
max_capacity   = 2

# environments/prod/terraform.tfvars  
environment    = "prod"
project_name   = "stackkit"

# Production-specific settings
instance_count = 3
instance_type  = "m5.large"
min_capacity   = 3
max_capacity   = 10
```

### Best Practices for Production Use

#### 1. Resource Naming Convention
```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Standard naming patterns
  vpc_name     = "${local.name_prefix}-vpc"
  subnet_name  = "${local.name_prefix}-subnet"
  sg_name      = "${local.name_prefix}-sg"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}
```

#### 2. State Management
```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "stackkit-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "stackkit-terraform-locks"
  }
}
```

---

## Contributing Guidelines

### Creating New Modules

#### 1. Module Standards

**Directory Structure:**
```
modules/category/module-name/
├── main.tf              # Primary resources
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── versions.tf         # Provider requirements
├── README.md           # Usage documentation
├── examples/           # Usage examples
│   └── basic/
│       ├── main.tf
│       └── variables.tf
└── tests/              # Module tests
    └── module_test.go
```

**Variable Conventions:**
```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

#### 2. Documentation Requirements

**README.md Template:**
```markdown
# Module Name

Brief description of what the module creates and its purpose.

## Usage

```hcl
module "example" {
  source = "../../modules/category/module-name"
  
  environment  = "dev"
  project_name = "myproject"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| aws_vpc.main | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
```

#### 3. Testing Requirements

**Module Test Structure:**
```go
// tests/module_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestModuleBasic(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/basic",
        Vars: map[string]interface{}{
            "environment":  "test",
            "project_name": "terratest",
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify outputs
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```

---

## Team Collaboration

### State Management Strategies

#### 1. Environment Separation
```
terraform-states/
├── dev/
│   ├── networking.tfstate
│   ├── compute.tfstate
│   └── storage.tfstate
├── staging/
│   ├── networking.tfstate
│   ├── compute.tfstate
│   └── storage.tfstate
└── prod/
    ├── networking.tfstate
    ├── compute.tfstate
    └── storage.tfstate
```

#### 2. Team Boundaries and Permissions

**AWS IAM Policy for Development Team:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::stackkit-terraform-state-dev",
        "arn:aws:s3:::stackkit-terraform-state-dev/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/stackkit-terraform-locks"
    }
  ]
}
```

#### 3. Resource Naming Conventions

```hcl
locals {
  # Standard naming pattern: {project}-{environment}-{service}-{resource}
  naming_convention = "${var.project_name}-${var.environment}"
  
  # Examples:
  vpc_name      = "${local.naming_convention}-vpc"
  subnet_name   = "${local.naming_convention}-subnet-${var.subnet_type}"
  sg_name       = "${local.naming_convention}-sg-${var.service_name}"
  rds_name      = "${local.naming_convention}-rds-${var.database_name}"
  
  # Common tags applied to all resources
  common_tags = {
    Project       = var.project_name
    Environment   = var.environment
    ManagedBy     = "terraform"
    Team          = var.team_name
    CostCenter    = var.cost_center
    CreatedAt     = timestamp()
  }
}
```

### Troubleshooting Common Issues

#### 1. State Lock Issues
```bash
# Check current locks
aws dynamodb scan --table-name stackkit-terraform-locks --region us-west-2

# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Prevention: Always use workspace or separate state files
terraform workspace list
terraform workspace select dev
```

#### 2. Module Version Conflicts
```hcl
# Pin module versions in production
module "vpc" {
  source = "git::https://github.com/company/stackkit-terraform.git//modules/networking/vpc?ref=v1.2.0"
  
  # Always specify version constraints
}
```

#### 3. Resource Import Issues
```bash
# Import existing resources
terraform import aws_vpc.main vpc-12345678

# Generate configuration from existing resources
terraform show -json | jq '.values.root_module.resources[]'
```

---

## Advanced Topics

### Custom Module Development

#### 1. Dynamic Configuration Patterns
```hcl
# Dynamic subnet creation
resource "aws_subnet" "private" {
  count = length(var.private_subnets)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  
  tags = merge(local.common_tags, {
    Name = "${local.naming_convention}-private-${count.index + 1}"
    Type = "private"
  })
}

# For_each with complex objects
variable "security_groups" {
  description = "Map of security group configurations"
  type = map(object({
    description = string
    ingress = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))
}

resource "aws_security_group" "this" {
  for_each = var.security_groups
  
  name        = "${local.naming_convention}-${each.key}"
  description = each.value.description
  vpc_id      = var.vpc_id
  
  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.naming_convention}-${each.key}"
  })
}
```

#### 2. Data Source Patterns
```hcl
# AMI lookup with filters
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Remote state data sources
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "stackkit-terraform-state-${var.environment}"
    key    = "networking/terraform.tfstate"
    region = var.aws_region
  }
}
```

### Integration with CI/CD

#### 1. GitHub Actions Workflow
```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  TF_VERSION: 1.6.0
  AWS_REGION: us-west-2

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: Terraform Format
      run: terraform fmt -check -recursive
    
    - name: Terraform Validate
      run: |
        find . -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do
          echo "Validating $dir"
          (cd "$dir" && terraform init -backend=false && terraform validate)
        done
    
    - name: Security Scan
      run: |
        pip install checkov
        checkov -d . --framework terraform
    
    - name: TFLint
      run: |
        curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
        tflint --init
        tflint --recursive

  plan:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    strategy:
      matrix:
        environment: [dev, staging]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: Terraform Plan
      run: |
        cd environments/${{ matrix.environment }}
        terraform init
        terraform plan -var-file="terraform.tfvars"

  apply:
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: Terraform Apply
      run: |
        cd environments/prod
        terraform init
        terraform apply -var-file="terraform.tfvars" -auto-approve
```

#### 2. Pre-commit Configuration
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.4
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_tflint
        args:
          - --args=--only=terraform_deprecated_interpolation
          - --args=--only=terraform_deprecated_index
          - --args=--only=terraform_unused_declarations
          - --args=--only=terraform_comment_syntax
          - --args=--only=terraform_documented_outputs
          - --args=--only=terraform_documented_variables
          - --args=--only=terraform_typed_variables
          - --args=--only=terraform_module_pinned_source
          - --args=--only=terraform_naming_convention
          - --args=--only=terraform_required_version
          - --args=--only=terraform_required_providers
          - --args=--only=terraform_standard_module_structure
          - --args=--only=terraform_workspace_remote

  - repo: https://github.com/bridgecrewio/checkov
    rev: 2.4.9
    hooks:
      - id: checkov
        args: [--framework, terraform]
```

### Security Considerations

#### 1. Secrets Management
```hcl
# Use AWS Systems Manager Parameter Store
data "aws_ssm_parameter" "db_password" {
  name            = "/${var.project_name}/${var.environment}/database/password"
  with_decryption = true
}

resource "aws_db_instance" "main" {
  # ... other configuration
  password = data.aws_ssm_parameter.db_password.value
  
  # Never hardcode sensitive values
  # password = "hardcoded_password"  # ❌ Don't do this
}

# Use random providers for generated secrets
resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/${var.environment}/database/password"
  type  = "SecureString"
  value = random_password.db_password.result
  
  tags = local.common_tags
}
```

#### 2. Security Group Best Practices
```hcl
# Principle of least privilege
resource "aws_security_group" "web" {
  name        = "${local.naming_convention}-web"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id
  
  # Only allow necessary traffic
  ingress {
    description = "HTTPS from ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]  # Reference, not CIDR
  }
  
  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Explicit egress rules
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.naming_convention}-web"
  })
}
```

### Performance Optimization

#### 1. State File Optimization
```hcl
# Split large environments into multiple state files
# networking/
terraform {
  backend "s3" {
    bucket = "stackkit-terraform-state-${var.environment}"
    key    = "networking/terraform.tfstate"
    region = var.aws_region
  }
}

# compute/
terraform {
  backend "s3" {
    bucket = "stackkit-terraform-state-${var.environment}"
    key    = "compute/terraform.tfstate" 
    region = var.aws_region
  }
}
```

#### 2. Parallel Execution
```hcl
# Use count and for_each strategically
resource "aws_instance" "web" {
  count = var.instance_count
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
  
  # Parallel execution across AZs
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.naming_convention}-web-${count.index + 1}"
  })
}
```

#### 3. Resource Dependencies
```hcl
# Explicit dependencies when needed
resource "aws_instance" "web" {
  # ... configuration
  
  depends_on = [
    aws_security_group.web,
    aws_iam_role_policy_attachment.web
  ]
}

# Implicit dependencies preferred
resource "aws_instance" "web" {
  # ... configuration
  vpc_security_group_ids = [aws_security_group.web.id]  # Implicit dependency
  iam_instance_profile   = aws_iam_instance_profile.web.name
}
```

---

## Quick Reference

### Common Commands
```bash
# Module development
terraform fmt -recursive              # Format all files
terraform validate                    # Validate syntax
terraform plan                        # Preview changes
terraform apply                       # Apply changes
terraform destroy                     # Destroy resources

# State management
terraform state list                  # List resources in state
terraform state show <resource>       # Show resource details
terraform state mv <old> <new>        # Rename resource
terraform state rm <resource>         # Remove from state
terraform import <resource> <id>      # Import existing resource

# Workspace management
terraform workspace list              # List workspaces
terraform workspace new <name>        # Create workspace
terraform workspace select <name>     # Switch workspace

# Debugging
terraform refresh                     # Sync state with reality
terraform console                     # Interactive console
TF_LOG=DEBUG terraform apply          # Enable debug logging
```

### Emergency Procedures
```bash
# State file corruption
terraform state pull > backup.tfstate
# Fix issues, then:
terraform state push backup.tfstate

# Stuck deployment
terraform force-unlock <lock-id>
# Then investigate and fix root cause

# Resource drift
terraform refresh                     # Update state
terraform plan                        # Check for changes
# Apply or import as needed
```

---

## Support and Resources

### Internal Resources
- **Slack Channels**: #terraform-support, #infrastructure
- **Documentation**: `/docs` directory in this repository
- **Module Registry**: Internal GitLab registry at `registry.company.com`
- **Monitoring**: Terraform Cloud workspace dashboards

### External Resources
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Getting Help
1. Check this documentation first
2. Search existing issues in the repository
3. Ask in #terraform-support Slack channel
4. Create a GitHub issue with:
   - Environment details
   - Terraform version
   - Error messages
   - Steps to reproduce
   - Expected vs actual behavior

---

*Last updated: 2025-01-15*
*Version: 1.0*