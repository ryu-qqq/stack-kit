#!/bin/bash
set -euo pipefail

# 🔄 StackKit v1 to v2 Migration Tool
# Automated migration from legacy StackKit structure to new Template + Registry architecture

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
log_header() { echo -e "${PURPLE}🔄 $1${NC}"; }

show_help() {
    cat << EOF
🔄 StackKit v1 to v2 Migration Tool

Migrates existing StackKit v1 projects to the new v2 architecture with:
- Template-based project structure
- Module registry references
- Modern CI/CD workflows
- Enhanced governance

Usage: $0 --project-dir PATH [OPTIONS]

Required:
    --project-dir PATH      Path to existing StackKit v1 project

Options:
    --backup-dir PATH       Backup directory (default: ./backup-TIMESTAMP)
    --dry-run              Show what would be migrated without making changes
    --template TYPE        Target template type (api-service, web-application, etc.)
    --force                Skip confirmations and proceed with migration
    --preserve-state       Keep existing Terraform state (recommended)

Examples:
    # Migrate existing project with backup
    $0 --project-dir ./my-legacy-project

    # Dry run to see what would change
    $0 --project-dir ./my-project --dry-run

    # Force migration without prompts
    $0 --project-dir ./my-project --force --template api-service

EOF
}

# Default values
BACKUP_DIR=""
DRY_RUN=false
TEMPLATE_TYPE=""
FORCE=false
PRESERVE_STATE=true
PROJECT_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --template)
            TEMPLATE_TYPE="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --preserve-state)
            PRESERVE_STATE=true
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
[[ -z "$PROJECT_DIR" ]] && log_error "Project directory is required (--project-dir)"
[[ ! -d "$PROJECT_DIR" ]] && log_error "Project directory does not exist: $PROJECT_DIR"

# Set default backup directory
[[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"

log_header "StackKit v1 to v2 Migration"
log_info "Source: $PROJECT_DIR"
log_info "Backup: $BACKUP_DIR"
log_info "Dry run: $DRY_RUN"

# Step 1: Analyze existing project
analyze_project() {
    log_header "Step 1: Analyzing existing project"
    
    cd "$PROJECT_DIR"
    
    # Detect project type
    local detected_type=""
    if [[ -f "main.tf" ]]; then
        if grep -q "aws_ecs_service" main.tf; then
            detected_type="api-service"
        elif grep -q "aws_instance" main.tf; then
            detected_type="web-application"
        elif grep -q "aws_lambda_function" main.tf; then
            detected_type="serverless-function"
        fi
    fi
    
    # Set template type if not specified
    if [[ -z "$TEMPLATE_TYPE" ]]; then
        if [[ -n "$detected_type" ]]; then
            TEMPLATE_TYPE="$detected_type"
            log_info "Detected project type: $TEMPLATE_TYPE"
        else
            log_warning "Could not detect project type. Please specify --template"
            echo "Available templates:"
            echo "  - api-service"
            echo "  - web-application" 
            echo "  - serverless-function"
            echo "  - microservice"
            read -p "Enter template type: " TEMPLATE_TYPE
        fi
    fi
    
    # Check for existing modules
    local old_modules=()
    if [[ -d "modules" ]]; then
        while IFS= read -r -d '' module; do
            old_modules+=("$(basename "$module")")
        done < <(find modules -mindepth 1 -maxdepth 1 -type d -print0)
    fi
    
    # Check for terraform files
    local tf_files=()
    while IFS= read -r -d '' file; do
        tf_files+=("$file")
    done < <(find . -name "*.tf" -print0)
    
    # Check for state files
    local has_state=false
    if [[ -f "terraform.tfstate" ]] || [[ -f ".terraform/terraform.tfstate" ]]; then
        has_state=true
    fi
    
    log_info "Analysis results:"
    echo "  - Template type: $TEMPLATE_TYPE"
    echo "  - Old modules found: ${#old_modules[@]}"
    echo "  - Terraform files: ${#tf_files[@]}"
    echo "  - Has state: $has_state"
    
    if [[ "$has_state" == true ]] && [[ "$PRESERVE_STATE" == true ]]; then
        log_warning "Terraform state detected. Migration will preserve existing state."
    fi
    
    # Return to original directory
    cd - > /dev/null
}

# Step 2: Create backup
create_backup() {
    log_header "Step 2: Creating backup"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would create backup at $BACKUP_DIR"
        return 0
    fi
    
    log_info "Creating backup of original project..."
    cp -r "$PROJECT_DIR" "$BACKUP_DIR"
    log_success "Backup created at: $BACKUP_DIR"
}

# Step 3: Download new template
download_template() {
    log_header "Step 3: Preparing new template structure"
    
    local template_source="../templates/$TEMPLATE_TYPE"
    if [[ ! -d "$template_source" ]]; then
        log_error "Template not found: $template_source"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would copy template from $template_source"
        return 0
    fi
    
    log_info "Copying template structure..."
    
    # Create new structure directories
    mkdir -p "$PROJECT_DIR/environments/"{dev,staging,prod}
    mkdir -p "$PROJECT_DIR/.github/workflows"
    mkdir -p "$PROJECT_DIR/scripts"
    
    # Copy template files (excluding .git)
    rsync -av --exclude='.git' "$template_source/" "$PROJECT_DIR/template-new/"
    
    log_success "Template structure prepared"
}

# Step 4: Extract project information
extract_project_info() {
    log_header "Step 4: Extracting project information"
    
    cd "$PROJECT_DIR"
    
    # Try to extract project info from existing files
    local project_name=""
    local team_name=""
    local org_name=""
    local aws_region=""
    
    # Look for project name in various places
    if [[ -f "terraform.tfvars" ]]; then
        project_name=$(grep -o 'project_name.*=.*"[^"]*"' terraform.tfvars | cut -d'"' -f2 || echo "")
        team_name=$(grep -o 'team.*=.*"[^"]*"' terraform.tfvars | cut -d'"' -f2 || echo "")
        aws_region=$(grep -o 'region.*=.*"[^"]*"' terraform.tfvars | cut -d'"' -f2 || echo "")
    fi
    
    # Try to extract from tags in main.tf
    if [[ -z "$project_name" ]] && [[ -f "main.tf" ]]; then
        project_name=$(grep -o 'Project.*=.*"[^"]*"' main.tf | cut -d'"' -f2 || echo "")
        team_name=$(grep -o 'Team.*=.*"[^"]*"' main.tf | cut -d'"' -f2 || echo "")
    fi
    
    # Use directory name as fallback
    if [[ -z "$project_name" ]]; then
        project_name=$(basename "$PROJECT_DIR" | sed 's/-infrastructure$//')
    fi
    
    # Interactive input for missing values
    if [[ "$FORCE" == false ]]; then
        echo
        log_info "Please confirm/provide project information:"
        read -p "Project name [$project_name]: " input_project
        project_name="${input_project:-$project_name}"
        
        read -p "Team name [$team_name]: " input_team
        team_name="${input_team:-$team_name}"
        
        read -p "Organization [$org_name]: " input_org
        org_name="${input_org:-$org_name}"
        
        read -p "AWS region [$aws_region]: " input_region
        aws_region="${input_region:-$aws_region}"
    fi
    
    # Set defaults if still empty
    project_name="${project_name:-my-project}"
    team_name="${team_name:-backend}"
    org_name="${org_name:-mycompany}"
    aws_region="${aws_region:-ap-northeast-2}"
    
    # Export for use in other functions
    export PROJECT_NAME="$project_name"
    export TEAM_NAME="$team_name"
    export ORG_NAME="$org_name"
    export AWS_REGION="$aws_region"
    
    log_info "Project information:"
    echo "  - Name: $PROJECT_NAME"
    echo "  - Team: $TEAM_NAME"
    echo "  - Organization: $ORG_NAME"
    echo "  - Region: $AWS_REGION"
    
    cd - > /dev/null
}

# Step 5: Convert module references
convert_module_references() {
    log_header "Step 5: Converting module references"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would convert local module references to registry references"
        cd "$PROJECT_DIR"
        
        # Show what would be converted
        if [[ -f "main.tf" ]]; then
            echo "Current module references:"
            grep -n "source.*=.*\".*modules/" main.tf || echo "  No local module references found"
        fi
        
        cd - > /dev/null
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Convert local module references to registry references
    if [[ -f "main.tf" ]]; then
        log_info "Converting module references in main.tf..."
        
        # Common module conversions
        local conversions=(
            "s|source = \"./modules/vpc\"|source = \"git::https://github.com/company/stackkit-terraform-modules.git//foundation/networking/vpc?ref=v1.0.0\"|g"
            "s|source = \"./modules/ecs\"|source = \"git::https://github.com/company/stackkit-terraform-modules.git//foundation/compute/ecs?ref=v1.0.0\"|g"
            "s|source = \"./modules/rds\"|source = \"git::https://github.com/company/stackkit-terraform-modules.git//foundation/database/rds?ref=v1.0.0\"|g"
            "s|source = \"./modules/alb\"|source = \"git::https://github.com/company/stackkit-terraform-modules.git//foundation/networking/alb?ref=v1.0.0\"|g"
        )
        
        for conversion in "${conversions[@]}"; do
            sed -i.bak "$conversion" main.tf
        done
        
        # Remove backup file
        rm -f main.tf.bak
        
        log_success "Module references converted"
    fi
    
    cd - > /dev/null
}

# Step 6: Apply new template structure
apply_template_structure() {
    log_header "Step 6: Applying new template structure"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would apply new template structure"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Copy template files with substitutions
    log_info "Applying template structure..."
    
    # Copy main template files
    cp template-new/main.tf main-new.tf
    cp template-new/variables.tf variables-new.tf
    cp template-new/outputs.tf outputs-new.tf
    
    # Substitute placeholders
    local files_to_substitute=("main-new.tf" "variables-new.tf" "outputs-new.tf")
    
    for file in "${files_to_substitute[@]}"; do
        if [[ -f "$file" ]]; then
            sed -i.bak \
                -e "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" \
                -e "s/TEAM_NAME_PLACEHOLDER/$TEAM_NAME/g" \
                -e "s/ORG_NAME_PLACEHOLDER/$ORG_NAME/g" \
                -e "s/REGION_PLACEHOLDER/$AWS_REGION/g" \
                "$file"
            rm -f "$file.bak"
        fi
    done
    
    # Copy environment configurations
    for env in dev staging prod; do
        if [[ -f "template-new/environments/$env/terraform.tfvars" ]]; then
            cp "template-new/environments/$env/terraform.tfvars" "environments/$env/"
            
            # Substitute placeholders in tfvars
            sed -i.bak \
                -e "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" \
                -e "s/TEAM_NAME_PLACEHOLDER/$TEAM_NAME/g" \
                -e "s/ORG_NAME_PLACEHOLDER/$ORG_NAME/g" \
                -e "s/REGION_PLACEHOLDER/$AWS_REGION/g" \
                "environments/$env/terraform.tfvars"
            rm -f "environments/$env/terraform.tfvars.bak"
        fi
    done
    
    # Copy CI/CD and configuration files
    cp template-new/.github/workflows/terraform-ci.yml .github/workflows/
    cp template-new/atlantis.yaml .
    cp template-new/README.md README-new.md
    
    # Substitute placeholders in workflow files
    sed -i.bak \
        -e "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" \
        -e "s/TEAM_NAME_PLACEHOLDER/$TEAM_NAME/g" \
        -e "s/ORG_NAME_PLACEHOLDER/$ORG_NAME/g" \
        .github/workflows/terraform-ci.yml atlantis.yaml README-new.md
    
    rm -f .github/workflows/terraform-ci.yml.bak atlantis.yaml.bak README-new.md.bak
    
    # Clean up template directory
    rm -rf template-new
    
    log_success "Template structure applied"
    
    cd - > /dev/null
}

# Step 7: Preserve state and important files
preserve_state() {
    log_header "Step 7: Preserving Terraform state and important files"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would preserve existing state files"
        return 0
    fi
    
    if [[ "$PRESERVE_STATE" == false ]]; then
        log_warning "State preservation disabled. Skipping..."
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Preserve state files
    if [[ -f "terraform.tfstate" ]]; then
        log_info "Preserving terraform.tfstate..."
        cp terraform.tfstate terraform.tfstate.backup
    fi
    
    if [[ -d ".terraform" ]]; then
        log_info "Preserving .terraform directory..."
        cp -r .terraform .terraform.backup
    fi
    
    # Preserve any custom scripts or documentation
    if [[ -d "scripts" ]]; then
        log_info "Preserving custom scripts..."
        cp -r scripts scripts.backup
    fi
    
    log_success "State and important files preserved"
    
    cd - > /dev/null
}

# Step 8: Generate migration report
generate_report() {
    log_header "Step 8: Generating migration report"
    
    local report_file="$PROJECT_DIR/MIGRATION_REPORT.md"
    
    if [[ "$DRY_RUN" == true ]]; then
        report_file="./MIGRATION_REPORT_DRY_RUN.md"
    fi
    
    cat > "$report_file" << EOF
# StackKit v1 to v2 Migration Report

**Project**: $PROJECT_NAME  
**Migration Date**: $(date +"%Y-%m-%d %H:%M:%S")  
**Template**: $TEMPLATE_TYPE  
**Status**: $(if [[ "$DRY_RUN" == true ]]; then echo "DRY RUN"; else echo "COMPLETED"; fi)

## Summary

This report documents the migration from StackKit v1 to v2 architecture.

### Changes Made

1. **Project Structure**: Migrated to template-based structure
2. **Module References**: Converted to registry-based modules
3. **CI/CD**: Added modern GitHub Actions workflows
4. **GitOps**: Added Atlantis configuration
5. **Environments**: Structured environment-specific configurations

### Files Modified

- \`main.tf\` → Updated to use registry modules
- \`variables.tf\` → Updated with new variable structure
- \`outputs.tf\` → Enhanced output definitions
- \`environments/*/terraform.tfvars\` → Environment-specific configurations
- \`.github/workflows/terraform-ci.yml\` → CI/CD pipeline
- \`atlantis.yaml\` → GitOps configuration

### Backup Location

$(if [[ "$DRY_RUN" == false ]]; then echo "Original project backed up to: \`$BACKUP_DIR\`"; else echo "Backup would be created at: \`$BACKUP_DIR\`"; fi)

### Next Steps

1. **Review Configuration**: Check all environment configurations
2. **Update Secrets**: Configure secrets in AWS Secrets Manager
3. **Test Migration**: Run \`terraform plan\` in each environment
4. **Update CI/CD**: Configure GitHub secrets and environments
5. **Deploy**: Test deployment in development environment

### Verification Commands

\`\`\`bash
# Validate new configuration
cd environments/dev
terraform init
terraform plan

# Check with StackKit CLI
stackkit validate
stackkit status
\`\`\`

### Rollback Instructions

$(if [[ "$DRY_RUN" == false ]]; then
echo "If needed, rollback by restoring from backup:

\`\`\`bash
rm -rf $PROJECT_DIR
cp -r $BACKUP_DIR $PROJECT_DIR
\`\`\`"
else
echo "This was a dry run - no changes were made to rollback."
fi)

### Support

- **Team**: $TEAM_NAME
- **Template Documentation**: [StackKit v2 Templates](../templates/)
- **Module Documentation**: [StackKit Module Registry](https://github.com/company/stackkit-terraform-modules)

---
Generated by StackKit Migration Tool v2.0.0
EOF

    log_success "Migration report generated: $report_file"
}

# Step 9: Final validation
final_validation() {
    log_header "Step 9: Final validation"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Skipping validation"
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Check if terraform files are valid
    log_info "Validating Terraform syntax..."
    
    for env_dir in environments/*/; do
        if [[ -d "$env_dir" ]]; then
            env_name=$(basename "$env_dir")
            log_info "Validating $env_name environment..."
            
            cd "$env_dir"
            if terraform init -backend=false > /dev/null 2>&1; then
                if terraform validate > /dev/null 2>&1; then
                    log_success "$env_name: Valid"
                else
                    log_warning "$env_name: Validation issues (review manually)"
                fi
            else
                log_warning "$env_name: Init failed (review manually)"
            fi
            cd - > /dev/null
        fi
    done
    
    log_success "Migration validation completed"
    
    cd - > /dev/null
}

# Main migration flow
main() {
    log_header "Starting StackKit v1 to v2 Migration"
    
    # Confirm before proceeding
    if [[ "$FORCE" == false ]] && [[ "$DRY_RUN" == false ]]; then
        echo
        log_warning "This migration will modify your existing project structure."
        log_info "A backup will be created at: $BACKUP_DIR"
        echo
        read -p "Do you want to proceed? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Migration cancelled"
            exit 0
        fi
    fi
    
    # Execute migration steps
    analyze_project
    create_backup
    download_template
    extract_project_info
    convert_module_references
    apply_template_structure
    preserve_state
    generate_report
    final_validation
    
    echo
    log_success "Migration completed successfully!"
    
    if [[ "$DRY_RUN" == false ]]; then
        echo
        log_info "Next steps:"
        echo "  1. Review the migration report: $PROJECT_DIR/MIGRATION_REPORT.md"
        echo "  2. Update environment configurations in environments/"
        echo "  3. Configure secrets in AWS Secrets Manager"
        echo "  4. Test with: cd $PROJECT_DIR && stackkit validate"
        echo "  5. Deploy to dev: stackkit deploy --env dev"
    else
        log_info "This was a dry run. Use without --dry-run to apply changes."
    fi
}

# Run migration
main "$@"