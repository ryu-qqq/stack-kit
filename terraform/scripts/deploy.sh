#!/usr/bin/env bash
set -euo pipefail

# Environment-specific deployment automation script
# Usage: scripts/deploy.sh <stack_name> <env> [action] [OPTIONS]

show_help() {
    cat << EOF
Usage: $0 <stack_name> <env> [action] [OPTIONS]

Arguments:
    stack_name    Name of the stack to deploy
    env          Environment (dev|staging|prod)
    action       Action to perform: plan|apply|destroy (default: plan)

Options:
    --auto-approve   Auto approve apply/destroy (skip confirmation)
    --target=RESOURCE Target specific resource for plan/apply
    --var-file=FILE  Additional tfvars file to load
    --parallelism=N  Number of concurrent operations (default: 10)
    --backup-state   Backup state before apply/destroy
    --rollback       Rollback to previous state (requires backup)
    --detailed       Show detailed output
    --help          Show this help message

Safety Options:
    --force         Skip safety checks (not recommended for prod)
    --dry-run       Show what would be done (implies plan)

Examples:
    $0 my-web-app dev plan
    $0 my-web-app staging apply --auto-approve
    $0 my-web-app prod destroy --backup-state
    $0 my-api dev apply --target=module.database
EOF
}

# Parse arguments
STACK="${1:-}"
ENV="${2:-}"
ACTION="${3:-plan}"
AUTO_APPROVE=false
TARGET=""
ADDITIONAL_VAR_FILE=""
PARALLELISM=10
BACKUP_STATE=false
ROLLBACK=false
DETAILED=false
FORCE=false
DRY_RUN=false

if [[ -z "$STACK" || -z "$ENV" ]]; then
    show_help
    exit 1
fi

# Parse optional arguments
for arg in "${@:4}"; do
    case $arg in
        --auto-approve)
            AUTO_APPROVE=true
            ;;
        --target=*)
            TARGET="${arg#*=}"
            ;;
        --var-file=*)
            ADDITIONAL_VAR_FILE="${arg#*=}"
            ;;
        --parallelism=*)
            PARALLELISM="${arg#*=}"
            ;;
        --backup-state)
            BACKUP_STATE=true
            ;;
        --rollback)
            ROLLBACK=true
            ACTION="apply"  # Rollback is essentially an apply
            ;;
        --detailed)
            DETAILED=true
            ;;
        --force)
            FORCE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ACTION="plan"
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo "❌ Invalid action: $ACTION. Must be: plan|apply|destroy"
    exit 1
fi

# Validate environment
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Invalid environment: $ENV. Must be: dev|staging|prod"
    exit 1
fi

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_DIR="$INFRA_ROOT/stacks/${STACK}/${ENV}"

# Validate stack directory exists
if [[ ! -d "$STACK_DIR" ]]; then
    echo "❌ Stack directory not found: $STACK_DIR"
    echo "💡 Create stack first: scripts/new-stack.sh $STACK $ENV"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Safety checks
safety_checks() {
    log_info "Running safety checks for $ENV environment..."
    
    # Production safety checks
    if [[ "$ENV" == "prod" && "$FORCE" != "true" ]]; then
        log_warning "Production environment detected - additional safety measures"
        
        if [[ "$ACTION" == "destroy" ]]; then
            log_error "Destroy action on production requires --force flag"
            echo "This is a safety measure to prevent accidental production destruction."
            exit 1
        fi
        
        if [[ "$ACTION" == "apply" && "$AUTO_APPROVE" == "true" ]]; then
            log_error "Auto-approve on production requires --force flag"
            echo "Production changes should be manually reviewed and approved."
            exit 1
        fi
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or expired"
        echo "Configure AWS credentials: aws configure"
        exit 1
    fi
    
    # Validate current AWS account/region matches expectation
    local current_account=$(aws sts get-caller-identity --query Account --output text)
    local current_region=$(aws configure get region)
    
    log_info "AWS Account: $current_account"
    log_info "AWS Region: $current_region"
    
    # Run policy validation
    if [[ -f "$INFRA_ROOT/scripts/tf_forbidden.sh" ]]; then
        log_info "Running policy validation..."
        if ! bash "$INFRA_ROOT/scripts/tf_forbidden.sh"; then
            log_error "Policy validation failed"
            exit 1
        fi
        log_success "Policy validation passed"
    fi
    
    log_success "Safety checks completed"
}

# State backup
backup_state() {
    if [[ "$BACKUP_STATE" == "true" ]]; then
        log_info "Creating state backup..."
        
        local backup_dir="$STACK_DIR/backups"
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_file="$backup_dir/terraform.tfstate.backup.$timestamp"
        
        mkdir -p "$backup_dir"
        
        # Pull current state
        cd "$STACK_DIR"
        if terraform state pull > "$backup_file" 2>/dev/null; then
            log_success "State backed up to: $backup_file"
            echo "$backup_file" > "$backup_dir/latest_backup"
        else
            log_warning "Could not backup state (may be empty)"
        fi
    fi
}

# State rollback
rollback_state() {
    if [[ "$ROLLBACK" == "true" ]]; then
        log_info "Rolling back to previous state..."
        
        local backup_dir="$STACK_DIR/backups"
        local latest_backup_file="$backup_dir/latest_backup"
        
        if [[ ! -f "$latest_backup_file" ]]; then
            log_error "No backup found for rollback"
            exit 1
        fi
        
        local backup_path=$(cat "$latest_backup_file")
        if [[ ! -f "$backup_path" ]]; then
            log_error "Backup file not found: $backup_path"
            exit 1
        fi
        
        cd "$STACK_DIR"
        if terraform state push "$backup_path"; then
            log_success "State rolled back successfully"
        else
            log_error "State rollback failed"
            exit 1
        fi
    fi
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    
    cd "$STACK_DIR"
    
    local init_args=()
    init_args+=("-backend-config=backend.hcl")
    
    if [[ "$DETAILED" != "true" ]]; then
        init_args+=("-input=false")
    fi
    
    if terraform init "${init_args[@]}"; then
        log_success "Terraform initialized"
    else
        log_error "Terraform initialization failed"
        exit 1
    fi
}

# Build Terraform command arguments
build_tf_args() {
    local tf_args=()
    
    # Always include terraform.tfvars if it exists
    if [[ -f "terraform.tfvars" ]]; then
        tf_args+=("-var-file=terraform.tfvars")
    fi
    
    # Additional var file
    if [[ -n "$ADDITIONAL_VAR_FILE" ]]; then
        if [[ -f "$ADDITIONAL_VAR_FILE" ]]; then
            tf_args+=("-var-file=$ADDITIONAL_VAR_FILE")
        else
            log_error "Additional var file not found: $ADDITIONAL_VAR_FILE"
            exit 1
        fi
    fi
    
    # Target resource
    if [[ -n "$TARGET" ]]; then
        tf_args+=("-target=$TARGET")
    fi
    
    # Parallelism
    tf_args+=("-parallelism=$PARALLELISM")
    
    # Auto approve for apply/destroy
    if [[ "$AUTO_APPROVE" == "true" && "$ACTION" != "plan" ]]; then
        tf_args+=("-auto-approve")
    fi
    
    # Detailed output
    if [[ "$DETAILED" == "true" ]]; then
        tf_args+=("-input=true")
    else
        tf_args+=("-input=false")
    fi
    
    echo "${tf_args[@]}"
}

# Execute Terraform action
execute_terraform() {
    local action=$1
    
    cd "$STACK_DIR"
    
    log_info "Executing: terraform $action"
    
    local tf_args=()
    read -ra tf_args <<< "$(build_tf_args)"
    
    case $action in
        plan)
            tf_args+=("-out=tfplan")
            if terraform plan "${tf_args[@]}"; then
                log_success "Plan completed successfully"
                
                # Show plan summary
                if command -v terraform-landscape >/dev/null 2>&1; then
                    terraform show tfplan | terraform-landscape
                else
                    terraform show tfplan
                fi
            else
                log_error "Plan failed"
                exit 1
            fi
            ;;
        apply)
            if [[ "$ROLLBACK" != "true" ]]; then
                if terraform apply "${tf_args[@]}"; then
                    log_success "Apply completed successfully"
                    
                    # Show outputs
                    log_info "Stack outputs:"
                    terraform output
                else
                    log_error "Apply failed"
                    exit 1
                fi
            fi
            ;;
        destroy)
            log_warning "⚠️  DESTROY operation will delete all resources!"
            
            if [[ "$AUTO_APPROVE" != "true" ]]; then
                echo -n "Type 'yes' to confirm destruction: "
                read -r confirmation
                if [[ "$confirmation" != "yes" ]]; then
                    log_info "Destruction cancelled"
                    exit 0
                fi
            fi
            
            if terraform destroy "${tf_args[@]}"; then
                log_success "Destroy completed successfully"
            else
                log_error "Destroy failed"
                exit 1
            fi
            ;;
    esac
}

# Post-deployment tasks
post_deployment() {
    if [[ "$ACTION" == "apply" ]]; then
        log_info "Running post-deployment tasks..."
        
        # Generate outputs file
        cd "$STACK_DIR"
        terraform output -json > outputs.json
        log_success "Outputs saved to outputs.json"
        
        # Optional: run tests or health checks
        # if [[ -f "post-deploy-tests.sh" ]]; then
        #     bash post-deploy-tests.sh
        # fi
    fi
}

# Main execution
main() {
    echo "🚀 Terraform Deployment Automation"
    echo "=================================="
    echo "Stack: $STACK"
    echo "Environment: $ENV" 
    echo "Action: $ACTION"
    echo "Directory: $STACK_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Mode: DRY RUN (plan only)"
    fi
    
    echo ""
    
    # Execute deployment pipeline
    safety_checks
    backup_state
    rollback_state
    init_terraform
    execute_terraform "$ACTION"
    post_deployment
    
    log_success "Deployment completed successfully! 🎉"
}

# Handle cleanup on exit
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code: $exit_code"
        
        # Optionally restore from backup on failure
        if [[ "$BACKUP_STATE" == "true" && "$ACTION" == "apply" ]]; then
            log_info "Consider rolling back with: $0 $STACK $ENV apply --rollback"
        fi
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Run main function
main