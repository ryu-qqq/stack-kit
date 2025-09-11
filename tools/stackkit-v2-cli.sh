#!/bin/bash
set -euo pipefail

# 🚀 StackKit v2 CLI - Next Generation Infrastructure Tool
# Terraform 모범 사례를 따르는 새로운 아키텍처 지원

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
STACKKIT_MODULES_REPO="https://github.com/company/stackkit-terraform-modules.git"
STACKKIT_TEMPLATES_REPO="https://github.com/company/stackkit-templates.git"
DEFAULT_REGION="ap-northeast-2"
DEFAULT_ENVIRONMENTS="dev,staging,prod"

show_help() {
    cat << EOF
🚀 StackKit v2 CLI - Next Generation Infrastructure Tool

Usage: $0 <command> [options]

Commands:
    new         Create new project from template
    init        Initialize existing project for StackKit v2
    update      Update modules to latest versions
    migrate     Migrate legacy project to v2 architecture
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

    # Check if GitHub CLI is available for template cloning
    if command -v gh &> /dev/null; then
        log_info "Using GitHub CLI to create from template..."
        gh repo create "$project_name-infrastructure" \
            --template "$STACKKIT_TEMPLATES_REPO/$template" \
            --clone \
            --private
        
        cd "$project_name-infrastructure"
    else
        log_warning "GitHub CLI not found. Cloning template manually..."
        git clone "$STACKKIT_TEMPLATES_REPO" temp-templates
        cp -r "temp-templates/$template" "$output_dir"
        rm -rf temp-templates
        cd "$output_dir"
        git init
    fi

    # Customize template with project values
    log_info "Customizing template for your project..."
    
    # Replace placeholder values in all .tf and .tfvars files
    find . -name "*.tf" -o -name "*.tfvars" -o -name "*.md" | xargs sed -i.bak \
        -e "s/PROJECT_NAME_PLACEHOLDER/$project_name/g" \
        -e "s/TEAM_NAME_PLACEHOLDER/$team/g" \
        -e "s/ORG_NAME_PLACEHOLDER/$org/g" \
        -e "s/REGION_PLACEHOLDER/$region/g"

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

# Migrate legacy project
cmd_migrate() {
    log_header "Migrating legacy project to StackKit v2"
    log_warning "This feature is under development"
    log_info "For now, please use the migration guide at:"
    log_info "https://github.com/company/stackkit-terraform-modules/blob/main/docs/MIGRATION_GUIDE.md"
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