#!/bin/bash

# StackKit Security Framework Deployment Script
# Automated deployment of enterprise security controls

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$SECURITY_DIR")"
TERRAFORM_DIR="$SECURITY_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Deployment configuration
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-plan}"  # plan, apply, destroy
ENVIRONMENT="${ENVIRONMENT:-prod}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
BACKUP_STATE="${BACKUP_STATE:-true}"

# Validate required tools
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform not found${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI not found${NC}"; exit 1; }

# Function: Print section header
print_section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Function: Print status message
print_status() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "SUCCESS"|"PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "ERROR"|"FAIL")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARNING"|"WARN")
            echo -e "${YELLOW}⚠️ $message${NC}"
            ;;
        "INFO")
            echo -e "${CYAN}ℹ️ $message${NC}"
            ;;
        "STEP")
            echo -e "${BLUE}🔄 $message${NC}"
            ;;
    esac
}

# Function: Validate prerequisites
validate_prerequisites() {
    print_section "Validating Prerequisites"
    
    # Check AWS connectivity
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        print_status "SUCCESS" "AWS connectivity verified (Account: $account_id)"
    else
        print_status "ERROR" "AWS connectivity failed - check credentials"
        exit 1
    fi
    
    # Check Terraform version
    local terraform_version=$(terraform version -json | jq -r '.terraform_version')
    print_status "INFO" "Terraform version: $terraform_version"
    
    # Validate Terraform configuration
    cd "$TERRAFORM_DIR"
    if terraform validate >/dev/null 2>&1; then
        print_status "SUCCESS" "Terraform configuration is valid"
    else
        print_status "ERROR" "Terraform configuration validation failed"
        terraform validate
        exit 1
    fi
    
    # Check for terraform.tfvars
    if [[ -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        print_status "SUCCESS" "Terraform variables file found"
    else
        print_status "WARNING" "No terraform.tfvars found - using defaults"
    fi
}

# Function: Initialize Terraform
initialize_terraform() {
    print_section "Initializing Terraform"
    
    cd "$TERRAFORM_DIR"
    
    print_status "STEP" "Running terraform init..."
    if terraform init -upgrade; then
        print_status "SUCCESS" "Terraform initialized successfully"
    else
        print_status "ERROR" "Terraform initialization failed"
        exit 1
    fi
}

# Function: Plan security deployment
plan_deployment() {
    print_section "Planning Security Deployment"
    
    cd "$TERRAFORM_DIR"
    
    local plan_file="security-plan-$TIMESTAMP.tfplan"
    
    print_status "STEP" "Generating deployment plan..."
    
    # Create comprehensive plan
    if terraform plan \
        -var="environment=$ENVIRONMENT" \
        -out="$plan_file" \
        -detailed-exitcode; then
        
        local exit_code=$?
        case $exit_code in
            0)
                print_status "INFO" "No changes required"
                ;;
            2)
                print_status "SUCCESS" "Deployment plan created: $plan_file"
                
                # Show plan summary
                print_status "STEP" "Displaying plan summary..."
                terraform show -json "$plan_file" | jq -r '
                    .resource_changes[] | 
                    select(.change.actions[] | . != "no-op") |
                    "\(.change.actions | join(",")): \(.address)"
                ' | sort | uniq -c
                ;;
        esac
        
        # Save plan for potential apply
        export TERRAFORM_PLAN_FILE="$plan_file"
        
    else
        print_status "ERROR" "Terraform planning failed"
        exit 1
    fi
}

# Function: Apply security deployment
apply_deployment() {
    print_section "Applying Security Deployment"
    
    cd "$TERRAFORM_DIR"
    
    # Backup state if enabled
    if [[ "$BACKUP_STATE" == "true" ]]; then
        print_status "STEP" "Backing up Terraform state..."
        if [[ -f "terraform.tfstate" ]]; then
            cp terraform.tfstate "terraform.tfstate.backup-$TIMESTAMP"
            print_status "SUCCESS" "State backed up"
        fi
    fi
    
    # Apply configuration
    print_status "STEP" "Applying security configuration..."
    
    local apply_args=()
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        apply_args+=("-auto-approve")
    fi
    
    if [[ -n "${TERRAFORM_PLAN_FILE:-}" ]]; then
        apply_args+=("$TERRAFORM_PLAN_FILE")
    else
        apply_args+=("-var=environment=$ENVIRONMENT")
    fi
    
    if terraform apply "${apply_args[@]}"; then
        print_status "SUCCESS" "Security framework deployed successfully"
    else
        print_status "ERROR" "Security deployment failed"
        
        # Restore state backup if deployment failed
        if [[ "$BACKUP_STATE" == "true" ]] && [[ -f "terraform.tfstate.backup-$TIMESTAMP" ]]; then
            print_status "STEP" "Restoring previous state..."
            cp "terraform.tfstate.backup-$TIMESTAMP" terraform.tfstate
            print_status "WARNING" "State restored from backup"
        fi
        
        exit 1
    fi
}

# Function: Validate deployment
validate_deployment() {
    print_section "Validating Deployment"
    
    cd "$TERRAFORM_DIR"
    
    # Get Terraform outputs
    print_status "STEP" "Retrieving deployment outputs..."
    if terraform output -json > "outputs-$TIMESTAMP.json"; then
        print_status "SUCCESS" "Deployment outputs saved"
    else
        print_status "WARNING" "Could not retrieve all outputs"
    fi
    
    # Validate key resources
    print_status "STEP" "Validating key security resources..."
    
    # Check for team roles
    local team_roles=$(aws iam list-roles --path-prefix "/teams/" --query 'length(Roles)' --output text 2>/dev/null || echo 0)
    if [[ "$team_roles" -gt 0 ]]; then
        print_status "SUCCESS" "Team roles deployed ($team_roles roles)"
    else
        print_status "WARNING" "No team roles found"
    fi
    
    # Check for secrets
    local stackkit_secrets=$(aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name, `stackkit/`)] | length(@)' --output text 2>/dev/null || echo 0)
    if [[ "$stackkit_secrets" -gt 0 ]]; then
        print_status "SUCCESS" "StackKit secrets deployed ($stackkit_secrets secrets)"
    else
        print_status "WARNING" "No StackKit secrets found"
    fi
    
    # Check for Lambda functions
    local security_functions=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `stackkit`)] | length(@)' --output text 2>/dev/null || echo 0)
    if [[ "$security_functions" -gt 0 ]]; then
        print_status "SUCCESS" "Security Lambda functions deployed ($security_functions functions)"
    else
        print_status "WARNING" "No security Lambda functions found"
    fi
    
    # Check Config recorder
    local config_recorders=$(aws configservice describe-configuration-recorders --query 'length(ConfigurationRecorders)' --output text 2>/dev/null || echo 0)
    if [[ "$config_recorders" -gt 0 ]]; then
        print_status "SUCCESS" "AWS Config recorders active"
    else
        print_status "WARNING" "No AWS Config recorders found"
    fi
}

# Function: Run security assessment
run_security_assessment() {
    print_section "Running Security Assessment"
    
    if [[ -x "$SCRIPT_DIR/security-assessment.sh" ]]; then
        print_status "STEP" "Running automated security assessment..."
        "$SCRIPT_DIR/security-assessment.sh"
    else
        print_status "WARNING" "Security assessment script not found or not executable"
    fi
}

# Function: Generate deployment report
generate_deployment_report() {
    print_section "Generating Deployment Report"
    
    local report_dir="$PROJECT_ROOT/claudedocs/security-reports"
    mkdir -p "$report_dir"
    
    local deployment_report="$report_dir/security-deployment-$TIMESTAMP.md"
    
    cat > "$deployment_report" << EOF
# StackKit Security Framework Deployment Report

**Deployment Date**: $(date)
**Environment**: $ENVIRONMENT
**Deployment Mode**: $DEPLOYMENT_MODE
**Terraform Version**: $(terraform version -json | jq -r '.terraform_version')

## Deployment Summary

EOF
    
    # Add Terraform outputs if available
    if [[ -f "$TERRAFORM_DIR/outputs-$TIMESTAMP.json" ]]; then
        echo "### Terraform Outputs" >> "$deployment_report"
        echo "" >> "$deployment_report"
        echo '```json' >> "$deployment_report"
        cat "$TERRAFORM_DIR/outputs-$TIMESTAMP.json" >> "$deployment_report"
        echo '```' >> "$deployment_report"
        echo "" >> "$deployment_report"
    fi
    
    # Add resource counts
    cat >> "$deployment_report" << EOF
### Deployed Resources

- **IAM Roles**: $(aws iam list-roles --path-prefix "/teams/" --query 'length(Roles)' --output text 2>/dev/null || echo 0)
- **Secrets**: $(aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name, `stackkit/`)] | length(@)' --output text 2>/dev/null || echo 0)  
- **Lambda Functions**: $(aws lambda list-functions --query 'Functions[?contains(FunctionName, `stackkit`)] | length(@)' --output text 2>/dev/null || echo 0)
- **Config Rules**: $(aws configservice describe-config-rules --query 'ConfigRules[?starts_with(ConfigRuleName, `stackkit`)] | length(@)' --output text 2>/dev/null || echo 0)

### Next Steps

1. **Configure Team Access**: Set up team-specific access patterns
2. **Customize Compliance**: Configure compliance frameworks for your organization
3. **Set Up Monitoring**: Configure alerting and notification endpoints
4. **Test Security**: Run comprehensive security testing

### Support Resources

- Security Assessment Script: \`./security/scripts/security-assessment.sh\`
- Compliance Validation: \`./security/scripts/compliance-validation.sh\`
- Documentation: \`./security/README.md\`

---
*Report generated by StackKit Security Deployment v1.0.0*
EOF

    print_status "SUCCESS" "Deployment report generated: $deployment_report"
}

# Function: Cleanup temporary files
cleanup() {
    print_status "STEP" "Cleaning up temporary files..."
    
    cd "$TERRAFORM_DIR"
    
    # Remove plan files older than 7 days
    find . -name "security-plan-*.tfplan" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Remove old output files
    find . -name "outputs-*.json" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Remove old state backups (keep last 5)
    ls -t terraform.tfstate.backup-* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    print_status "SUCCESS" "Cleanup completed"
}

# Function: Show usage
show_usage() {
    cat << EOF
StackKit Security Framework Deployment Script

Usage: $0 [OPTIONS]

Options:
    -m, --mode MODE         Deployment mode: plan, apply, destroy (default: plan)
    -e, --environment ENV   Target environment: dev, staging, prod (default: prod)  
    -a, --auto-approve     Auto-approve changes (dangerous, use with caution)
    -b, --no-backup        Skip state backup
    -h, --help             Show this help message

Environment Variables:
    DEPLOYMENT_MODE        Same as --mode
    ENVIRONMENT           Same as --environment
    AUTO_APPROVE          Set to 'true' for auto-approve
    BACKUP_STATE          Set to 'false' to skip backup

Examples:
    $0 --mode plan                    # Plan deployment
    $0 --mode apply --environment dev # Deploy to dev environment
    $0 --mode apply --auto-approve    # Apply with auto-approval
    $0 --mode destroy                 # Destroy security resources

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--auto-approve)
            AUTO_APPROVE="true"
            shift
            ;;
        -b|--no-backup)
            BACKUP_STATE="false"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validate deployment mode
case "$DEPLOYMENT_MODE" in
    plan|apply|destroy)
        ;;
    *)
        echo -e "${RED}❌ Invalid deployment mode: $DEPLOYMENT_MODE${NC}"
        echo -e "${CYAN}Valid modes: plan, apply, destroy${NC}"
        exit 1
        ;;
esac

# Main execution
main() {
    echo -e "${BLUE}🚀 StackKit Security Framework Deployment${NC}"
    echo -e "${CYAN}Mode: $DEPLOYMENT_MODE | Environment: $ENVIRONMENT | $(date)${NC}\n"
    
    # Warning for destructive operations
    if [[ "$DEPLOYMENT_MODE" == "apply" || "$DEPLOYMENT_MODE" == "destroy" ]]; then
        if [[ "$AUTO_APPROVE" != "true" ]]; then
            echo -e "${YELLOW}⚠️ This will modify AWS resources. Continue? (y/N)${NC}"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}ℹ️ Deployment cancelled${NC}"
                exit 0
            fi
        fi
    fi
    
    # Run deployment steps
    validate_prerequisites
    initialize_terraform
    
    case "$DEPLOYMENT_MODE" in
        plan)
            plan_deployment
            ;;
        apply)
            plan_deployment
            apply_deployment  
            validate_deployment
            run_security_assessment
            generate_deployment_report
            ;;
        destroy)
            print_status "WARNING" "Destroying security resources..."
            cd "$TERRAFORM_DIR"
            local destroy_args=()
            if [[ "$AUTO_APPROVE" == "true" ]]; then
                destroy_args+=("-auto-approve")
            fi
            terraform destroy "${destroy_args[@]}" -var="environment=$ENVIRONMENT"
            ;;
    esac
    
    cleanup
    
    echo -e "\n${GREEN}✅ Deployment operation completed successfully${NC}"
    
    if [[ "$DEPLOYMENT_MODE" == "apply" ]]; then
        echo -e "${CYAN}📊 Next steps:${NC}"
        echo -e "  1. Review deployment report in claudedocs/security-reports/"
        echo -e "  2. Configure team access and notification endpoints"
        echo -e "  3. Run security assessment: ./security/scripts/security-assessment.sh"
        echo -e "  4. Set up ongoing monitoring and alerting"
    fi
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}⚠️ Deployment interrupted${NC}"; exit 1' SIGINT SIGTERM

# Execute main function
main "$@"