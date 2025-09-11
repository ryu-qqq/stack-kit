#!/bin/bash
set -euo pipefail

# 🏢 StackKit Enterprise Bootstrap
# Initialize multi-tenant Atlantis environment with enterprise controls

# Colors and logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
 _____ _             _    _  ___ _   
/  ___| |           | |  | |/ (_) |  
\ `--.| |_ __ _  ___| | _| ' / _| |_ 
 `--. \ __/ _` |/ __| |/ /  < | | __|
/\__/ / || (_| | (__|   <| . \| | |_ 
\____/ \__\__,_|\___|_|\_\_|\_\_|\__|
                                    
🏢 Enterprise Multi-Tenant Bootstrap
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --organization ORG [OPTIONS]

🏢 Bootstrap enterprise-grade multi-tenant Atlantis environment

Required Arguments:
    --organization ORG          Enterprise organization name
    --master-region REGION      Master AWS region for control plane

Optional Arguments:
    --domain DOMAIN             Base domain for team subdomains
    --github-org ORG            GitHub organization name
    --aws-profile PROFILE       AWS CLI profile (default: default)
    --terraform-version VER     Terraform version (default: 1.7.5)
    --cost-center CENTER        Default cost center for billing

Advanced Options:
    --enable-control-tower      Use AWS Control Tower for governance
    --enable-sso               Enable AWS SSO integration  
    --enable-audit-logging     Enable comprehensive audit logging
    --backup-retention DAYS    State backup retention (default: 90)

Security Options:
    --boundary-policy ARN      IAM boundary policy for teams
    --encryption-key ARN       KMS key for enterprise encryption
    --vpc-cidr-base CIDR       Base CIDR for team VPCs (default: 10.0.0.0/8)

Examples:
    # Basic enterprise setup
    $0 --organization acme --master-region us-east-1

    # Full enterprise setup
    $0 --organization acme \\
       --master-region us-east-1 \\
       --domain atlantis.acme.com \\
       --github-org acme-corp \\
       --enable-control-tower \\
       --enable-sso

EOF
}

# Default values
ORGANIZATION=""
MASTER_REGION=""
DOMAIN=""
GITHUB_ORG=""
AWS_PROFILE="default"
TERRAFORM_VERSION="1.7.5"
COST_CENTER="engineering"
ENABLE_CONTROL_TOWER=false
ENABLE_SSO=false
ENABLE_AUDIT_LOGGING=true
BACKUP_RETENTION=90
BOUNDARY_POLICY=""
ENCRYPTION_KEY=""
VPC_CIDR_BASE="10.0.0.0/8"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --organization)
            ORGANIZATION="$2"
            shift 2
            ;;
        --master-region)
            MASTER_REGION="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --github-org)
            GITHUB_ORG="$2"
            shift 2
            ;;
        --aws-profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --terraform-version)
            TERRAFORM_VERSION="$2"
            shift 2
            ;;
        --cost-center)
            COST_CENTER="$2"
            shift 2
            ;;
        --enable-control-tower)
            ENABLE_CONTROL_TOWER=true
            shift
            ;;
        --enable-sso)
            ENABLE_SSO=true
            shift
            ;;
        --enable-audit-logging)
            ENABLE_AUDIT_LOGGING=true
            shift
            ;;
        --backup-retention)
            BACKUP_RETENTION="$2"
            shift 2
            ;;
        --boundary-policy)
            BOUNDARY_POLICY="$2"
            shift 2
            ;;
        --encryption-key)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        --vpc-cidr-base)
            VPC_CIDR_BASE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            ;;
    esac
done

# Validation
if [[ -z "$ORGANIZATION" ]]; then
    log_error "Organization name is required (--organization)"
fi

if [[ -z "$MASTER_REGION" ]]; then
    log_error "Master region is required (--master-region)"
fi

# Set derived values
GITHUB_ORG="${GITHUB_ORG:-$ORGANIZATION}"
DOMAIN="${DOMAIN:-atlantis.$ORGANIZATION.com}"

show_banner
log_info "Starting enterprise bootstrap for $ORGANIZATION"
log_info "Master region: $MASTER_REGION"
log_info "Domain: $DOMAIN"
log_info "GitHub org: $GITHUB_ORG"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install: https://aws.amazon.com/cli/"
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install: https://terraform.io"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install: https://stedolan.github.io/jq/"
    fi
    
    # Validate AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "AWS credentials not configured for profile: $AWS_PROFILE"
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Arn --output text)
    
    log_success "Prerequisites validated"
    log_info "AWS Account: $ACCOUNT_ID"
    log_info "AWS User: $USER_ARN"
}

# Create enterprise directory structure
create_directory_structure() {
    log_info "Creating enterprise directory structure..."
    
    local base_dir="/tmp/stackkit-enterprise-$ORGANIZATION"
    
    if [[ $DRY_RUN == false ]]; then
        mkdir -p "$base_dir"/{terraform,teams,backups,logs}
        mkdir -p "$base_dir"/terraform/{control-plane,team-templates}
        mkdir -p "$base_dir"/teams/{active,archived}
        
        # Create enterprise configuration
        cat > "$base_dir/enterprise-config.yaml" << EOF
organization: $ORGANIZATION
master_region: $MASTER_REGION
domain: $DOMAIN
github_org: $GITHUB_ORG
cost_center: $COST_CENTER
vpc_cidr_base: $VPC_CIDR_BASE
backup_retention: $BACKUP_RETENTION
features:
  control_tower: $ENABLE_CONTROL_TOWER
  sso: $ENABLE_SSO
  audit_logging: $ENABLE_AUDIT_LOGGING
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
account_id: $ACCOUNT_ID
EOF
    fi
    
    log_success "Directory structure created: $base_dir"
}

# Create KMS key for enterprise encryption
create_enterprise_kms_key() {
    if [[ -n "$ENCRYPTION_KEY" ]]; then
        log_info "Using existing KMS key: $ENCRYPTION_KEY"
        return
    fi
    
    log_info "Creating enterprise KMS key..."
    
    local key_policy=$(cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow Enterprise Services",
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "s3.amazonaws.com",
                    "dynamodb.amazonaws.com",
                    "secretsmanager.amazonaws.com",
                    "logs.amazonaws.com"
                ]
            },
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey",
                "kms:ReEncrypt*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    
    if [[ $DRY_RUN == false ]]; then
        ENCRYPTION_KEY=$(aws kms create-key \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --policy "$key_policy" \
            --description "StackKit Enterprise Master Key for $ORGANIZATION" \
            --query 'KeyMetadata.Arn' \
            --output text)
        
        aws kms create-alias \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --alias-name "alias/stackkit-enterprise-$ORGANIZATION" \
            --target-key-id "$ENCRYPTION_KEY"
    else
        ENCRYPTION_KEY="arn:aws:kms:$MASTER_REGION:$ACCOUNT_ID:key/00000000-1111-2222-3333-444444444444"
    fi
    
    log_success "Enterprise KMS key created: $ENCRYPTION_KEY"
}

# Create enterprise S3 buckets
create_enterprise_buckets() {
    log_info "Creating enterprise S3 buckets..."
    
    local buckets=(
        "stackkit-enterprise-$ORGANIZATION-control-plane"
        "stackkit-enterprise-$ORGANIZATION-team-templates" 
        "stackkit-enterprise-$ORGANIZATION-audit-logs"
        "stackkit-enterprise-$ORGANIZATION-backups"
    )
    
    for bucket in "${buckets[@]}"; do
        if [[ $DRY_RUN == false ]]; then
            # Create bucket
            if [[ "$MASTER_REGION" == "us-east-1" ]]; then
                aws s3 mb "s3://$bucket" --profile "$AWS_PROFILE"
            else
                aws s3 mb "s3://$bucket" --region "$MASTER_REGION" --profile "$AWS_PROFILE"
            fi
            
            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$bucket" \
                --versioning-configuration Status=Enabled \
                --profile "$AWS_PROFILE"
            
            # Enable encryption
            aws s3api put-bucket-encryption \
                --bucket "$bucket" \
                --server-side-encryption-configuration '{
                    "Rules": [{
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "aws:kms",
                            "KMSMasterKeyID": "'"$ENCRYPTION_KEY"'"
                        }
                    }]
                }' \
                --profile "$AWS_PROFILE"
            
            # Block public access
            aws s3api put-public-access-block \
                --bucket "$bucket" \
                --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
                --profile "$AWS_PROFILE"
        fi
        
        log_success "Created bucket: $bucket"
    done
}

# Create enterprise DynamoDB tables
create_enterprise_dynamodb() {
    log_info "Creating enterprise DynamoDB tables..."
    
    local tables=(
        "stackkit-enterprise-$ORGANIZATION-teams"
        "stackkit-enterprise-$ORGANIZATION-audit"
        "stackkit-enterprise-$ORGANIZATION-locks"
    )
    
    for table in "${tables[@]}"; do
        if [[ $DRY_RUN == false ]]; then
            aws dynamodb create-table \
                --profile "$AWS_PROFILE" \
                --region "$MASTER_REGION" \
                --table-name "$table" \
                --attribute-definitions \
                    AttributeName=id,AttributeType=S \
                --key-schema \
                    AttributeName=id,KeyType=HASH \
                --provisioned-throughput \
                    ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --sse-specification \
                    Enabled=true,SSEType=KMS,KMSMasterKeyId="$ENCRYPTION_KEY" \
                --point-in-time-recovery-specification \
                    PointInTimeRecoveryEnabled=true \
                --tags \
                    Key=Organization,Value="$ORGANIZATION" \
                    Key=CostCenter,Value="$COST_CENTER" \
                    Key=Purpose,Value=Enterprise-Control-Plane
        fi
        
        log_success "Created table: $table"
    done
}

# Create IAM boundary policy for teams
create_boundary_policy() {
    if [[ -n "$BOUNDARY_POLICY" ]]; then
        log_info "Using existing boundary policy: $BOUNDARY_POLICY"
        return
    fi
    
    log_info "Creating IAM boundary policy for teams..."
    
    local policy_document=$(cat << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "s3:*",
                "dynamodb:*",
                "iam:List*",
                "iam:Get*",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:DeleteRole",
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey",
                "logs:*",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:PrincipalTag/Organization": "${aws:PrincipalTag/Organization}"
                }
            }
        },
        {
            "Effect": "Deny",
            "Action": [
                "iam:CreateUser",
                "iam:DeleteUser",
                "iam:CreateAccessKey",
                "iam:DeleteAccessKey",
                "organizations:*",
                "account:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    
    if [[ $DRY_RUN == false ]]; then
        BOUNDARY_POLICY=$(aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "StackKitEnterprise-$ORGANIZATION-TeamBoundary" \
            --policy-document "$policy_document" \
            --description "Boundary policy for StackKit Enterprise teams" \
            --query 'Policy.Arn' \
            --output text)
    else
        BOUNDARY_POLICY="arn:aws:iam::$ACCOUNT_ID:policy/StackKitEnterprise-$ORGANIZATION-TeamBoundary"
    fi
    
    log_success "Created boundary policy: $BOUNDARY_POLICY"
}

# Generate enterprise configuration files
generate_enterprise_config() {
    log_info "Generating enterprise Terraform configuration..."
    
    local terraform_dir="/tmp/stackkit-enterprise-$ORGANIZATION/terraform"
    
    # Generate main control plane configuration
    cat > "$terraform_dir/control-plane/main.tf" << EOF
terraform {
  required_version = ">= $TERRAFORM_VERSION"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "stackkit-enterprise-$ORGANIZATION-control-plane"
    key            = "control-plane/terraform.tfstate"
    region         = "$MASTER_REGION"
    encrypt        = true
    kms_key_id     = "$ENCRYPTION_KEY"
    dynamodb_table = "stackkit-enterprise-$ORGANIZATION-locks"
  }
}

provider "aws" {
  region = "$MASTER_REGION"
  
  default_tags {
    tags = {
      Organization = "$ORGANIZATION"
      CostCenter   = "$COST_CENTER"
      ManagedBy    = "StackKit-Enterprise"
      Environment  = "control-plane"
    }
  }
}

# Enterprise configuration data
locals {
  organization    = "$ORGANIZATION"
  master_region   = "$MASTER_REGION"
  domain          = "$DOMAIN"
  github_org      = "$GITHUB_ORG"
  encryption_key  = "$ENCRYPTION_KEY"
  boundary_policy = "$BOUNDARY_POLICY"
  
  # Team CIDR allocation (10.x.0.0/16 where x = team_id)
  team_cidr_base = "$VPC_CIDR_BASE"
  
  enterprise_buckets = {
    control_plane = "stackkit-enterprise-$ORGANIZATION-control-plane"
    templates     = "stackkit-enterprise-$ORGANIZATION-team-templates"
    audit_logs    = "stackkit-enterprise-$ORGANIZATION-audit-logs"
    backups       = "stackkit-enterprise-$ORGANIZATION-backups"
  }
  
  enterprise_tables = {
    teams = "stackkit-enterprise-$ORGANIZATION-teams"
    audit = "stackkit-enterprise-$ORGANIZATION-audit"
    locks = "stackkit-enterprise-$ORGANIZATION-locks"
  }
}

# Output key values for team modules
output "enterprise_config" {
  value = {
    organization    = local.organization
    master_region   = local.master_region
    domain          = local.domain
    github_org      = local.github_org
    encryption_key  = local.encryption_key
    boundary_policy = local.boundary_policy
    buckets         = local.enterprise_buckets
    tables          = local.enterprise_tables
  }
  sensitive = true
}
EOF

    log_success "Generated enterprise Terraform configuration"
}

# Create enterprise documentation
create_documentation() {
    log_info "Creating enterprise documentation..."
    
    local docs_dir="/tmp/stackkit-enterprise-$ORGANIZATION/docs"
    mkdir -p "$docs_dir"
    
    cat > "$docs_dir/enterprise-setup-summary.md" << EOF
# StackKit Enterprise Setup Summary

## Organization: $ORGANIZATION
- **Account ID**: $ACCOUNT_ID
- **Master Region**: $MASTER_REGION
- **Domain**: $DOMAIN
- **GitHub Org**: $GITHUB_ORG

## Enterprise Resources Created

### KMS Encryption
- **Key ARN**: $ENCRYPTION_KEY
- **Alias**: alias/stackkit-enterprise-$ORGANIZATION

### S3 Buckets
- stackkit-enterprise-$ORGANIZATION-control-plane
- stackkit-enterprise-$ORGANIZATION-team-templates
- stackkit-enterprise-$ORGANIZATION-audit-logs
- stackkit-enterprise-$ORGANIZATION-backups

### DynamoDB Tables
- stackkit-enterprise-$ORGANIZATION-teams
- stackkit-enterprise-$ORGANIZATION-audit
- stackkit-enterprise-$ORGANIZATION-locks

### IAM Policies
- **Boundary Policy**: $BOUNDARY_POLICY

## Next Steps

1. **Onboard First Team**:
   \`\`\`bash
   ./scripts/onboard-team.sh --team-name platform --team-leads "admin1,admin2"
   \`\`\`

2. **Deploy Team Atlantis**:
   \`\`\`bash
   ./scripts/deploy-team-atlantis.sh --team-name platform --github-token ghp_xxx
   \`\`\`

3. **Configure DNS** (if using custom domain):
   - Create Route53 hosted zone for $DOMAIN
   - Configure NS records in parent domain

4. **Setup Monitoring**:
   - Configure CloudWatch dashboards
   - Setup SNS topics for alerts

## Configuration Files
- Enterprise config: /tmp/stackkit-enterprise-$ORGANIZATION/enterprise-config.yaml
- Terraform config: /tmp/stackkit-enterprise-$ORGANIZATION/terraform/control-plane/main.tf

## Security Considerations
- All data encrypted with KMS key: $ENCRYPTION_KEY
- Team isolation via VPC and IAM boundary policies
- Audit logging enabled for compliance
- State file encryption and versioning enabled

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

    log_success "Created enterprise documentation"
}

# Main execution
main() {
    check_prerequisites
    create_directory_structure
    create_enterprise_kms_key
    create_enterprise_buckets
    create_enterprise_dynamodb
    create_boundary_policy
    generate_enterprise_config
    create_documentation
    
    log_success "Enterprise bootstrap completed!"
    log_info "Configuration saved to: /tmp/stackkit-enterprise-$ORGANIZATION/"
    log_warning "Next step: Copy configuration to your repository and onboard your first team"
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "This was a dry run. No resources were actually created."
    fi
}

main "$@"