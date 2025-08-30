#!/usr/bin/env bash
set -euo pipefail

# Safe infrastructure teardown script
# Usage: scripts/destroy.sh <stack_name> <env> [OPTIONS]

show_help() {
    cat << EOF
Usage: $0 <stack_name> <env> [OPTIONS]

Arguments:
    stack_name    Name of the stack to destroy
    env          Environment (dev|staging|prod)

Options:
    --force         Skip all safety prompts (dangerous!)
    --backup-state  Backup state before destruction
    --target=RESOURCE Destroy only specific resource
    --list-resources List all resources without destroying
    --preview       Show destruction plan without executing
    --help          Show this help message

Safety Features:
    - Multiple confirmation prompts for production
    - Automatic state backup before destruction
    - Resource dependency analysis
    - Protection for critical resources (configurable)

Examples:
    $0 my-web-app dev --preview
    $0 my-web-app staging --backup-state
    $0 old-stack prod --list-resources
    $0 my-api dev --target=module.database --force
EOF
}

# Parse arguments
STACK="${1:-}"
ENV="${2:-}"
FORCE=false
BACKUP_STATE=true  # Default to true for safety
TARGET=""
LIST_RESOURCES=false
PREVIEW=false

if [[ -z "$STACK" || -z "$ENV" ]]; then
    show_help
    exit 1
fi

# Parse optional arguments
for arg in "${@:3}"; do
    case $arg in
        --force)
            FORCE=true
            ;;
        --backup-state)
            BACKUP_STATE=true
            ;;
        --target=*)
            TARGET="${arg#*=}"
            ;;
        --list-resources)
            LIST_RESOURCES=true
            ;;
        --preview)
            PREVIEW=true
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

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_DIR="$INFRA_ROOT/stacks/${STACK}/${ENV}"

# Validate stack directory exists
if [[ ! -d "$STACK_DIR" ]]; then
    echo "❌ Stack directory not found: $STACK_DIR"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_critical() {
    echo -e "${RED}🚨 CRITICAL: $1${NC}"
}

log_danger() {
    echo -e "${PURPLE}💀 DANGER: $1${NC}"
}

# Protected resources (add patterns for resources that should not be easily destroyed)
PROTECTED_RESOURCES=(
    "aws_s3_bucket.*backup.*"
    "aws_s3_bucket.*logs.*" 
    "aws_dynamodb_table.*lock.*"
    "aws_kms_key"
    "aws_backup_vault"
    "aws_cloudtrail"
)

# Check for protected resources
check_protected_resources() {
    log_info "Checking for protected resources..."
    
    cd "$STACK_DIR"
    
    if [[ ! -f "terraform.tfstate" ]]; then
        log_warning "No state file found - cannot check protected resources"
        return 0
    fi
    
    local protected_found=false
    local protected_list=()
    
    # Get list of resources from state
    local resources
    if ! resources=$(terraform state list 2>/dev/null); then
        log_warning "Could not read state - skipping protection check"
        return 0
    fi
    
    # Check each resource against protection patterns
    while IFS= read -r resource; do
        for pattern in "${PROTECTED_RESOURCES[@]}"; do
            if [[ "$resource" =~ $pattern ]]; then
                protected_found=true
                protected_list+=("$resource")
                break
            fi
        done
    done <<< "$resources"
    
    if [[ "$protected_found" == "true" ]]; then
        log_critical "Protected resources found in stack:"
        printf '%s\n' "${protected_list[@]}" | sed 's/^/  🛡️  /'
        echo ""
        
        if [[ "$FORCE" != "true" ]]; then
            log_error "Destruction blocked due to protected resources"
            echo "Use --target to destroy specific resources or --force to override (dangerous!)"
            exit 1
        else
            log_danger "Force flag enabled - protected resources will be destroyed!"
        fi
    else
        log_success "No protected resources found"
    fi
}

# Get resource count and details
analyze_resources() {
    log_info "Analyzing resources to be destroyed..."
    
    cd "$STACK_DIR"
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init -backend-config=backend.hcl >/dev/null 2>&1
    fi
    
    # Generate destroy plan
    local plan_args=()
    if [[ -n "$TARGET" ]]; then
        plan_args+=("-target=$TARGET")
    fi
    
    if [[ -f "terraform.tfvars" ]]; then
        plan_args+=("-var-file=terraform.tfvars")
    fi
    
    plan_args+=("-destroy" "-out=destroy.tfplan")
    
    if terraform plan "${plan_args[@]}" >/dev/null 2>&1; then
        # Parse plan for resource counts
        local plan_summary
        if plan_summary=$(terraform show -json destroy.tfplan 2>/dev/null); then
            local destroy_count
            destroy_count=$(echo "$plan_summary" | jq -r '[.resource_changes[]? | select(.change.actions[] == "delete")] | length' 2>/dev/null || echo "unknown")
            
            log_warning "Resources to be destroyed: $destroy_count"
            
            # Show resource breakdown
            if [[ "$destroy_count" != "0" && "$destroy_count" != "unknown" ]]; then
                echo ""
                log_info "Resource breakdown:"
                
                # Group by resource type
                local resource_types
                if resource_types=$(echo "$plan_summary" | jq -r '[.resource_changes[]? | select(.change.actions[] == "delete")] | group_by(.type) | .[] | "\(length) \(.[0].type)"' 2>/dev/null); then
                    while IFS= read -r line; do
                        echo "  📦 $line"
                    done <<< "$resource_types"
                fi
            fi
        else
            log_warning "Could not analyze destroy plan details"
        fi
        
        # Show destroy plan if preview mode
        if [[ "$PREVIEW" == "true" ]]; then
            echo ""
            log_info "Destroy plan preview:"
            terraform show destroy.tfplan
        fi
    else
        log_error "Could not generate destroy plan"
        exit 1
    fi
}

# List all resources
list_resources() {
    log_info "Listing all resources in stack..."
    
    cd "$STACK_DIR"
    
    if terraform state list 2>/dev/null | while IFS= read -r resource; do
        # Get resource details
        local resource_info
        if resource_info=$(terraform state show "$resource" 2>/dev/null | head -5); then
            echo "📋 $resource"
            echo "$resource_info" | grep -E "^\s*id\s*=" | sed 's/^/    /'
            echo ""
        else
            echo "📋 $resource (details unavailable)"
        fi
    done; then
        log_success "Resource listing completed"
    else
        log_error "Could not list resources"
        exit 1
    fi
}

# Backup state
backup_state() {
    if [[ "$BACKUP_STATE" == "true" ]]; then
        log_info "Creating state backup before destruction..."
        
        local backup_dir="$STACK_DIR/backups"
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_file="$backup_dir/terraform.tfstate.pre-destroy.$timestamp"
        
        mkdir -p "$backup_dir"
        
        cd "$STACK_DIR"
        if terraform state pull > "$backup_file" 2>/dev/null; then
            log_success "State backed up to: $backup_file"
            echo "$backup_file" > "$backup_dir/pre_destroy_backup"
        else
            log_warning "Could not backup state"
        fi
    fi
}

# Multi-level confirmation for production
production_confirmation() {
    if [[ "$ENV" == "prod" && "$FORCE" != "true" ]]; then
        log_critical "PRODUCTION ENVIRONMENT DESTRUCTION"
        echo ""
        echo "You are about to destroy infrastructure in PRODUCTION!"
        echo "This action is IRREVERSIBLE and will:"
        echo "  - Delete all resources in the stack"
        echo "  - Potentially cause service downtime" 
        echo "  - Result in data loss"
        echo ""
        
        # First confirmation
        echo -n "Type the stack name '$STACK' to continue: "
        read -r stack_confirm
        if [[ "$stack_confirm" != "$STACK" ]]; then
            log_info "Stack name mismatch - destruction cancelled"
            exit 0
        fi
        
        # Second confirmation
        echo -n "Type 'DESTROY' in uppercase to confirm: "
        read -r destroy_confirm
        if [[ "$destroy_confirm" != "DESTROY" ]]; then
            log_info "Confirmation failed - destruction cancelled"
            exit 0
        fi
        
        # Final countdown
        log_danger "Final countdown - Ctrl+C to cancel"
        for i in {5..1}; do
            echo -n "$i... "
            sleep 1
        done
        echo "EXECUTING DESTRUCTION!"
        echo ""
    elif [[ "$FORCE" != "true" ]]; then
        # Standard confirmation for non-prod
        echo -n "Type 'yes' to confirm destruction of $STACK ($ENV): "
        read -r confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Destruction cancelled"
            exit 0
        fi
    fi
}

# Execute destruction
execute_destruction() {
    log_danger "Executing infrastructure destruction..."
    
    cd "$STACK_DIR"
    
    local destroy_args=()
    
    if [[ -n "$TARGET" ]]; then
        destroy_args+=("-target=$TARGET")
    fi
    
    if [[ -f "terraform.tfvars" ]]; then
        destroy_args+=("-var-file=terraform.tfvars")
    fi
    
    destroy_args+=("-auto-approve")
    
    if terraform destroy "${destroy_args[@]}"; then
        log_success "Infrastructure destroyed successfully"
        
        # Clean up generated files
        rm -f destroy.tfplan
        rm -f terraform.tfplan
        rm -f .terraform.lock.hcl
        
        # Show final status
        echo ""
        log_success "Stack '$STACK' ($ENV) has been destroyed"
        
        if [[ "$BACKUP_STATE" == "true" ]]; then
            local backup_dir="$STACK_DIR/backups"
            if [[ -f "$backup_dir/pre_destroy_backup" ]]; then
                local backup_path=$(cat "$backup_dir/pre_destroy_backup")
                echo "💾 State backup available at: $backup_path"
            fi
        fi
        
    else
        log_error "Destruction failed"
        echo ""
        echo "Some resources may have been partially destroyed."
        echo "Check the Terraform state and AWS console for remaining resources."
        exit 1
    fi
}

# Main execution
main() {
    echo "💀 Infrastructure Destruction Tool"
    echo "=================================="
    echo "Stack: $STACK"
    echo "Environment: $ENV"
    
    if [[ -n "$TARGET" ]]; then
        echo "Target: $TARGET"
    fi
    
    echo ""
    
    # Handle list-only mode
    if [[ "$LIST_RESOURCES" == "true" ]]; then
        list_resources
        exit 0
    fi
    
    # Handle preview mode
    if [[ "$PREVIEW" == "true" ]]; then
        analyze_resources
        echo ""
        log_info "Preview mode - no resources were destroyed"
        exit 0
    fi
    
    # Full destruction workflow
    check_protected_resources
    analyze_resources
    backup_state
    production_confirmation
    execute_destruction
    
    log_success "Destruction completed! 💀"
}

# Handle cleanup on exit
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Destruction process failed"
        echo ""
        echo "Check the state and AWS console for any remaining resources."
        echo "You may need to manually clean up partially destroyed resources."
    fi
    
    # Clean up temporary files
    cd "$STACK_DIR" 2>/dev/null || true
    rm -f destroy.tfplan 2>/dev/null || true
    
    exit $exit_code
}

trap cleanup EXIT

# Run main function
main