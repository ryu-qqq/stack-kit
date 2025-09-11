#!/bin/bash
set -euo pipefail

# 🏢 StackKit Enterprise Team Onboarding
# Automated team provisioning with isolation and security controls

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
 _____                      
|_   _|                     
  | | ___  __ _ _ __ ___     
  | |/ _ \/ _` | '_ ` _ \    
  | |  __/ (_| | | | | | |  
  \_/\___|\__,_|_| |_| |_|  
                            
🏢 Enterprise Team Onboarding
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --team-name TEAM [OPTIONS]

🏢 Onboard a new team with isolated infrastructure

Required Arguments:
    --team-name TEAM            Unique team identifier (lowercase, alphanumeric, hyphens)
    --team-leads USERS          Comma-separated list of team lead GitHub usernames

Optional Arguments:
    --github-teams TEAMS        Comma-separated list of GitHub team names
    --cost-center CENTER        Cost center for billing (default: engineering)
    --team-budget AMOUNT        Monthly budget limit in USD
    --environment ENV           Environment suffix (default: prod)
    --aws-region REGION         Team's primary AWS region (default: us-east-1)

Advanced Options:
    --team-id ID                Manual team ID (1-254, auto-assigned if not specified)
    --vpc-cidr CIDR            Custom VPC CIDR (default: 10.{team-id}.0.0/16)
    --enable-cross-team        Allow limited cross-team resource sharing
    --atlantis-size SIZE       ECS task size: small|medium|large (default: small)

Enterprise Integration:
    --enterprise-config PATH    Path to enterprise config file
    --aws-profile PROFILE       AWS CLI profile (default: default)
    --approval-required        Require enterprise admin approval

Examples:
    # Basic team onboarding
    $0 --team-name platform --team-leads "alice,bob"

    # Full configuration
    $0 --team-name data-science \\
       --team-leads "alice,bob" \\
       --github-teams "data-team,ml-engineers" \\
       --cost-center "data-analytics" \\
       --team-budget 5000 \\
       --atlantis-size medium

EOF
}

# Default values
TEAM_NAME=""
TEAM_LEADS=""
GITHUB_TEAMS=""
COST_CENTER="engineering"
TEAM_BUDGET=""
ENVIRONMENT="prod"
AWS_REGION="us-east-1"
TEAM_ID=""
VPC_CIDR=""
ENABLE_CROSS_TEAM=false
ATLANTIS_SIZE="small"
ENTERPRISE_CONFIG=""
AWS_PROFILE="default"
APPROVAL_REQUIRED=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --team-name)
            TEAM_NAME="$2"
            shift 2
            ;;
        --team-leads)
            TEAM_LEADS="$2"
            shift 2
            ;;
        --github-teams)
            GITHUB_TEAMS="$2"
            shift 2
            ;;
        --cost-center)
            COST_CENTER="$2"
            shift 2
            ;;
        --team-budget)
            TEAM_BUDGET="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --aws-region)
            AWS_REGION="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --vpc-cidr)
            VPC_CIDR="$2"
            shift 2
            ;;
        --enable-cross-team)
            ENABLE_CROSS_TEAM=true
            shift
            ;;
        --atlantis-size)
            ATLANTIS_SIZE="$2"
            shift 2
            ;;
        --enterprise-config)
            ENTERPRISE_CONFIG="$2"
            shift 2
            ;;
        --aws-profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --approval-required)
            APPROVAL_REQUIRED=true
            shift
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
if [[ -z "$TEAM_NAME" ]]; then
    log_error "Team name is required (--team-name)"
fi

if [[ -z "$TEAM_LEADS" ]]; then
    log_error "Team leads are required (--team-leads)"
fi

# Validate team name format
if [[ ! "$TEAM_NAME" =~ ^[a-z0-9-]+$ ]]; then
    log_error "Team name must be lowercase alphanumeric with hyphens only"
fi

# Load enterprise configuration
load_enterprise_config() {
    # Try to find enterprise config automatically
    local config_paths=(
        "$ENTERPRISE_CONFIG"
        "../enterprise-config.yaml"
        "/tmp/stackkit-enterprise-*/enterprise-config.yaml"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [[ -n "$config_path" && -f "$config_path" ]]; then
            ENTERPRISE_CONFIG="$config_path"
            break
        fi
    done
    
    if [[ -z "$ENTERPRISE_CONFIG" || ! -f "$ENTERPRISE_CONFIG" ]]; then
        log_error "Enterprise config not found. Run enterprise-bootstrap.sh first or specify --enterprise-config"
    fi
    
    log_info "Loading enterprise config: $ENTERPRISE_CONFIG"
    
    # Parse YAML (simple grep-based parsing for this example)
    ORGANIZATION=$(grep "organization:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    MASTER_REGION=$(grep "master_region:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    DOMAIN=$(grep "domain:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    GITHUB_ORG=$(grep "github_org:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    ACCOUNT_ID=$(grep "account_id:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    
    log_success "Loaded enterprise config for $ORGANIZATION"
}

# Auto-assign team ID if not specified
assign_team_id() {
    if [[ -n "$TEAM_ID" ]]; then
        log_info "Using specified team ID: $TEAM_ID"
        return
    fi
    
    log_info "Auto-assigning team ID..."
    
    # Query DynamoDB for existing team IDs
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    
    if [[ $DRY_RUN == false ]]; then
        local existing_ids=$(aws dynamodb scan \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --table-name "$table_name" \
            --projection-expression "team_id" \
            --query 'Items[].team_id.N' \
            --output text 2>/dev/null || echo "")
    else
        existing_ids=""
    fi
    
    # Find next available ID (starting from 1)
    for ((id=1; id<=254; id++)); do
        if [[ ! "$existing_ids" =~ $id ]]; then
            TEAM_ID="$id"
            break
        fi
    done
    
    if [[ -z "$TEAM_ID" ]]; then
        log_error "No available team IDs (maximum 254 teams reached)"
    fi
    
    log_success "Assigned team ID: $TEAM_ID"
}

# Generate team VPC CIDR
generate_vpc_cidr() {
    if [[ -n "$VPC_CIDR" ]]; then
        log_info "Using specified VPC CIDR: $VPC_CIDR"
        return
    fi
    
    VPC_CIDR="10.$TEAM_ID.0.0/16"
    log_info "Generated VPC CIDR: $VPC_CIDR"
}

# Create team IAM role
create_team_iam_role() {
    log_info "Creating team IAM role..."
    
    local role_name="StackKitTeam-$TEAM_NAME"
    
    # Trust policy for the team role
    local trust_policy=$(cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "aws:PrincipalTag/Team": "$TEAM_NAME",
                    "aws:PrincipalTag/Organization": "$ORGANIZATION"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "ecs-tasks.amazonaws.com",
                    "ec2.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    
    # Team permissions policy
    local permissions_policy=$(cat << EOF
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
                "logs:*",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/Team": "$TEAM_NAME"
                }
            }
        }
    ]
}
EOF
)
    
    if [[ $DRY_RUN == false ]]; then
        # Create IAM role
        aws iam create-role \
            --profile "$AWS_PROFILE" \
            --role-name "$role_name" \
            --assume-role-policy-document "$trust_policy" \
            --permissions-boundary "$(grep "boundary_policy:" "$ENTERPRISE_CONFIG" | awk '{print $2}')" \
            --tags Key=Team,Value="$TEAM_NAME" Key=Organization,Value="$ORGANIZATION" Key=CostCenter,Value="$COST_CENTER"
        
        # Create and attach permissions policy
        local policy_arn=$(aws iam create-policy \
            --profile "$AWS_PROFILE" \
            --policy-name "StackKitTeam-$TEAM_NAME-Permissions" \
            --policy-document "$permissions_policy" \
            --description "Permissions policy for team $TEAM_NAME" \
            --query 'Policy.Arn' \
            --output text)
        
        aws iam attach-role-policy \
            --profile "$AWS_PROFILE" \
            --role-name "$role_name" \
            --policy-arn "$policy_arn"
    fi
    
    log_success "Created team IAM role: $role_name"
}

# Create team S3 bucket for Terraform state
create_team_state_bucket() {
    log_info "Creating team state management resources..."
    
    local state_bucket="stackkit-team-$TEAM_NAME-$ENVIRONMENT-state"
    local lock_table="stackkit-team-$TEAM_NAME-$ENVIRONMENT-locks"
    
    if [[ $DRY_RUN == false ]]; then
        # Create S3 bucket for state
        if [[ "$AWS_REGION" == "us-east-1" ]]; then
            aws s3 mb "s3://$state_bucket" --profile "$AWS_PROFILE"
        else
            aws s3 mb "s3://$state_bucket" --region "$AWS_REGION" --profile "$AWS_PROFILE"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$state_bucket" \
            --versioning-configuration Status=Enabled \
            --profile "$AWS_PROFILE"
        
        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$state_bucket" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "aws:kms"
                    }
                }]
            }' \
            --profile "$AWS_PROFILE"
        
        # Add bucket policy for team access only
        aws s3api put-bucket-policy \
            --bucket "$state_bucket" \
            --policy '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": "arn:aws:iam::'$ACCOUNT_ID':role/StackKitTeam-'$TEAM_NAME'"
                    },
                    "Action": "s3:*",
                    "Resource": [
                        "arn:aws:s3:::'$state_bucket'",
                        "arn:aws:s3:::'$state_bucket'/*"
                    ]
                }]
            }' \
            --profile "$AWS_PROFILE"
        
        # Create DynamoDB table for state locking
        aws dynamodb create-table \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --table-name "$lock_table" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --sse-specification Enabled=true,SSEType=KMS \
            --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
            --tags Key=Team,Value="$TEAM_NAME" Key=Organization,Value="$ORGANIZATION" Key=Purpose,Value=terraform-locking
    fi
    
    log_success "Created team state resources: $state_bucket, $lock_table"
}

# Register team in enterprise system
register_team() {
    log_info "Registering team in enterprise system..."
    
    local team_record=$(cat << EOF
{
    "id": {"S": "$TEAM_NAME"},
    "team_id": {"N": "$TEAM_ID"},
    "organization": {"S": "$ORGANIZATION"},
    "created": {"S": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"},
    "team_leads": {"SS": [$(printf '"%s",' $(echo "$TEAM_LEADS" | tr ',' ' ') | sed 's/,$//')]},
    "github_teams": {"SS": [$(printf '"%s",' $(echo "$GITHUB_TEAMS" | tr ',' ' ') | sed 's/,$//')]},
    "cost_center": {"S": "$COST_CENTER"},
    "team_budget": {"N": "${TEAM_BUDGET:-0}"},
    "environment": {"S": "$ENVIRONMENT"},
    "aws_region": {"S": "$AWS_REGION"},
    "vpc_cidr": {"S": "$VPC_CIDR"},
    "atlantis_size": {"S": "$ATLANTIS_SIZE"},
    "enable_cross_team": {"BOOL": $ENABLE_CROSS_TEAM},
    "status": {"S": "provisioned"}
}
EOF
)
    
    if [[ $DRY_RUN == false ]]; then
        aws dynamodb put-item \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --table-name "stackkit-enterprise-$ORGANIZATION-teams" \
            --item "$team_record"
    fi
    
    log_success "Registered team: $TEAM_NAME"
}

# Generate team Terraform configuration
generate_team_terraform() {
    log_info "Generating team Terraform configuration..."
    
    local team_dir="/tmp/stackkit-team-$TEAM_NAME"
    mkdir -p "$team_dir"
    
    cat > "$team_dir/main.tf" << EOF
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "stackkit-team-$TEAM_NAME-$ENVIRONMENT-state"
    key            = "team-infrastructure/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "stackkit-team-$TEAM_NAME-$ENVIRONMENT-locks"
  }
}

provider "aws" {
  region = "$AWS_REGION"
  
  assume_role {
    role_arn = "arn:aws:iam::$ACCOUNT_ID:role/StackKitTeam-$TEAM_NAME"
  }
  
  default_tags {
    tags = {
      Team         = "$TEAM_NAME"
      Organization = "$ORGANIZATION"
      CostCenter   = "$COST_CENTER"
      ManagedBy    = "StackKit-Enterprise"
      Environment  = "$ENVIRONMENT"
    }
  }
}

# Team configuration
locals {
  team_name       = "$TEAM_NAME"
  team_id         = $TEAM_ID
  organization    = "$ORGANIZATION"
  cost_center     = "$COST_CENTER"
  environment     = "$ENVIRONMENT"
  aws_region      = "$AWS_REGION"
  vpc_cidr        = "$VPC_CIDR"
  atlantis_size   = "$ATLANTIS_SIZE"
  
  # Atlantis ECS configuration
  atlantis_config = {
    small  = { cpu = 256, memory = 512 }
    medium = { cpu = 512, memory = 1024 }
    large  = { cpu = 1024, memory = 2048 }
  }
  
  atlantis_resources = local.atlantis_config[local.atlantis_size]
}

# Import team VPC module from enterprise templates
module "team_vpc" {
  source = "../../modules/team-vpc"
  
  team_name    = local.team_name
  team_id      = local.team_id
  vpc_cidr     = local.vpc_cidr
  environment  = local.environment
  
  enable_cross_team_access = $ENABLE_CROSS_TEAM
}

# Team Atlantis deployment module
module "team_atlantis" {
  source = "../../modules/team-atlantis"
  
  team_name           = local.team_name
  team_id             = local.team_id
  organization        = local.organization
  environment         = local.environment
  
  # Network configuration
  vpc_id              = module.team_vpc.vpc_id
  private_subnet_ids  = module.team_vpc.private_subnet_ids
  public_subnet_ids   = module.team_vpc.public_subnet_ids
  
  # ECS configuration
  cpu                 = local.atlantis_resources.cpu
  memory              = local.atlantis_resources.memory
  
  # Domain configuration (will be set during Atlantis deployment)
  domain_name         = "$DOMAIN"
  subdomain           = local.team_name
  
  depends_on = [module.team_vpc]
}

# Outputs
output "team_info" {
  value = {
    team_name          = local.team_name
    team_id            = local.team_id
    vpc_id             = module.team_vpc.vpc_id
    vpc_cidr           = local.vpc_cidr
    atlantis_url       = module.team_atlantis.atlantis_url
    atlantis_dns       = module.team_atlantis.dns_name
  }
}
EOF

    # Create team-specific variables file
    cat > "$team_dir/terraform.tfvars" << EOF
# Team Configuration
team_name = "$TEAM_NAME"
team_id = $TEAM_ID
cost_center = "$COST_CENTER"
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"

# Network Configuration  
vpc_cidr = "$VPC_CIDR"

# Atlantis Configuration
atlantis_size = "$ATLANTIS_SIZE"
enable_cross_team = $ENABLE_CROSS_TEAM

# Team Members (for reference)
team_leads = "$TEAM_LEADS"
github_teams = "$GITHUB_TEAMS"

# Budget Configuration
team_budget = ${TEAM_BUDGET:-0}
EOF
    
    log_success "Generated team Terraform configuration: $team_dir"
}

# Generate team onboarding summary
generate_team_summary() {
    log_info "Generating team onboarding summary..."
    
    local summary_file="/tmp/stackkit-team-$TEAM_NAME/TEAM_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# Team Onboarding Summary: $TEAM_NAME

## Team Configuration
- **Team Name**: $TEAM_NAME
- **Team ID**: $TEAM_ID
- **Organization**: $ORGANIZATION
- **Environment**: $ENVIRONMENT
- **Cost Center**: $COST_CENTER
- **AWS Region**: $AWS_REGION

## Team Members
- **Team Leads**: $TEAM_LEADS
- **GitHub Teams**: $GITHUB_TEAMS

## Infrastructure Allocation
- **VPC CIDR**: $VPC_CIDR
- **Atlantis Size**: $ATLANTIS_SIZE
- **Budget**: \$${TEAM_BUDGET:-"Not Set"}
- **Cross-Team Access**: $ENABLE_CROSS_TEAM

## AWS Resources Created
- **IAM Role**: StackKitTeam-$TEAM_NAME
- **S3 State Bucket**: stackkit-team-$TEAM_NAME-$ENVIRONMENT-state
- **DynamoDB Lock Table**: stackkit-team-$TEAM_NAME-$ENVIRONMENT-locks

## Next Steps

### 1. Deploy Team Infrastructure
\`\`\`bash
cd /tmp/stackkit-team-$TEAM_NAME
terraform init
terraform plan
terraform apply
\`\`\`

### 2. Deploy Team Atlantis Instance
\`\`\`bash
../scripts/deploy-team-atlantis.sh \\
  --team-name $TEAM_NAME \\
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx \\
  --slack-webhook https://hooks.slack.com/services/xxx/xxx/xxx
\`\`\`

### 3. Connect Team Repositories
\`\`\`bash
../scripts/connect-team-repos.sh \\
  --team-name $TEAM_NAME \\
  --repos "org/repo1,org/repo2" \\
  --github-token ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
\`\`\`

### 4. Configure Team Access
- Add team members to GitHub teams: $GITHUB_TEAMS
- Configure AWS SSO access (if enabled)
- Set up team-specific Slack notifications

## URLs and Endpoints
- **Atlantis URL**: https://$TEAM_NAME.$DOMAIN (after deployment)
- **State Bucket**: s3://stackkit-team-$TEAM_NAME-$ENVIRONMENT-state
- **Team Dashboard**: https://console.aws.amazon.com/resource-groups/tag-editor

## Security Notes
- Team IAM role has permissions boundary: $(grep "boundary_policy:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
- All resources are tagged with Team=$TEAM_NAME for cost allocation
- State files are encrypted with enterprise KMS key
- Network isolation via dedicated VPC

## Support
- Enterprise Admin: Contact via #stackkit-enterprise Slack channel
- Documentation: See enterprise documentation in /docs/
- Troubleshooting: Run ../scripts/diagnose-team.sh --team-name $TEAM_NAME

Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

    log_success "Generated team summary: $summary_file"
}

show_banner
log_info "Starting team onboarding for: $TEAM_NAME"

# Main execution
load_enterprise_config
assign_team_id
generate_vpc_cidr
create_team_iam_role
create_team_state_bucket
register_team
generate_team_terraform
generate_team_summary

log_success "Team onboarding completed for: $TEAM_NAME"
log_info "Team ID: $TEAM_ID"
log_info "VPC CIDR: $VPC_CIDR" 
log_info "Configuration saved to: /tmp/stackkit-team-$TEAM_NAME/"
log_warning "Next step: Deploy team infrastructure and Atlantis instance"

if [[ $DRY_RUN == true ]]; then
    log_warning "This was a dry run. No resources were actually created."
fi