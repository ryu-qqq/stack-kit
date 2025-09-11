#!/bin/bash
set -euo pipefail

# 🚀 StackKit Enterprise Team Atlantis Deployment
# Deploy Atlantis instance for a specific team

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
  ___  _   _            _   _     
 / _ \| |_| |__ _ _ _  _| |_(_)___ 
/ /_\ \ __| / _` | ' \| _| (_-< 
|  _  | |_| \__,_|_||_|\__|_/__/ 
\_| |_/\__|_|                   
                               
🚀 Team Atlantis Deployment
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --team-name TEAM --github-token TOKEN [OPTIONS]

🚀 Deploy Atlantis instance for a specific team

Required Arguments:
    --team-name TEAM            Team name (must be already onboarded)
    --github-token TOKEN        GitHub personal access token

Optional Arguments:
    --slack-webhook URL         Slack webhook URL for notifications
    --infracost-key KEY         Infracost API key for cost analysis
    --domain DOMAIN             Custom domain (overrides team subdomain)
    --certificate-arn ARN       SSL certificate ARN for HTTPS
    --route53-zone-id ID        Route53 hosted zone ID for DNS

Advanced Options:
    --atlantis-size SIZE        ECS task size: small|medium|large (default: from team config)
    --terraform-version VER     Terraform version (default: 1.7.5)
    --atlantis-version VER      Atlantis version (default: 0.27.0)
    --log-level LEVEL           Log level: debug|info|warn|error (default: info)

Enterprise Options:
    --enterprise-config PATH    Path to enterprise config file
    --aws-profile PROFILE       AWS CLI profile (default: default)
    --auto-approve              Skip deployment confirmation prompts

Examples:
    # Basic team Atlantis deployment
    $0 --team-name platform --github-token ghp_xxx

    # Full configuration with integrations
    $0 --team-name data-science \\
       --github-token ghp_xxx \\
       --slack-webhook https://hooks.slack.com/services/xxx \\
       --infracost-key ico-xxx \\
       --atlantis-size medium

    # Custom domain with HTTPS
    $0 --team-name platform \\
       --github-token ghp_xxx \\
       --domain platform.atlantis.company.com \\
       --certificate-arn arn:aws:acm:us-east-1:123:certificate/xxx \\
       --route53-zone-id Z123456789

EOF
}

# Default values
TEAM_NAME=""
GITHUB_TOKEN=""
SLACK_WEBHOOK=""
INFRACOST_KEY=""
DOMAIN=""
CERTIFICATE_ARN=""
ROUTE53_ZONE_ID=""
ATLANTIS_SIZE=""
TERRAFORM_VERSION="1.7.5"
ATLANTIS_VERSION="0.27.0"
LOG_LEVEL="info"
ENTERPRISE_CONFIG=""
AWS_PROFILE="default"
AUTO_APPROVE=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --team-name)
            TEAM_NAME="$2"
            shift 2
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --infracost-key)
            INFRACOST_KEY="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --certificate-arn)
            CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --route53-zone-id)
            ROUTE53_ZONE_ID="$2"
            shift 2
            ;;
        --atlantis-size)
            ATLANTIS_SIZE="$2"
            shift 2
            ;;
        --terraform-version)
            TERRAFORM_VERSION="$2"
            shift 2
            ;;
        --atlantis-version)
            ATLANTIS_VERSION="$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
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
        --auto-approve)
            AUTO_APPROVE=true
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

if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GitHub token is required (--github-token)"
fi

# Load enterprise configuration
load_enterprise_config() {
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
        log_error "Enterprise config not found. Run enterprise-bootstrap.sh first."
    fi
    
    log_info "Loading enterprise config: $ENTERPRISE_CONFIG"
    
    # Parse enterprise configuration
    ORGANIZATION=$(grep "organization:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    MASTER_REGION=$(grep "master_region:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    DOMAIN_BASE=$(grep "domain:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    GITHUB_ORG=$(grep "github_org:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    ACCOUNT_ID=$(grep "account_id:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    
    log_success "Loaded enterprise config for $ORGANIZATION"
}

# Load team configuration
load_team_config() {
    log_info "Loading team configuration for: $TEAM_NAME"
    
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    
    if [[ $DRY_RUN == false ]]; then
        local team_config=$(aws dynamodb get-item \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --table-name "$table_name" \
            --key '{"id":{"S":"'$TEAM_NAME'"}}' \
            --query 'Item' \
            --output json 2>/dev/null)
        
        if [[ "$team_config" == "null" || -z "$team_config" ]]; then
            log_error "Team '$TEAM_NAME' not found. Run onboard-team.sh first."
        fi
        
        # Parse team configuration
        TEAM_ID=$(echo "$team_config" | jq -r '.team_id.N // "1"')
        COST_CENTER=$(echo "$team_config" | jq -r '.cost_center.S // "engineering"')
        ENVIRONMENT=$(echo "$team_config" | jq -r '.environment.S // "prod"')
        AWS_REGION=$(echo "$team_config" | jq -r '.aws_region.S // "us-east-1"')
        
        # Use team's configured size if not overridden
        if [[ -z "$ATLANTIS_SIZE" ]]; then
            ATLANTIS_SIZE=$(echo "$team_config" | jq -r '.atlantis_size.S // "small"')
        fi
        
        # Check if team infrastructure is deployed
        local state_bucket="stackkit-team-$TEAM_NAME-$ENVIRONMENT-state"
        if ! aws s3 ls "s3://$state_bucket" --profile "$AWS_PROFILE" &>/dev/null; then
            log_warning "Team infrastructure not found. Deploying team infrastructure first..."
            deploy_team_infrastructure
        fi
    else
        TEAM_ID="1"
        COST_CENTER="engineering"
        ENVIRONMENT="prod"
        AWS_REGION="us-east-1"
        ATLANTIS_SIZE="${ATLANTIS_SIZE:-small}"
    fi
    
    log_success "Loaded team config - ID: $TEAM_ID, Size: $ATLANTIS_SIZE, Region: $AWS_REGION"
}

# Deploy team infrastructure if not exists
deploy_team_infrastructure() {
    log_info "Deploying team infrastructure..."
    
    local team_terraform_dir="/tmp/stackkit-team-$TEAM_NAME"
    
    if [[ ! -d "$team_terraform_dir" ]]; then
        log_error "Team Terraform configuration not found. Run onboard-team.sh first."
    fi
    
    if [[ $DRY_RUN == false ]]; then
        cd "$team_terraform_dir"
        
        # Initialize Terraform
        terraform init
        
        # Plan and apply
        if [[ $AUTO_APPROVE == true ]]; then
            terraform apply -auto-approve
        else
            terraform plan
            read -p "Deploy team infrastructure? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                terraform apply -auto-approve
            else
                log_error "Team infrastructure deployment cancelled"
            fi
        fi
        
        cd - > /dev/null
    fi
    
    log_success "Team infrastructure deployed"
}

# Update team secrets in Secrets Manager
update_team_secrets() {
    log_info "Updating team secrets..."
    
    local secret_name="stackkit-team-$TEAM_NAME-atlantis-secrets"
    
    local secret_json=$(cat << EOF
{
    "github_token": "$GITHUB_TOKEN",
    "github_secret": "$(openssl rand -hex 32)",
    "slack_webhook_url": "$SLACK_WEBHOOK",
    "infracost_api_key": "$INFRACOST_KEY"
}
EOF
)
    
    if [[ $DRY_RUN == false ]]; then
        # Update the secret
        aws secretsmanager update-secret \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --secret-id "$secret_name" \
            --secret-string "$secret_json" &>/dev/null
        
        # Store webhook secret for later use
        GITHUB_WEBHOOK_SECRET=$(echo "$secret_json" | jq -r '.github_secret')
    else
        GITHUB_WEBHOOK_SECRET="dry-run-webhook-secret"
    fi
    
    log_success "Updated team secrets in Secrets Manager"
}

# Create additional security group for Atlantis
create_atlantis_security_group() {
    log_info "Creating Atlantis security group..."
    
    local team_terraform_dir="/tmp/stackkit-team-$TEAM_NAME"
    
    if [[ $DRY_RUN == false ]]; then
        cd "$team_terraform_dir"
        
        # Get VPC ID from Terraform state
        VPC_ID=$(terraform output -json | jq -r '.team_info.value.vpc_id')
        
        cd - > /dev/null
        
        # Create security group for Atlantis ECS tasks
        ATLANTIS_SG_ID=$(aws ec2 create-security-group \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --group-name "stackkit-team-$TEAM_NAME-atlantis-sg" \
            --description "Security group for team $TEAM_NAME Atlantis ECS tasks" \
            --vpc-id "$VPC_ID" \
            --query 'GroupId' \
            --output text)
        
        # Allow inbound from ALB
        aws ec2 authorize-security-group-ingress \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --group-id "$ATLANTIS_SG_ID" \
            --protocol tcp \
            --port 4141 \
            --source-group "$(aws ec2 describe-security-groups \
                --profile "$AWS_PROFILE" \
                --region "$AWS_REGION" \
                --filters "Name=group-name,Values=stackkit-team-$TEAM_NAME-alb" \
                --query 'SecurityGroups[0].GroupId' \
                --output text)"
        
        # Allow all outbound
        aws ec2 authorize-security-group-egress \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --group-id "$ATLANTIS_SG_ID" \
            --protocol -1 \
            --port -1 \
            --cidr 0.0.0.0/0
        
        # Tag the security group
        aws ec2 create-tags \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --resources "$ATLANTIS_SG_ID" \
            --tags Key=Name,Value="stackkit-team-$TEAM_NAME-atlantis-sg" \
                   Key=Team,Value="$TEAM_NAME" \
                   Key=Organization,Value="$ORGANIZATION" \
                   Key=Purpose,Value="atlantis-ecs"
    else
        VPC_ID="vpc-dry-run-12345678"
        ATLANTIS_SG_ID="sg-dry-run-atlantis"
    fi
    
    log_success "Created Atlantis security group: $ATLANTIS_SG_ID"
}

# Deploy Atlantis using Terraform
deploy_atlantis() {
    log_info "Deploying team Atlantis instance..."
    
    local atlantis_dir="/tmp/stackkit-team-$TEAM_NAME-atlantis"
    mkdir -p "$atlantis_dir"
    
    # Generate Atlantis-specific Terraform configuration
    cat > "$atlantis_dir/main.tf" << EOF
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
    key            = "atlantis/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "stackkit-team-$TEAM_NAME-$ENVIRONMENT-locks"
  }
}

provider "aws" {
  region = "$AWS_REGION"
  profile = "$AWS_PROFILE"
  
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
      Purpose      = "atlantis"
    }
  }
}

# Data sources for team infrastructure
data "terraform_remote_state" "team_infra" {
  backend = "s3"
  config = {
    bucket = "stackkit-team-$TEAM_NAME-$ENVIRONMENT-state"
    key    = "team-infrastructure/terraform.tfstate"
    region = "$AWS_REGION"
  }
}

# Team Atlantis module
module "team_atlantis" {
  source = "../../modules/team-atlantis"
  
  # Team configuration
  team_name         = "$TEAM_NAME"
  team_id           = $TEAM_ID
  organization      = "$ORGANIZATION"
  environment       = "$ENVIRONMENT"
  
  # Network configuration from team infrastructure
  vpc_id                      = data.terraform_remote_state.team_infra.outputs.team_info.vpc_id
  public_subnet_ids          = data.terraform_remote_state.team_infra.outputs.public_subnet_ids
  private_subnet_ids         = data.terraform_remote_state.team_infra.outputs.private_subnet_ids
  alb_security_group_id      = data.terraform_remote_state.team_infra.outputs.alb_security_group_id
  atlantis_security_group_id = "$ATLANTIS_SG_ID"
  
  # ECS configuration
  atlantis_size      = "$ATLANTIS_SIZE"
  atlantis_version   = "$ATLANTIS_VERSION"
  terraform_version  = "$TERRAFORM_VERSION"
  log_level         = "$LOG_LEVEL"
  
  # GitHub configuration
  github_org    = "$GITHUB_ORG"
  github_token  = "$GITHUB_TOKEN"
  
  # Domain configuration
  domain_name       = "$DOMAIN_BASE"
  subdomain         = "${DOMAIN:+$DOMAIN}"
  certificate_arn   = "$CERTIFICATE_ARN"
  route53_zone_id   = "$ROUTE53_ZONE_ID"
  
  # Integrations
  slack_webhook_url = "$SLACK_WEBHOOK"
  infracost_api_key = "$INFRACOST_KEY"
}

output "atlantis_info" {
  value = {
    team_name    = "$TEAM_NAME"
    atlantis_url = module.team_atlantis.atlantis_url
    webhook_url  = "\${module.team_atlantis.atlantis_url}/events"
    dns_name     = module.team_atlantis.dns_name
    custom_domain = module.team_atlantis.custom_domain
    endpoints    = module.team_atlantis.endpoints
  }
}

output "secrets" {
  value = {
    webhook_secret = module.team_atlantis.github_webhook_secret
    secret_arn     = module.team_atlantis.secrets_manager_secret_arn
  }
  sensitive = true
}
EOF
    
    if [[ $DRY_RUN == false ]]; then
        cd "$atlantis_dir"
        
        # Initialize Terraform
        terraform init
        
        # Plan deployment
        terraform plan
        
        # Confirm deployment
        if [[ $AUTO_APPROVE == false ]]; then
            read -p "Deploy Atlantis for team $TEAM_NAME? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Atlantis deployment cancelled"
            fi
        fi
        
        # Apply configuration
        terraform apply -auto-approve
        
        # Get outputs
        ATLANTIS_OUTPUT=$(terraform output -json)
        ATLANTIS_URL=$(echo "$ATLANTIS_OUTPUT" | jq -r '.atlantis_info.value.atlantis_url')
        WEBHOOK_URL=$(echo "$ATLANTIS_OUTPUT" | jq -r '.atlantis_info.value.webhook_url')
        
        cd - > /dev/null
    else
        ATLANTIS_URL="https://$TEAM_NAME.$DOMAIN_BASE"
        WEBHOOK_URL="$ATLANTIS_URL/events"
    fi
    
    log_success "Deployed Atlantis at: $ATLANTIS_URL"
}

# Wait for Atlantis to be healthy
wait_for_atlantis() {
    if [[ $DRY_RUN == true ]]; then
        log_info "Dry run: Skipping health check"
        return
    fi
    
    log_info "Waiting for Atlantis to be healthy..."
    
    local health_url="$ATLANTIS_URL/healthz"
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "$health_url" > /dev/null; then
            log_success "Atlantis is healthy!"
            return
        fi
        
        log_info "Attempt $attempt/$max_attempts: Waiting for Atlantis to be ready..."
        sleep 10
        ((attempt++))
    done
    
    log_warning "Atlantis may not be fully ready. Check ECS service status."
}

# Generate deployment summary
generate_summary() {
    log_info "Generating deployment summary..."
    
    local summary_file="/tmp/stackkit-team-$TEAM_NAME-atlantis/DEPLOYMENT_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# Atlantis Deployment Summary: $TEAM_NAME

## Team Information
- **Team Name**: $TEAM_NAME
- **Team ID**: $TEAM_ID
- **Organization**: $ORGANIZATION
- **Environment**: $ENVIRONMENT
- **Cost Center**: $COST_CENTER
- **AWS Region**: $AWS_REGION

## Atlantis Configuration
- **Size**: $ATLANTIS_SIZE
- **Atlantis Version**: $ATLANTIS_VERSION
- **Terraform Version**: $TERRAFORM_VERSION
- **Log Level**: $LOG_LEVEL

## Endpoints
- **Atlantis URL**: $ATLANTIS_URL
- **Webhook URL**: $WEBHOOK_URL
- **Health Check**: $ATLANTIS_URL/healthz

## Next Steps

### 1. Configure GitHub Repositories
For each repository that should use this Atlantis instance:

\`\`\`bash
# Add webhook to repository
curl -X POST \\
  -H "Authorization: token $GITHUB_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "name": "web",
    "active": true,
    "events": [
      "issue_comment",
      "pull_request",
      "pull_request_review",
      "push"
    ],
    "config": {
      "url": "$WEBHOOK_URL",
      "secret": "$GITHUB_WEBHOOK_SECRET",
      "content_type": "json"
    }
  }' \\
  "https://api.github.com/repos/$GITHUB_ORG/YOUR_REPO/hooks"
\`\`\`

### 2. Create atlantis.yaml in Repositories
Add this to your repository root:

\`\`\`yaml
version: 3
projects:
- name: main
  dir: .
  terraform_version: $TERRAFORM_VERSION
  workflow: default
  apply_requirements: ["approved", "mergeable"]
  allowed_overrides: ["apply_requirements", "workflow"]
\`\`\`

### 3. Test the Setup
1. Create a test PR with Terraform changes
2. Comment \`atlantis plan\` on the PR
3. Review the plan output
4. Comment \`atlantis apply\` to apply changes

### 4. Configure Branch Protection
Add these branch protection rules:
- Require pull request reviews
- Require status checks to pass: \`atlantis/plan\`
- Require branches to be up to date

## Monitoring and Troubleshooting

### CloudWatch Logs
- **Log Group**: /ecs/stackkit-team-$TEAM_NAME-atlantis
- **Region**: $AWS_REGION

### ECS Service
- **Cluster**: stackkit-team-$TEAM_NAME-atlantis
- **Service**: stackkit-team-$TEAM_NAME-atlantis

### Common Commands
\`\`\`bash
# Check service status
aws ecs describe-services --cluster stackkit-team-$TEAM_NAME-atlantis --services stackkit-team-$TEAM_NAME-atlantis

# View logs
aws logs tail /ecs/stackkit-team-$TEAM_NAME-atlantis --follow

# Update secrets
aws secretsmanager update-secret --secret-id stackkit-team-$TEAM_NAME-atlantis-secrets --secret-string '{...}'
\`\`\`

## Support
- **Team Dashboard**: https://console.aws.amazon.com/resource-groups/tag-editor?region=$AWS_REGION#/tagFilters/Team=$TEAM_NAME
- **Enterprise Support**: #stackkit-enterprise Slack channel
- **Documentation**: See /docs/ in the enterprise repository

Deployed: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

    log_success "Deployment summary: $summary_file"
}

show_banner
log_info "Starting Atlantis deployment for team: $TEAM_NAME"

# Main execution
load_enterprise_config
load_team_config
update_team_secrets
create_atlantis_security_group
deploy_atlantis
wait_for_atlantis
generate_summary

log_success "🎉 Atlantis deployment completed for team: $TEAM_NAME"
log_info "Atlantis URL: $ATLANTIS_URL"
log_info "Webhook URL: $WEBHOOK_URL"
log_warning "Next step: Configure GitHub repository webhooks"

if [[ $DRY_RUN == true ]]; then
    log_warning "This was a dry run. No resources were actually created."
fi