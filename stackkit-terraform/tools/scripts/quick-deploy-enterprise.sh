#!/bin/bash
set -euo pipefail

# 🏢 StackKit Enterprise Quick Deploy
# One-click enterprise multi-tenant Atlantis deployment

# Colors and logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_enterprise() { echo -e "${PURPLE}🏢 $1${NC}"; }

show_banner() {
    echo -e "${PURPLE}"
    cat << "EOF"
 _____ _             _    _  ___ _   
/  ___| |           | |  | |/ (_) |  
\ `--.| |_ __ _  ___| | _| ' / _| |_ 
 `--. \ __/ _` |/ __| |/ /  < | | __|
/\__/ / || (_| | (__|   <| . \| | |_ 
\____/ \__\__,_|\___|_|\_\_|\_\_|\__|
                                    
🏢 Enterprise Quick Deploy
One command, full multi-tenant Atlantis
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 --organization ORG --github-token TOKEN [OPTIONS]

🏢 Deploy enterprise multi-tenant Atlantis in one command

Required Arguments:
    --organization ORG          Enterprise organization name
    --github-token TOKEN        GitHub personal access token

Team Configuration:
    --teams "team1,team2"       Comma-separated list of teams to onboard
    --team-leads "user1,user2"  Default team leads (applied to all teams)
    --github-org ORG            GitHub organization (defaults to --organization)

Infrastructure Options:
    --master-region REGION      AWS region for control plane (default: us-east-1)
    --domain DOMAIN             Base domain for team subdomains (default: atlantis.ORG.com)
    --certificate-arn ARN       Wildcard SSL certificate ARN for HTTPS
    --route53-zone-id ID        Route53 hosted zone ID

Integrations:
    --slack-webhook URL         Slack webhook URL for all teams
    --infracost-key KEY         Infracost API key for cost analysis

Advanced Options:
    --enable-control-tower      Use AWS Control Tower for governance
    --enable-sso               Enable AWS SSO integration
    --vpc-cidr-base CIDR       Base CIDR for team VPCs (default: 10.0.0.0/8)
    --default-team-size SIZE   Default Atlantis size per team (small/medium/large)

Deployment Control:
    --auto-approve             Skip all confirmation prompts
    --parallel-teams           Deploy teams in parallel (faster but higher AWS limits)
    --dry-run                  Show what would be deployed without creating resources

Examples:
    # Quick start with single team
    $0 --organization acme --github-token ghp_xxx --teams "platform"

    # Full enterprise setup
    $0 --organization acme \\
       --github-token ghp_xxx \\
       --teams "platform,data,security" \\
       --team-leads "admin1,admin2" \\
       --domain atlantis.acme.com \\
       --certificate-arn arn:aws:acm:us-east-1:123:certificate/xxx \\
       --slack-webhook https://hooks.slack.com/services/xxx \\
       --infracost-key ico-xxx \\
       --enable-control-tower \\
       --auto-approve

    # Development environment
    $0 --organization dev-corp \\
       --github-token ghp_xxx \\
       --teams "dev-team" \\
       --master-region us-west-2 \\
       --default-team-size small

EOF
}

# Default values
ORGANIZATION=""
GITHUB_TOKEN=""
TEAMS=""
TEAM_LEADS=""
GITHUB_ORG=""
MASTER_REGION="us-east-1"
DOMAIN=""
CERTIFICATE_ARN=""
ROUTE53_ZONE_ID=""
SLACK_WEBHOOK=""
INFRACOST_KEY=""
ENABLE_CONTROL_TOWER=false
ENABLE_SSO=false
VPC_CIDR_BASE="10.0.0.0/8"
DEFAULT_TEAM_SIZE="small"
AUTO_APPROVE=false
PARALLEL_TEAMS=false
DRY_RUN=false
AWS_PROFILE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --organization)
            ORGANIZATION="$2"
            shift 2
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --teams)
            TEAMS="$2"
            shift 2
            ;;
        --team-leads)
            TEAM_LEADS="$2"
            shift 2
            ;;
        --github-org)
            GITHUB_ORG="$2"
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
        --certificate-arn)
            CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --route53-zone-id)
            ROUTE53_ZONE_ID="$2"
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
        --enable-control-tower)
            ENABLE_CONTROL_TOWER=true
            shift
            ;;
        --enable-sso)
            ENABLE_SSO=true
            shift
            ;;
        --vpc-cidr-base)
            VPC_CIDR_BASE="$2"
            shift 2
            ;;
        --default-team-size)
            DEFAULT_TEAM_SIZE="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --parallel-teams)
            PARALLEL_TEAMS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --aws-profile)
            AWS_PROFILE="$2"
            shift 2
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

if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GitHub token is required (--github-token)"
fi

if [[ -z "$TEAMS" ]]; then
    log_error "At least one team is required (--teams)"
fi

# Set derived values
GITHUB_ORG="${GITHUB_ORG:-$ORGANIZATION}"
DOMAIN="${DOMAIN:-atlantis.$ORGANIZATION.com}"
TEAM_LEADS="${TEAM_LEADS:-admin}"

# Convert teams to array
IFS=',' read -ra TEAM_ARRAY <<< "$TEAMS"

show_banner
log_enterprise "Starting enterprise deployment for $ORGANIZATION"
log_info "Teams to deploy: ${TEAM_ARRAY[*]}"
log_info "Master region: $MASTER_REGION"
log_info "Domain: $DOMAIN"
log_info "GitHub org: $GITHUB_ORG"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    for tool in aws terraform jq curl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Validate AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "AWS credentials not configured for profile: $AWS_PROFILE"
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    log_success "Prerequisites validated - AWS Account: $ACCOUNT_ID"
}

# Deployment summary and confirmation
show_deployment_summary() {
    log_enterprise "DEPLOYMENT SUMMARY"
    echo ""
    echo "🏢 Organization: $ORGANIZATION"
    echo "🌍 Master Region: $MASTER_REGION"
    echo "🌐 Domain: $DOMAIN"
    echo "👥 GitHub Org: $GITHUB_ORG"
    echo "🔧 AWS Account: $ACCOUNT_ID"
    echo ""
    echo "👨‍👩‍👧‍👦 Teams (${#TEAM_ARRAY[@]}):"
    for team in "${TEAM_ARRAY[@]}"; do
        echo "  - $team (size: $DEFAULT_TEAM_SIZE)"
    done
    echo ""
    echo "🔗 Integrations:"
    echo "  - Slack: ${SLACK_WEBHOOK:+"Configured"}"
    echo "  - Infracost: ${INFRACOST_KEY:+"Configured"}"
    echo "  - HTTPS: ${CERTIFICATE_ARN:+"Enabled"}"
    echo "  - Control Tower: $ENABLE_CONTROL_TOWER"
    echo "  - SSO: $ENABLE_SSO"
    echo ""
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "DRY RUN MODE - No resources will be created"
        return
    fi
    
    if [[ $AUTO_APPROVE == false ]]; then
        read -p "🚀 Deploy this enterprise configuration? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment cancelled"
        fi
    fi
}

# Step 1: Bootstrap enterprise environment
bootstrap_enterprise() {
    log_enterprise "Step 1: Bootstrapping enterprise environment"
    
    local bootstrap_args=(
        "--organization" "$ORGANIZATION"
        "--master-region" "$MASTER_REGION"
        "--domain" "$DOMAIN"
        "--github-org" "$GITHUB_ORG"
        "--aws-profile" "$AWS_PROFILE"
        "--vpc-cidr-base" "$VPC_CIDR_BASE"
    )
    
    if [[ $ENABLE_CONTROL_TOWER == true ]]; then
        bootstrap_args+=("--enable-control-tower")
    fi
    
    if [[ $ENABLE_SSO == true ]]; then
        bootstrap_args+=("--enable-sso")
    fi
    
    if [[ $DRY_RUN == true ]]; then
        bootstrap_args+=("--dry-run")
    fi
    
    ./scripts/enterprise-bootstrap.sh "${bootstrap_args[@]}"
    log_success "Enterprise environment bootstrapped"
}

# Step 2: Onboard teams
onboard_teams() {
    log_enterprise "Step 2: Onboarding teams"
    
    local team_pids=()
    
    for i in "${!TEAM_ARRAY[@]}"; do
        local team="${TEAM_ARRAY[$i]}"
        log_info "Onboarding team: $team"
        
        local onboard_args=(
            "--team-name" "$team"
            "--team-leads" "$TEAM_LEADS"
            "--cost-center" "engineering"
            "--atlantis-size" "$DEFAULT_TEAM_SIZE"
            "--aws-region" "$MASTER_REGION"
            "--aws-profile" "$AWS_PROFILE"
        )
        
        if [[ $DRY_RUN == true ]]; then
            onboard_args+=("--dry-run")
        fi
        
        if [[ $PARALLEL_TEAMS == true ]]; then
            # Run in background for parallel execution
            ./scripts/onboard-team.sh "${onboard_args[@]}" &
            team_pids+=($!)
        else
            # Run sequentially
            ./scripts/onboard-team.sh "${onboard_args[@]}"
        fi
    done
    
    # Wait for parallel team onboarding to complete
    if [[ $PARALLEL_TEAMS == true ]]; then
        log_info "Waiting for all teams to be onboarded..."
        for pid in "${team_pids[@]}"; do
            wait "$pid"
        done
    fi
    
    log_success "All teams onboarded successfully"
}

# Step 3: Deploy team Atlantis instances
deploy_team_atlantis_instances() {
    log_enterprise "Step 3: Deploying team Atlantis instances"
    
    local deploy_pids=()
    
    for i in "${!TEAM_ARRAY[@]}"; do
        local team="${TEAM_ARRAY[$i]}"
        log_info "Deploying Atlantis for team: $team"
        
        local deploy_args=(
            "--team-name" "$team"
            "--github-token" "$GITHUB_TOKEN"
            "--aws-profile" "$AWS_PROFILE"
            "--terraform-version" "1.7.5"
            "--atlantis-version" "0.27.0"
        )
        
        # Add integrations if configured
        if [[ -n "$SLACK_WEBHOOK" ]]; then
            deploy_args+=("--slack-webhook" "$SLACK_WEBHOOK")
        fi
        
        if [[ -n "$INFRACOST_KEY" ]]; then
            deploy_args+=("--infracost-key" "$INFRACOST_KEY")
        fi
        
        if [[ -n "$CERTIFICATE_ARN" ]]; then
            deploy_args+=("--certificate-arn" "$CERTIFICATE_ARN")
        fi
        
        if [[ -n "$ROUTE53_ZONE_ID" ]]; then
            deploy_args+=("--route53-zone-id" "$ROUTE53_ZONE_ID")
        fi
        
        if [[ $AUTO_APPROVE == true ]]; then
            deploy_args+=("--auto-approve")
        fi
        
        if [[ $DRY_RUN == true ]]; then
            deploy_args+=("--dry-run")
        fi
        
        if [[ $PARALLEL_TEAMS == true ]]; then
            # Run in background for parallel execution
            ./scripts/deploy-team-atlantis.sh "${deploy_args[@]}" &
            deploy_pids+=($!)
        else
            # Run sequentially
            ./scripts/deploy-team-atlantis.sh "${deploy_args[@]}"
        fi
    done
    
    # Wait for parallel deployments to complete
    if [[ $PARALLEL_TEAMS == true ]]; then
        log_info "Waiting for all Atlantis deployments to complete..."
        for pid in "${deploy_pids[@]}"; do
            wait "$pid"
        done
    fi
    
    log_success "All team Atlantis instances deployed successfully"
}

# Step 4: Generate enterprise summary
generate_enterprise_summary() {
    log_enterprise "Step 4: Generating enterprise summary"
    
    local summary_file="/tmp/stackkit-enterprise-$ORGANIZATION-SUMMARY.md"
    
    cat > "$summary_file" << EOF
# StackKit Enterprise Deployment Summary

## Organization: $ORGANIZATION
**Deployed**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**AWS Account**: $ACCOUNT_ID
**Master Region**: $MASTER_REGION
**Domain**: $DOMAIN
**GitHub Org**: $GITHUB_ORG

## Teams Deployed (${#TEAM_ARRAY[@]} teams)

EOF
    
    for team in "${TEAM_ARRAY[@]}"; do
        local team_url
        if [[ $DRY_RUN == true ]]; then
            team_url="https://$team.$DOMAIN (dry run)"
        else
            team_url="https://$team.$DOMAIN"
        fi
        
        cat >> "$summary_file" << EOF
### Team: $team
- **Atlantis URL**: $team_url
- **Webhook URL**: $team_url/events
- **Size**: $DEFAULT_TEAM_SIZE
- **AWS Region**: $MASTER_REGION
- **Status**: $(if [[ $DRY_RUN == true ]]; then echo "Dry Run"; else echo "Deployed"; fi)

EOF
    done
    
    cat >> "$summary_file" << EOF

## Enterprise Resources

### Control Plane
- **S3 Buckets**: 
  - stackkit-enterprise-$ORGANIZATION-control-plane
  - stackkit-enterprise-$ORGANIZATION-team-templates
  - stackkit-enterprise-$ORGANIZATION-audit-logs
  - stackkit-enterprise-$ORGANIZATION-backups

- **DynamoDB Tables**:
  - stackkit-enterprise-$ORGANIZATION-teams
  - stackkit-enterprise-$ORGANIZATION-audit
  - stackkit-enterprise-$ORGANIZATION-locks

### Per-Team Resources
Each team has isolated:
- Dedicated VPC (10.{team-id}.0.0/16)
- ECS Fargate Atlantis instance
- S3 state bucket with encryption
- DynamoDB lock table
- IAM roles with boundary policies
- CloudWatch logs and monitoring

## Next Steps

### 1. Configure GitHub Repository Webhooks
For each repository in each team, add webhook:
\`\`\`bash
# For team '$team' and repo 'my-repo'
curl -X POST \\
  -H "Authorization: token $GITHUB_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "name": "web",
    "active": true,
    "events": ["issue_comment", "pull_request", "pull_request_review", "push"],
    "config": {
      "url": "https://$team.$DOMAIN/events",
      "content_type": "json"
    }
  }' \\
  "https://api.github.com/repos/$GITHUB_ORG/my-repo/hooks"
\`\`\`

### 2. Configure Branch Protection Rules
For each repository:
- Require pull request reviews
- Require status checks: \`atlantis/plan\`
- Require branches to be up to date

### 3. Add atlantis.yaml to Repositories
\`\`\`yaml
version: 3
projects:
- name: main
  dir: .
  terraform_version: 1.7.5
  workflow: default
  apply_requirements: ["approved", "mergeable"]
\`\`\`

### 4. Team Access Management
- Add users to appropriate GitHub teams
- Configure AWS SSO access (if enabled)
- Set up team-specific Slack channels

## Monitoring and Management

### Enterprise Dashboard
- **AWS Console**: Resource Groups by Organization tag
- **Cost Explorer**: Filter by CostCenter tags
- **CloudWatch**: Centralized logging and monitoring

### Team Management Commands
\`\`\`bash
# List all teams
./scripts/list-teams.sh

# Scale team resources
./scripts/scale-team.sh --team-name platform --atlantis-size medium

# Add new team
./scripts/onboard-team.sh --team-name new-team --team-leads "admin1,admin2"

# Deploy new team Atlantis
./scripts/deploy-team-atlantis.sh --team-name new-team --github-token \$TOKEN
\`\`\`

### Troubleshooting
\`\`\`bash
# Check team health
./scripts/diagnose-team.sh --team-name platform

# View team logs
aws logs tail /ecs/stackkit-team-platform-atlantis --follow

# Update team secrets
aws secretsmanager update-secret --secret-id stackkit-team-platform-atlantis-secrets
\`\`\`

## Support
- **Enterprise Slack**: #stackkit-enterprise
- **Documentation**: /docs/ in repository
- **GitHub Issues**: Repository issue tracker

## Security and Compliance
- All resources encrypted at rest and in transit
- Network isolation via dedicated VPCs per team  
- IAM boundary policies prevent privilege escalation
- Audit logging enabled for all teams
- Cost allocation tags for billing separation
- Backup retention: 90 days (configurable)

---
**Generated by StackKit Enterprise Quick Deploy**
EOF

    log_success "Enterprise summary generated: $summary_file"
    
    # Display key information
    echo ""
    log_enterprise "🎉 DEPLOYMENT COMPLETE!"
    echo ""
    echo "📊 Enterprise Dashboard: https://console.aws.amazon.com/resource-groups/tag-editor?region=$MASTER_REGION#/tagFilters/Organization=$ORGANIZATION"
    echo "📁 Summary Document: $summary_file"
    echo ""
    echo "🚀 Team Atlantis URLs:"
    for team in "${TEAM_ARRAY[@]}"; do
        local team_url="https://$team.$DOMAIN"
        echo "  - $team: $team_url"
    done
    echo ""
    log_warning "Next: Configure GitHub webhooks and repository branch protection rules"
    
    if [[ $DRY_RUN == true ]]; then
        echo ""
        log_warning "This was a DRY RUN. No actual resources were created."
    fi
}

# Main execution
main() {
    check_prerequisites
    show_deployment_summary
    
    if [[ $DRY_RUN == false || $AUTO_APPROVE == true ]]; then
        bootstrap_enterprise
        onboard_teams
        deploy_team_atlantis_instances
        generate_enterprise_summary
    else
        log_info "Dry run completed. Use --auto-approve to proceed with actual deployment."
    fi
}

# Execute main function
main "$@"