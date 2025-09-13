#!/bin/bash
set -euo pipefail

# 🚀 StackKit CLI - Infrastructure Automation Tool
# Terraform 모범 사례를 따르는 인프라 자동화 도구

# Colors
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
log_header() { echo -e "${PURPLE}🚀 $1${NC}"; }

# Default values
STACKKIT_MODULES_REPO="https://github.com/stackkit/stackkit-terraform-modules.git"
STACKKIT_TEMPLATES_REPO="https://github.com/stackkit/stackkit-templates.git"
DEFAULT_REGION="ap-northeast-2"
DEFAULT_ENVIRONMENTS="dev,staging,prod"

show_help() {
    cat << EOF
🚀 StackKit CLI - Infrastructure Automation Tool

Usage: $0 <command> [options]

Commands:
    new         Create new project from template
    init        Initialize existing project for StackKit
    update      Update modules to latest versions
    addon       Manage project addons
    validate    Validate project configuration
    deploy      Deploy infrastructure to environment
    status      Show infrastructure status
    cost        Analyze infrastructure costs
    modules     Manage modules and versions
    templates   Manage project templates

Examples:
    # Create new API service project
    $0 new --template api-service --name my-api --team backend

    # Update all modules to latest versions
    $0 update --modules all

    # Deploy to development environment
    $0 deploy --env dev --auto-approve

    # Check infrastructure costs
    $0 cost --env prod --forecast 30d

Run '$0 <command> --help' for command-specific help.
EOF
}

# Module version management
get_latest_module_version() {
    local module_path="$1"
    git ls-remote --tags "$STACKKIT_MODULES_REPO" | \
        grep "refs/tags/${module_path}/" | \
        sed 's/.*\///g' | \
        sort -V | \
        tail -1
}

# Project templates management
list_available_templates() {
    log_info "Available project templates:"
    cat << EOF
    📱 api-service          - REST API microservice
    🌐 web-application      - Full-stack web application  
    ⚡ serverless-function  - AWS Lambda functions
    🔄 data-pipeline        - ETL/data processing pipeline
    🏗️  microservice        - Microservice platform
    📊 analytics-platform   - Data analytics infrastructure
    🔐 security-baseline    - Security-focused foundation
    🔄 gitops-atlantis      - GitOps with Atlantis on ECS
EOF
}

# Create new project from template
cmd_new() {
    local template=""
    local project_name=""
    local team=""
    local org=""
    local region="$DEFAULT_REGION"
    local environments="$DEFAULT_ENVIRONMENTS"
    local output_dir=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --template)
                template="$2"
                shift 2
                ;;
            --name)
                project_name="$2"
                shift 2
                ;;
            --team)
                team="$2"
                shift 2
                ;;
            --org)
                org="$2"
                shift 2
                ;;
            --region)
                region="$2"
                shift 2
                ;;
            --environments)
                environments="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Create new project from template

Usage: $0 new --template TEMPLATE --name PROJECT_NAME --team TEAM --org ORG [options]

Required:
    --template TEMPLATE     Template name (see: $0 templates list)
    --name PROJECT_NAME     Project name
    --team TEAM             Team name
    --org ORG              Organization name

Optional:
    --region REGION         AWS region (default: $DEFAULT_REGION)
    --environments ENVS     Environments (default: $DEFAULT_ENVIRONMENTS)
    --output-dir DIR        Output directory (default: ./PROJECT_NAME-infrastructure)

Examples:
    $0 new --template api-service --name user-api --team backend --org mycompany
    $0 new --template web-application --name dashboard --team frontend --org acme
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    # Validation
    [[ -z "$template" ]] && log_error "Template is required (--template)"
    [[ -z "$project_name" ]] && log_error "Project name is required (--name)"
    [[ -z "$team" ]] && log_error "Team name is required (--team)"
    [[ -z "$org" ]] && log_error "Organization is required (--org)"

    # Set default output directory
    [[ -z "$output_dir" ]] && output_dir="./${project_name}-infrastructure"

    log_header "Creating new project: $project_name"
    log_info "Template: $template"
    log_info "Team: $team"
    log_info "Organization: $org"
    log_info "Output directory: $output_dir"

    # Check for local templates first
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

    if [[ -d "$TEMPLATES_DIR/$template" ]]; then
        log_info "Using local template: $template"
        mkdir -p "$output_dir"
        cp -r "$TEMPLATES_DIR/$template/"* "$output_dir/"
        # Copy hidden files as well
        cp -r "$TEMPLATES_DIR/$template/".* "$output_dir/" 2>/dev/null || true
        cd "$output_dir"
        git init
        log_success "Template copied successfully"
    else
        log_error "Template '$template' not found in $TEMPLATES_DIR. Available templates:"
        if [[ -d "$TEMPLATES_DIR" ]]; then
            ls -1 "$TEMPLATES_DIR" | sed 's/^/  - /'
        else
            log_error "Templates directory not found: $TEMPLATES_DIR"
        fi
    fi

    # Customize template with project values
    log_info "Customizing template for your project..."
    
    # Replace placeholder values in all relevant files
    find . \( -name "*.tf" -o -name "*.tfvars" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) | while read file; do
        sed -i.bak \
            -e "s/PROJECT_NAME_PLACEHOLDER/$project_name/g" \
            -e "s/TEAM_NAME_PLACEHOLDER/$team/g" \
            -e "s/ORG_NAME_PLACEHOLDER/$org/g" \
            -e "s/REGION_PLACEHOLDER/$region/g" \
            -e "s/TERRAFORM_STATE_BUCKET_PLACEHOLDER/${org}-terraform-state/g" \
            -e "s/your-company/$org/g" \
            -e "s/your-org/$org/g" \
            -e "s/your-domain/${org}/g" \
            "$file"
    done

    # Remove backup files
    find . -name "*.bak" -delete

    # Setup environment-specific configurations
    IFS=',' read -ra ENV_ARRAY <<< "$environments"
    for env in "${ENV_ARRAY[@]}"; do
        log_info "Setting up environment: $env"
        if [[ -d "environments/$env" ]]; then
            # Create environment-specific tfvars
            cat > "environments/$env/terraform.tfvars" << EOF
# Environment: $env
# Project: $project_name
# Team: $team

project_name = "$project_name"
environment  = "$env"
aws_region   = "$region"
team         = "$team"
organization = "$org"

# Environment-specific settings
# Customize these values for $env environment
EOF
        fi
    done

    # Generate initial README
    cat > README.md << EOF
# $project_name Infrastructure

Infrastructure as Code for the $project_name project using StackKit v2.

## Project Information
- **Team**: $team
- **Organization**: $org
- **Template**: $template
- **Environments**: $environments

## Quick Start

\`\`\`bash
# Validate configuration
stackkit validate

# Deploy to development
stackkit deploy --env dev

# Check costs
stackkit cost --env dev
\`\`\`

## Directory Structure

\`\`\`
.
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/              # Project-specific local modules
├── .github/workflows/    # CI/CD pipelines
└── scripts/             # Helper scripts
\`\`\`

## Documentation

- [StackKit v2 Documentation](https://github.com/company/stackkit-terraform-modules)
- [Team Runbook](./docs/runbook.md)
- [Architecture Decision Records](./docs/adr/)

Generated by StackKit v2 CLI
EOF

    log_success "Project created successfully!"
    log_info "Next steps:"
    echo "  1. cd $output_dir"
    echo "  2. Review and customize terraform.tfvars files"
    echo "  3. Run: stackkit validate"
    echo "  4. Run: stackkit deploy --env dev"
}

# Update modules to latest versions
cmd_update() {
    local target="all"
    local dry_run=false
    local version=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --modules)
                target="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                cat << EOF
Update modules to latest versions

Usage: $0 update [options]

Options:
    --modules TARGET        Target modules (all, networking, compute, etc.)
    --version VERSION       Specific version to update to
    --dry-run              Show what would be updated without making changes

Examples:
    $0 update --modules all
    $0 update --modules networking --version v2.0.0
    $0 update --dry-run
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    log_header "Updating modules"

    # Find all Terraform files with module references
    log_info "Scanning for module references..."
    module_files=$(find . -name "*.tf" -exec grep -l "source.*stackkit-terraform-modules" {} \;)

    if [[ -z "$module_files" ]]; then
        log_warning "No StackKit modules found in current directory"
        return 0
    fi

    # Process each file
    for file in $module_files; do
        log_info "Processing: $file"
        
        # Extract module references
        while IFS= read -r line; do
            if [[ $line =~ source.*stackkit-terraform-modules.*//([^?]*)\?ref=([^\"]*) ]]; then
                module_path="${BASH_REMATCH[1]}"
                current_version="${BASH_REMATCH[2]}"
                
                # Get latest version if not specified
                if [[ -z "$version" ]]; then
                    latest_version=$(get_latest_module_version "$module_path")
                else
                    latest_version="$version"
                fi

                if [[ "$current_version" != "$latest_version" ]]; then
                    log_info "  $module_path: $current_version → $latest_version"
                    
                    if [[ "$dry_run" == false ]]; then
                        sed -i.bak "s|${module_path}?ref=${current_version}|${module_path}?ref=${latest_version}|g" "$file"
                    fi
                else
                    log_info "  $module_path: up to date ($current_version)"
                fi
            fi
        done < <(grep "source.*stackkit-terraform-modules" "$file")
    done

    if [[ "$dry_run" == false ]]; then
        # Clean up backup files
        find . -name "*.tf.bak" -delete
        log_success "Modules updated successfully!"
        log_info "Run 'terraform init -upgrade' to download new module versions"
    else
        log_info "Dry run completed. Use without --dry-run to apply changes."
    fi
}

# Validate project configuration
cmd_validate() {
    log_header "Validating project configuration"

    # Check for required tools
    local missing_tools=()
    for tool in terraform tflint tfsec; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
    fi

    # Terraform format check
    log_info "Checking Terraform format..."
    if terraform fmt -check -recursive >/dev/null 2>&1; then
        log_success "Terraform format: OK"
    else
        log_warning "Terraform format: Issues found"
        terraform fmt -recursive
        log_info "Format issues fixed automatically"
    fi

    # Terraform validation
    log_info "Validating Terraform syntax..."
    for env_dir in environments/*/; do
        if [[ -d "$env_dir" ]]; then
            env_name=$(basename "$env_dir")
            log_info "Validating environment: $env_name"
            
            cd "$env_dir"
            terraform init -backend=false >/dev/null 2>&1
            if terraform validate >/dev/null 2>&1; then
                log_success "  Syntax: OK"
            else
                log_error "  Syntax validation failed in $env_name"
            fi
            cd - >/dev/null
        fi
    done

    # Security scan
    if command -v tfsec &> /dev/null; then
        log_info "Running security scan..."
        if tfsec --soft-fail . >/dev/null 2>&1; then
            log_success "Security scan: OK"
        else
            log_warning "Security issues found. Run 'tfsec .' for details"
        fi
    fi

    # Cost validation (if infracost is available)
    if command -v infracost &> /dev/null; then
        log_info "Analyzing costs..."
        if infracost breakdown --path . --format table >/dev/null 2>&1; then
            log_success "Cost analysis: Completed"
        else
            log_warning "Cost analysis: Could not complete"
        fi
    fi

    log_success "Validation completed!"
}

# Deploy infrastructure
cmd_deploy() {
    local environment=""
    local auto_approve=false
    local plan_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                environment="$2"
                shift 2
                ;;
            --auto-approve)
                auto_approve=true
                shift
                ;;
            --plan-only)
                plan_only=true
                shift
                ;;
            --help)
                cat << EOF
Deploy infrastructure to environment

Usage: $0 deploy --env ENVIRONMENT [options]

Required:
    --env ENVIRONMENT       Target environment (dev, staging, prod)

Options:
    --auto-approve         Skip confirmation prompt
    --plan-only           Only generate and show plan

Examples:
    $0 deploy --env dev
    $0 deploy --env prod --plan-only
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    [[ -z "$environment" ]] && log_error "Environment is required (--env)"

    local env_dir="environments/$environment"
    [[ ! -d "$env_dir" ]] && log_error "Environment directory not found: $env_dir"

    log_header "Deploying to environment: $environment"

    cd "$env_dir"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init

    # Generate plan
    log_info "Generating deployment plan..."
    terraform plan -out=tfplan

    if [[ "$plan_only" == true ]]; then
        log_success "Plan generated successfully. Review above."
        return 0
    fi

    # Apply changes
    if [[ "$auto_approve" == true ]]; then
        log_info "Applying changes automatically..."
        terraform apply tfplan
    else
        echo
        read -p "Do you want to apply these changes? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            terraform apply tfplan
        else
            log_info "Deployment cancelled"
            return 0
        fi
    fi

    log_success "Deployment completed successfully!"
}

# Show infrastructure status
cmd_status() {
    local environment=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                environment="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Show infrastructure status

Usage: $0 status [options]

Options:
    --env ENVIRONMENT       Show status for specific environment

Examples:
    $0 status
    $0 status --env prod
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    log_header "Infrastructure Status"

    if [[ -n "$environment" ]]; then
        local env_dir="environments/$environment"
        [[ ! -d "$env_dir" ]] && log_error "Environment directory not found: $env_dir"
        
        log_info "Environment: $environment"
        cd "$env_dir"
        terraform show -json | jq -r '.values.root_module.resources[].type' | sort | uniq -c
    else
        # Show status for all environments
        for env_dir in environments/*/; do
            if [[ -d "$env_dir" ]]; then
                env_name=$(basename "$env_dir")
                log_info "Environment: $env_name"
                cd "$env_dir"
                if [[ -f "terraform.tfstate" ]]; then
                    terraform show -json | jq -r '.values.root_module.resources[].type' | sort | uniq -c
                else
                    echo "  No state file found"
                fi
                cd - >/dev/null
                echo
            fi
        done
    fi
}

# Analyze costs
cmd_cost() {
    local environment=""
    local forecast=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                environment="$2"
                shift 2
                ;;
            --forecast)
                forecast="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Analyze infrastructure costs

Usage: $0 cost [options]

Options:
    --env ENVIRONMENT       Analyze costs for specific environment
    --forecast PERIOD       Forecast period (30d, 12m, etc.)

Examples:
    $0 cost --env prod
    $0 cost --env dev --forecast 30d
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    if ! command -v infracost &> /dev/null; then
        log_error "infracost is required for cost analysis. Install from: https://www.infracost.io/docs/"
    fi

    log_header "Cost Analysis"

    if [[ -n "$environment" ]]; then
        local env_dir="environments/$environment"
        [[ ! -d "$env_dir" ]] && log_error "Environment directory not found: $env_dir"
        
        log_info "Analyzing costs for: $environment"
        cd "$env_dir"
        
        if [[ -n "$forecast" ]]; then
            infracost breakdown --path . --show-skipped
        else
            infracost breakdown --path . --format table
        fi
    else
        # Analyze all environments
        for env_dir in environments/*/; do
            if [[ -d "$env_dir" ]]; then
                env_name=$(basename "$env_dir")
                log_info "Environment: $env_name"
                cd "$env_dir"
                infracost breakdown --path . --format table
                cd - >/dev/null
                echo
            fi
        done
    fi
}

# Manage modules
cmd_modules() {
    local action="$1"
    shift

    case "$action" in
        list)
            log_header "Available StackKit Modules"
            log_info "Foundation Tier (Basic modules):"
            echo "  📡 networking/vpc - Virtual Private Cloud"
            echo "  📡 networking/alb - Application Load Balancer"
            echo "  💻 compute/ec2 - EC2 instances"
            echo "  💻 compute/ecs - Container services"
            echo "  💻 compute/lambda - Serverless functions"
            echo "  🗄️  database/rds - Relational databases"
            echo "  🗄️  database/dynamodb - NoSQL databases"
            echo "  🔒 security/iam - Identity and Access Management"
            echo
            log_info "Enterprise Tier (Advanced features):"
            echo "  🏢 multi-tenant - Multi-tenant isolation"
            echo "  📋 compliance - Compliance automation"
            echo "  💰 cost-optimization - Cost management"
            echo
            log_info "Community Tier (Integrations):"
            echo "  🔗 integrations/* - Third-party integrations"
            ;;
        versions)
            local module_name="${1:-}"
            if [[ -n "$module_name" ]]; then
                log_info "Available versions for $module_name:"
                git ls-remote --tags "$STACKKIT_MODULES_REPO" | grep "$module_name" | tail -10
            else
                log_info "Module versions in current project:"
                grep -r "stackkit-terraform-modules.*?ref=" . | grep -o "ref=[^\"]*" | sort | uniq
            fi
            ;;
        *)
            cat << EOF
Manage modules and versions

Usage: $0 modules <action>

Actions:
    list        List available modules
    versions    Show module versions

Examples:
    $0 modules list
    $0 modules versions networking/vpc
EOF
            ;;
    esac
}

# Manage templates
cmd_templates() {
    local action="$1"
    shift

    case "$action" in
        list)
            list_available_templates
            ;;
        *)
            cat << EOF
Manage project templates

Usage: $0 templates <action>

Actions:
    list        List available templates

Examples:
    $0 templates list
EOF
            ;;
    esac
}

# Manage addons
cmd_addon() {
    local action="$1"
    shift

    case "$action" in
        add)
            cmd_addon_add "$@"
            ;;
        remove)
            cmd_addon_remove "$@"
            ;;
        list)
            cmd_addon_list "$@"
            ;;
        *)
            cat << EOF
Manage project addons

Usage: $0 addon <action> [options]

Actions:
    add ADDON_PATH [PROJECT]     Add addon to project
    remove ADDON_NAME [PROJECT]  Remove addon from project
    list [PROJECT]               List available or installed addons

Examples:
    $0 addon add database/mysql-rds my-project
    $0 addon list
    $0 addon remove mysql-rds my-project
EOF
            ;;
    esac
}

# Add addon to project
cmd_addon_add() {
    local addon_path=""
    local project_dir="."

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                cat << EOF
Add addon to project

Usage: $0 addon add ADDON_PATH [PROJECT_DIR]

Arguments:
    ADDON_PATH      Path to addon (e.g., database/mysql-rds)
    PROJECT_DIR     Target project directory (default: current directory)

Examples:
    $0 addon add database/mysql-rds
    $0 addon add messaging/sqs ./my-project
EOF
                return 0
                ;;
            *)
                if [[ -z "$addon_path" ]]; then
                    addon_path="$1"
                else
                    project_dir="$1"
                fi
                shift
                ;;
        esac
    done

    [[ -z "$addon_path" ]] && log_error "Addon path is required"

    log_header "Adding addon: $addon_path"

    # Find addon directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ADDONS_DIR="$(dirname "$SCRIPT_DIR")/addons"

    if [[ ! -d "$ADDONS_DIR/$addon_path" ]]; then
        log_error "Addon not found: $ADDONS_DIR/$addon_path"
        log_info "Available addons:"
        find "$ADDONS_DIR" -maxdepth 2 -type d -name "*" | grep -v "^$ADDONS_DIR$" | sed "s|$ADDONS_DIR/||" | sort
        return 1
    fi

    # Check if project directory exists and has terraform files
    if [[ ! -d "$project_dir" ]]; then
        log_error "Project directory not found: $project_dir"
    fi

    if [[ ! -f "$project_dir/main.tf" ]] && [[ ! -f "$project_dir/variables.tf" ]]; then
        log_warning "No Terraform files found in $project_dir. This might not be a StackKit project."
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]] && return 0
    fi

    cd "$project_dir"

    # Copy addon files
    log_info "Copying addon files..."
    addon_name=$(basename "$addon_path")

    # Create addon-specific directory
    mkdir -p "addons/$addon_name"
    cp -r "$ADDONS_DIR/$addon_path/"* "addons/$addon_name/"

    # Update main.tf to include the addon module
    log_info "Updating main.tf to include addon..."

    cat >> main.tf << EOF

# ======================================
# Addon: $addon_name
# ======================================
module "$addon_name" {
  source = "./addons/$addon_name"

  # Project metadata
  project_name = var.project_name
  environment  = var.environment
  team         = var.team
  organization = var.organization

  # Basic configuration - customize as needed
  # Add specific variables for this addon here
}
EOF

    # Copy variables if they exist
    if [[ -f "$ADDONS_DIR/$addon_path/variables.tf" ]]; then
        log_info "Adding addon variables..."
        echo "" >> variables.tf
        echo "# ======================================" >> variables.tf
        echo "# Addon Variables: $addon_name" >> variables.tf
        echo "# ======================================" >> variables.tf
        cat "$ADDONS_DIR/$addon_path/variables.tf" >> variables.tf
    fi

    # Add outputs if they exist
    if [[ -f "$ADDONS_DIR/$addon_path/outputs.tf" ]]; then
        log_info "Adding addon outputs..."
        echo "" >> outputs.tf
        echo "# ======================================" >> outputs.tf
        echo "# Addon Outputs: $addon_name" >> outputs.tf
        echo "# ======================================" >> outputs.tf
        cat "$ADDONS_DIR/$addon_path/outputs.tf" >> outputs.tf
    fi

    log_success "Addon '$addon_name' added successfully!"
    log_info "Next steps:"
    echo "  1. Review and customize the addon configuration in main.tf"
    echo "  2. Update terraform.tfvars with addon-specific variables"
    echo "  3. Run: terraform init"
    echo "  4. Run: terraform plan"
}

# Remove addon from project
cmd_addon_remove() {
    local addon_name=""
    local project_dir="."

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                cat << EOF
Remove addon from project

Usage: $0 addon remove ADDON_NAME [PROJECT_DIR]

Arguments:
    ADDON_NAME      Name of addon to remove
    PROJECT_DIR     Target project directory (default: current directory)

Examples:
    $0 addon remove mysql-rds
    $0 addon remove sqs ./my-project
EOF
                return 0
                ;;
            *)
                if [[ -z "$addon_name" ]]; then
                    addon_name="$1"
                else
                    project_dir="$1"
                fi
                shift
                ;;
        esac
    done

    [[ -z "$addon_name" ]] && log_error "Addon name is required"

    log_header "Removing addon: $addon_name"

    cd "$project_dir"

    # Check if addon exists
    if [[ ! -d "addons/$addon_name" ]]; then
        log_error "Addon not found in project: $addon_name"
        return 1
    fi

    log_warning "This will remove the addon and its configuration. Continue? (y/N)"
    read -p "> " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        log_info "Removal cancelled"
        return 0
    fi

    # Remove addon directory
    rm -rf "addons/$addon_name"

    # Remove module reference from main.tf (basic approach)
    if grep -q "module \"$addon_name\"" main.tf; then
        log_info "Removing module reference from main.tf..."
        # Create backup
        cp main.tf main.tf.backup
        # Remove the module block (this is a simple approach - could be improved)
        log_warning "Module reference found in main.tf. Please manually remove the module block for '$addon_name'"
        log_info "Backup created: main.tf.backup"
    fi

    log_success "Addon '$addon_name' removed successfully!"
    log_info "You may need to manually clean up variables and outputs related to this addon"
}

# List available or installed addons
cmd_addon_list() {
    local project_dir="."

    if [[ $# -gt 0 ]] && [[ "$1" != "--help" ]]; then
        project_dir="$1"
    fi

    if [[ $# -gt 0 ]] && [[ "$1" == "--help" ]]; then
        cat << EOF
List available or installed addons

Usage: $0 addon list [PROJECT_DIR]

Arguments:
    PROJECT_DIR     Project directory to check (default: current directory)

Examples:
    $0 addon list
    $0 addon list ./my-project
EOF
        return 0
    fi

    log_header "StackKit Addons"

    # Show available addons
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ADDONS_DIR="$(dirname "$SCRIPT_DIR")/addons"

    if [[ -d "$ADDONS_DIR" ]]; then
        log_info "Available addons:"
        find "$ADDONS_DIR" -maxdepth 2 -type d -name "*" | grep -v "^$ADDONS_DIR$" | while read addon_dir; do
            addon_path=$(echo "$addon_dir" | sed "s|$ADDONS_DIR/||")
            if [[ -f "$addon_dir/README.md" ]]; then
                description=$(head -n 3 "$addon_dir/README.md" | tail -n 1 | sed 's/^# *//')
                echo "  📦 $addon_path - $description"
            else
                echo "  📦 $addon_path"
            fi
        done
    else
        log_warning "Addons directory not found: $ADDONS_DIR"
    fi

    # Show installed addons if in a project
    if [[ -d "$project_dir/addons" ]]; then
        echo
        log_info "Installed addons in $project_dir:"
        for addon_dir in "$project_dir/addons"/*; do
            if [[ -d "$addon_dir" ]]; then
                addon_name=$(basename "$addon_dir")
                echo "  ✅ $addon_name"
            fi
        done
    fi
}

# Migrate legacy project
cmd_migrate() {
    log_header "Migrating legacy project to StackKit v2"
    log_warning "This feature is under development"
    log_info "For now, please use the migration guide at:"
    log_info "https://github.com/stackkit/stackkit-terraform-modules/blob/main/docs/MIGRATION_GUIDE.md"
}

# Main command dispatcher
main() {
    [[ $# -eq 0 ]] && { show_help; exit 1; }

    local command="$1"
    shift

    case "$command" in
        new)
            cmd_new "$@"
            ;;
        init)
            log_info "init command is under development"
            ;;
        update)
            cmd_update "$@"
            ;;
        addon)
            cmd_addon "$@"
            ;;
        migrate)
            cmd_migrate "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        deploy)
            cmd_deploy "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        cost)
            cmd_cost "$@"
            ;;
        modules)
            cmd_modules "$@"
            ;;
        templates)
            cmd_templates "$@"
            ;;
        --help|-h|help)
            show_help
            ;;
        --version|-v)
            echo "StackKit CLI v2.0.0"
            ;;
        *)
            log_error "Unknown command: $command. Run '$0 --help' for usage."
            ;;
    esac
}

main "$@"