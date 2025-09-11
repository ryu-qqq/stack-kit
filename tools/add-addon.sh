#!/bin/bash

# StackKit Addon Management Script
# Version: v1.0.0
# Purpose: Intelligently merge addons into existing project infrastructure

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKKIT_ROOT="$(dirname "$SCRIPT_DIR")"
ADDONS_DIR="$STACKKIT_ROOT/addons"
PROJECTS_DIR="$STACKKIT_ROOT/stackkit-terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
StackKit Addon Management Script v1.0.0

USAGE:
    $0 <command> [options]

COMMANDS:
    list                          List available addons
    info <addon>                  Show detailed information about an addon
    add <addon> <project>         Add addon to existing project
    remove <addon> <project>      Remove addon from project
    update <addon> <project>      Update addon in project
    validate <project>            Validate project addon configuration
    init <project>                Initialize project for addon support

ADDON CATEGORIES:
    storage/s3                    Enhanced S3 storage with advanced features
    monitoring/cloudwatch         Advanced CloudWatch monitoring
    monitoring/prometheus         Prometheus monitoring stack with Grafana

OPTIONS:
    -h, --help                   Show this help message
    -v, --verbose                Enable verbose logging
    -d, --debug                  Enable debug logging
    -f, --force                  Force operation without confirmation
    -c, --config <file>          Use custom configuration file
    --dry-run                    Show what would be done without executing
    --backup                     Create backup before making changes

EXAMPLES:
    # List all available addons
    $0 list

    # Add S3 enhanced storage to a project
    $0 add storage/s3 my-web-app

    # Add Prometheus monitoring with custom config
    $0 add monitoring/prometheus enterprise-api --config prometheus.yml

    # Remove CloudWatch monitoring from project
    $0 remove monitoring/cloudwatch my-web-app

    # Validate project configuration
    $0 validate my-web-app

For more information, visit: https://github.com/your-org/stackkit
EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    ADDON=""
    PROJECT=""
    VERBOSE=false
    DEBUG=false
    FORCE=false
    DRY_RUN=false
    BACKUP=false
    CONFIG_FILE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            list|info|add|remove|update|validate|init)
                COMMAND="$1"
                shift
                ;;
            *)
                if [[ -z "$ADDON" && "$COMMAND" != "list" && "$COMMAND" != "validate" && "$COMMAND" != "init" ]]; then
                    ADDON="$1"
                elif [[ -z "$PROJECT" ]]; then
                    PROJECT="$1"
                else
                    log_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    case "$COMMAND" in
        "")
            log_error "No command specified"
            show_help
            exit 1
            ;;
        info|add|remove|update)
            if [[ -z "$ADDON" ]]; then
                log_error "Addon name required for $COMMAND command"
                exit 1
            fi
            if [[ "$COMMAND" != "info" && -z "$PROJECT" ]]; then
                log_error "Project name required for $COMMAND command"
                exit 1
            fi
            ;;
        validate|init)
            if [[ -z "$PROJECT" ]]; then
                log_error "Project name required for $COMMAND command"
                exit 1
            fi
            ;;
    esac
}

# Check if addon exists
addon_exists() {
    local addon="$1"
    [[ -d "$ADDONS_DIR/$addon" ]]
}

# Check if project exists
project_exists() {
    local project="$1"
    [[ -d "$PROJECTS_DIR/compositions/$project" ]] || [[ -d "$PROJECTS_DIR/stacks/$project" ]]
}

# Get project directory
get_project_dir() {
    local project="$1"
    if [[ -d "$PROJECTS_DIR/compositions/$project" ]]; then
        echo "$PROJECTS_DIR/compositions/$project"
    elif [[ -d "$PROJECTS_DIR/stacks/$project" ]]; then
        echo "$PROJECTS_DIR/stacks/$project"
    else
        return 1
    fi
}

# List available addons
list_addons() {
    log_info "Available StackKit Addons:"
    echo ""
    
    # Storage addons
    echo -e "${CYAN}Storage Addons:${NC}"
    if [[ -d "$ADDONS_DIR/storage" ]]; then
        find "$ADDONS_DIR/storage" -type d -mindepth 1 -maxdepth 2 | while read -r addon_path; do
            addon_name=$(echo "$addon_path" | sed "s|$ADDONS_DIR/||")
            version=$(grep -E "^# Version:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3 || echo "unknown")
            description=$(grep -E "^# Purpose:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3- || echo "No description available")
            echo "  📦 $addon_name ($version) - $description"
        done
    fi
    echo ""
    
    # Monitoring addons
    echo -e "${CYAN}Monitoring Addons:${NC}"
    if [[ -d "$ADDONS_DIR/monitoring" ]]; then
        find "$ADDONS_DIR/monitoring" -type d -mindepth 1 -maxdepth 2 | while read -r addon_path; do
            addon_name=$(echo "$addon_path" | sed "s|$ADDONS_DIR/||")
            version=$(grep -E "^# Version:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3 || echo "unknown")
            description=$(grep -E "^# Purpose:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3- || echo "No description available")
            echo "  📊 $addon_name ($version) - $description"
        done
    fi
    echo ""
    
    log_info "Use '$0 info <addon>' for detailed information about an addon"
}

# Show addon information
show_addon_info() {
    local addon="$1"
    local addon_path="$ADDONS_DIR/$addon"
    
    if ! addon_exists "$addon"; then
        log_error "Addon '$addon' not found"
        exit 1
    fi
    
    log_info "Addon Information: $addon"
    echo ""
    
    # Extract metadata from main.tf
    if [[ -f "$addon_path/main.tf" ]]; then
        echo -e "${CYAN}Details:${NC}"
        version=$(grep -E "^# Version:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        purpose=$(grep -E "^# Purpose:" "$addon_path/main.tf" 2>/dev/null | cut -d' ' -f3- || echo "No description available")
        echo "  Version: $version"
        echo "  Purpose: $purpose"
        echo ""
    fi
    
    # Show files
    echo -e "${CYAN}Files:${NC}"
    find "$addon_path" -type f -name "*.tf" -o -name "*.md" | sort | while read -r file; do
        filename=$(basename "$file")
        case "$filename" in
            main.tf) echo "  📄 $filename - Main Terraform configuration" ;;
            variables.tf) echo "  🔧 $filename - Input variables and configuration" ;;
            outputs.tf) echo "  📤 $filename - Output values and integration points" ;;
            README.md) echo "  📚 $filename - Documentation and examples" ;;
            *) echo "  📄 $filename" ;;
        esac
    done
    echo ""
    
    # Show requirements
    if [[ -f "$addon_path/variables.tf" ]]; then
        echo -e "${CYAN}Required Variables:${NC}"
        grep -A 3 "variable \"" "$addon_path/variables.tf" | grep -E "variable \"|description" | \
        while read -r line; do
            if [[ "$line" =~ variable.*\" ]]; then
                var_name=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
                echo -n "  🔧 $var_name"
            elif [[ "$line" =~ description ]]; then
                desc=$(echo "$line" | cut -d'"' -f2)
                echo " - $desc"
            fi
        done
        echo ""
    fi
    
    # Show README if exists
    if [[ -f "$addon_path/README.md" ]]; then
        echo -e "${CYAN}Documentation:${NC}"
        echo "  📚 Full documentation available in $addon_path/README.md"
        echo ""
        
        # Extract quick start if available
        if grep -q "## Quick Start" "$addon_path/README.md" 2>/dev/null; then
            echo -e "${CYAN}Quick Start Example:${NC}"
            sed -n '/## Quick Start/,/##[^#]/p' "$addon_path/README.md" | head -20 | tail -n +2 | head -n -1
            echo "  ... (see README.md for complete examples)"
        fi
    fi
}

# Create backup of project
create_backup() {
    local project="$1"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    local backup_dir="$project_dir.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup at $backup_dir"
    cp -r "$project_dir" "$backup_dir"
    log_success "Backup created successfully"
}

# Check for conflicts
check_conflicts() {
    local addon="$1"
    local project="$2"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    log_debug "Checking for conflicts in $project_dir"
    
    # Check if addon is already integrated
    if grep -r "source.*addons/$addon" "$project_dir" 2>/dev/null; then
        log_warning "Addon '$addon' appears to already be integrated in project '$project'"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        fi
    fi
    
    # Check for resource naming conflicts
    local addon_resources
    addon_resources=$(grep -h "^resource " "$ADDONS_DIR/$addon"/*.tf 2>/dev/null | awk '{print $3}' | tr -d '"' || true)
    
    if [[ -n "$addon_resources" ]]; then
        log_debug "Checking for resource name conflicts"
        while IFS= read -r resource; do
            if grep -r "resource.*\"$resource\"" "$project_dir" 2>/dev/null; then
                log_warning "Resource name conflict detected: $resource"
            fi
        done <<< "$addon_resources"
    fi
}

# Generate addon integration code
generate_integration() {
    local addon="$1"
    local project="$2"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    local integration_file="$project_dir/addons-${addon//\//-}.tf"
    
    log_info "Generating integration code for $addon"
    
    # Read addon metadata
    local addon_path="$ADDONS_DIR/$addon"
    local module_name="${addon//\//_}"
    
    # Create integration file
    cat > "$integration_file" << EOF
# StackKit Addon Integration: $addon
# Generated by add-addon.sh on $(date)
# Version: v1.0.0

module "${module_name}_addon" {
  source = "../../../addons/$addon"

  # Project configuration
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags

EOF

    # Add environment-specific variables based on addon type
    case "$addon" in
        storage/s3)
            cat >> "$integration_file" << 'EOF'
  # S3 Enhanced Storage Configuration
  bucket_purpose              = "data"
  enable_enhanced_security    = true
  enable_intelligent_tiering  = var.environment == "prod"
  enable_detailed_monitoring  = var.environment == "prod"
  
  versioning_enabled     = true
  kms_key_alias         = "${var.project_name}-s3-key"
  block_public_access   = true
  
  # Environment-specific lifecycle rules
  lifecycle_rules = var.environment == "prod" ? [
    {
      id     = "production_lifecycle"
      status = "Enabled"
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      noncurrent_version_expiration = {
        days = 90
      }
    }
  ] : [
    {
      id     = "dev_lifecycle"
      status = "Enabled"
      expiration = {
        days = 7
      }
    }
  ]
EOF
            ;;
        monitoring/cloudwatch)
            cat >> "$integration_file" << 'EOF'
  # CloudWatch Enhanced Monitoring Configuration
  monitoring_level = var.environment == "prod" ? "comprehensive" : "enhanced"
  
  # Application log groups
  log_groups = {
    application = {
      name              = "/aws/${var.project_name}/${var.environment}/application"
      retention_in_days = var.environment == "prod" ? 90 : 30
      purpose           = "application"
    }
    access = {
      name              = "/aws/${var.project_name}/${var.environment}/access"
      retention_in_days = var.environment == "prod" ? 365 : 14
      purpose           = "access"
    }
  }
  
  # Basic application alarms
  metric_alarms = {
    high_error_rate = {
      alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      threshold          = 10
      alarm_description  = "High error rate detected"
      metric_name        = "Errors"
      namespace          = "AWS/Lambda"
      period             = 300
      statistic          = "Sum"
      alarm_actions      = [] # Add SNS topic ARNs here
      severity           = "high"
    }
  }
  
  # Alert channels
  alert_channels = {
    default = {
      subscriptions = {
        email = {
          protocol = "email"
          endpoint = "alerts@${var.project_name}.com"
        }
      }
    }
  }
EOF
            ;;
        monitoring/prometheus)
            cat >> "$integration_file" << 'EOF'
  # Prometheus Enhanced Monitoring Configuration
  vpc_id = var.vpc_id
  
  # Environment-specific sizing
  prometheus_cpu    = var.environment == "prod" ? 2048 : 1024
  prometheus_memory = var.environment == "prod" ? 4096 : 2048
  grafana_cpu      = var.environment == "prod" ? 1024 : 512
  grafana_memory   = var.environment == "prod" ? 2048 : 1024
  
  # Feature configuration
  enable_grafana            = true
  enable_alertmanager       = var.environment != "dev"
  enable_alb               = true
  enable_persistent_storage = var.environment != "dev"
  enable_ha                = var.environment == "prod"
  
  # Storage and retention
  prometheus_retention      = var.environment == "prod" ? "90d" : "30d"
  efs_provisioned_throughput = var.environment == "prod" ? 200 : 100
  log_retention_days       = var.environment == "prod" ? 90 : 30
  
  # Security configuration
  prometheus_public_access = false
  grafana_public_access   = var.environment != "prod"
  
  # Basic monitoring targets
  monitoring_targets = {
    # Add your application endpoints here
    # web_servers = {
    #   targets = ["app1.internal:9100", "app2.internal:9100"]
    #   labels = {
    #     job = "web-servers"
    #     env = var.environment
    #   }
    # }
  }
EOF
            ;;
    esac

    # Close the module block
    cat >> "$integration_file" << 'EOF'
}

# Outputs for integration with other modules
EOF

    # Add outputs based on addon type
    case "$addon" in
        storage/s3)
            cat >> "$integration_file" << 'EOF'
output "s3_addon_bucket_id" {
  description = "S3 bucket ID from addon"
  value       = module.s3_addon.bucket_id
}

output "s3_addon_bucket_arn" {
  description = "S3 bucket ARN from addon"
  value       = module.s3_addon.bucket_arn
}
EOF
            ;;
        monitoring/cloudwatch)
            cat >> "$integration_file" << 'EOF'
output "cloudwatch_addon_log_groups" {
  description = "CloudWatch log groups from addon"
  value       = module.cloudwatch_addon.log_group_names
}

output "cloudwatch_addon_sns_topics" {
  description = "SNS topic ARNs for alerts"
  value       = module.cloudwatch_addon.sns_topic_arns
}
EOF
            ;;
        monitoring/prometheus)
            cat >> "$integration_file" << 'EOF'
output "prometheus_addon_endpoints" {
  description = "Prometheus monitoring endpoints"
  value       = module.prometheus_addon.integration_endpoints
}

output "prometheus_addon_cluster" {
  description = "ECS cluster information"
  value = {
    name = module.prometheus_addon.ecs_cluster_name
    arn  = module.prometheus_addon.ecs_cluster_arn
  }
}
EOF
            ;;
    esac

    log_success "Integration code generated: $integration_file"
}

# Update project variables
update_project_variables() {
    local addon="$1"
    local project="$2"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    local variables_file="$project_dir/variables.tf"
    
    log_info "Updating project variables for $addon integration"
    
    # Check if variables file exists
    if [[ ! -f "$variables_file" ]]; then
        log_error "Variables file not found: $variables_file"
        return 1
    fi
    
    # Add addon-specific variables if they don't exist
    case "$addon" in
        storage/s3)
            if ! grep -q "variable \"s3_" "$variables_file" 2>/dev/null; then
                cat >> "$variables_file" << 'EOF'

# S3 Addon Variables
variable "s3_enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle management"
  type        = bool
  default     = true
}
EOF
            fi
            ;;
        monitoring/prometheus)
            if ! grep -q "variable \"vpc_id\"" "$variables_file" 2>/dev/null; then
                cat >> "$variables_file" << 'EOF'

# Prometheus Addon Variables
variable "vpc_id" {
  description = "VPC ID for Prometheus deployment"
  type        = string
}

variable "prometheus_enable_ha" {
  description = "Enable high availability for Prometheus"
  type        = bool
  default     = false
}
EOF
            fi
            ;;
    esac
}

# Add addon to project
add_addon() {
    local addon="$1"
    local project="$2"
    
    log_info "Adding addon '$addon' to project '$project'"
    
    # Validate inputs
    if ! addon_exists "$addon"; then
        log_error "Addon '$addon' not found"
        exit 1
    fi
    
    if ! project_exists "$project"; then
        log_error "Project '$project' not found"
        exit 1
    fi
    
    # Create backup if requested
    if [[ "$BACKUP" == "true" ]]; then
        create_backup "$project"
    fi
    
    # Check for conflicts
    check_conflicts "$addon" "$project"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would add addon '$addon' to project '$project'"
        log_info "DRY RUN: Would generate integration file"
        log_info "DRY RUN: Would update project variables"
        return 0
    fi
    
    # Generate integration
    generate_integration "$addon" "$project"
    
    # Update project variables
    update_project_variables "$addon" "$project"
    
    log_success "Addon '$addon' successfully added to project '$project'"
    log_info "Next steps:"
    log_info "1. Review the generated integration file"
    log_info "2. Update variables with your specific configuration"
    log_info "3. Run 'terraform plan' to review changes"
    log_info "4. Run 'terraform apply' to deploy the addon"
}

# Remove addon from project
remove_addon() {
    local addon="$1"
    local project="$2"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    log_info "Removing addon '$addon' from project '$project'"
    
    if ! project_exists "$project"; then
        log_error "Project '$project' not found"
        exit 1
    fi
    
    # Find integration file
    local integration_file="$project_dir/addons-${addon//\//-}.tf"
    
    if [[ ! -f "$integration_file" ]]; then
        log_error "Integration file not found: $integration_file"
        log_error "Addon '$addon' may not be integrated in project '$project'"
        exit 1
    fi
    
    # Create backup if requested
    if [[ "$BACKUP" == "true" ]]; then
        create_backup "$project"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would remove integration file: $integration_file"
        return 0
    fi
    
    # Confirm removal
    if [[ "$FORCE" != "true" ]]; then
        log_warning "This will remove the addon integration from your project."
        log_warning "Make sure to run 'terraform destroy' for addon resources first!"
        read -p "Continue with removal? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Remove integration file
    rm "$integration_file"
    
    log_success "Addon '$addon' integration removed from project '$project'"
    log_warning "Remember to run 'terraform destroy' to remove addon resources!"
}

# Validate project addon configuration
validate_project() {
    local project="$1"
    local project_dir
    project_dir=$(get_project_dir "$project")
    
    log_info "Validating addon configuration for project '$project'"
    
    if ! project_exists "$project"; then
        log_error "Project '$project' not found"
        exit 1
    fi
    
    local errors=0
    local warnings=0
    
    # Find addon integration files
    local addon_files
    addon_files=$(find "$project_dir" -name "addons-*.tf" 2>/dev/null || true)
    
    if [[ -z "$addon_files" ]]; then
        log_info "No addon integrations found in project '$project'"
        return 0
    fi
    
    log_info "Found addon integration files:"
    while IFS= read -r file; do
        local filename
        filename=$(basename "$file")
        echo "  📄 $filename"
        
        # Basic syntax validation
        if ! terraform validate -check-variables=false "$project_dir" >/dev/null 2>&1; then
            log_error "Terraform syntax validation failed for $file"
            ((errors++))
        fi
        
        # Check for required variables
        local module_source
        module_source=$(grep "source.*addons" "$file" | head -1 | cut -d'"' -f2)
        if [[ -n "$module_source" ]]; then
            local addon_path="$STACKKIT_ROOT/$module_source"
            if [[ -f "$addon_path/variables.tf" ]]; then
                # Check if all required variables are provided
                local required_vars
                required_vars=$(grep -A 5 "variable.*{" "$addon_path/variables.tf" | grep -B 5 "type.*=" | grep "variable" | grep -o '"[^"]*"' | tr -d '"' || true)
                
                while IFS= read -r var_name; do
                    if [[ -n "$var_name" ]] && ! grep -q "$var_name" "$file"; then
                        log_warning "Variable '$var_name' not configured in $filename"
                        ((warnings++))
                    fi
                done <<< "$required_vars"
            fi
        fi
        
    done <<< "$addon_files"
    
    echo ""
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log_success "All addon configurations are valid"
    else
        log_info "Validation completed with $errors errors and $warnings warnings"
        if [[ $errors -gt 0 ]]; then
            exit 1
        fi
    fi
}

# Initialize project for addon support
init_project() {
    local project="$1"
    local project_dir
    
    if ! project_exists "$project"; then
        log_error "Project '$project' not found"
        exit 1
    fi
    
    project_dir=$(get_project_dir "$project")
    
    log_info "Initializing project '$project' for addon support"
    
    # Check if already initialized
    if [[ -f "$project_dir/.stackkit-addons" ]]; then
        log_warning "Project already initialized for addons"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would initialize project for addon support"
        return 0
    fi
    
    # Create addon marker file
    cat > "$project_dir/.stackkit-addons" << EOF
# StackKit Addons Configuration
# Generated on $(date)
project_name = "$project"
addons_enabled = true
EOF
    
    # Ensure variables.tf has basic addon variables
    local variables_file="$project_dir/variables.tf"
    if [[ -f "$variables_file" ]] && ! grep -q "common_tags" "$variables_file"; then
        cat >> "$variables_file" << 'EOF'

# StackKit Addon Common Variables
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
EOF
    fi
    
    log_success "Project '$project' initialized for addon support"
    log_info "You can now add addons using: $0 add <addon> $project"
}

# Main function
main() {
    parse_args "$@"
    
    log_debug "Command: $COMMAND"
    log_debug "Addon: $ADDON"
    log_debug "Project: $PROJECT"
    log_debug "StackKit Root: $STACKKIT_ROOT"
    
    case "$COMMAND" in
        list)
            list_addons
            ;;
        info)
            show_addon_info "$ADDON"
            ;;
        add)
            add_addon "$ADDON" "$PROJECT"
            ;;
        remove)
            remove_addon "$ADDON" "$PROJECT"
            ;;
        validate)
            validate_project "$PROJECT"
            ;;
        init)
            init_project "$PROJECT"
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"