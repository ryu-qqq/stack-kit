#!/bin/bash
# ECS Addon Validation Script
# Validates the addon configuration and prerequisites

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Validation counters
ERRORS=0
WARNINGS=0

# Function to increment error counter
error() {
    log_error "$1"
    ((ERRORS++))
}

# Function to increment warning counter
warning() {
    log_warning "$1"
    ((WARNINGS++))
}

log_info "🔍 Validating ECS Addon v1.0.0"
echo

# Check if we're in the addon directory
if [[ ! -f "main.tf" ]] || [[ ! -f "variables.tf" ]] || [[ ! -f "outputs.tf" ]]; then
    error "Not in ECS addon directory. Please run this script from the addon root."
    exit 1
fi

# Check required files
log_info "Checking required files..."
required_files=("main.tf" "variables.tf" "outputs.tf" "iam.tf" "README.md" "VERSION")

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        error "Missing required file: $file"
    fi
done

# Check example files
log_info "Checking example files..."
example_files=("examples/api-service.tf" "examples/worker-service.tf" "examples/terraform.tfvars.example")

for file in "${example_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        warning "Missing example file: $file"
    fi
done

# Check if Terraform is installed
log_info "Checking Terraform installation..."
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log_success "Terraform found: $TERRAFORM_VERSION"
    
    # Check minimum version
    if [[ $(echo "$TERRAFORM_VERSION 1.5.0" | tr " " "\n" | sort -V | head -n1) == "1.5.0" ]]; then
        log_success "Terraform version meets minimum requirement (>= 1.5.0)"
    else
        error "Terraform version $TERRAFORM_VERSION does not meet minimum requirement (>= 1.5.0)"
    fi
else
    error "Terraform not found. Please install Terraform >= 1.5.0"
fi

# Check if AWS CLI is installed
log_info "Checking AWS CLI installation..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d/ -f2 | cut -d' ' -f1)
    log_success "AWS CLI found: $AWS_VERSION"
else
    warning "AWS CLI not found. Consider installing for easier management"
fi

# Validate Terraform syntax
log_info "Validating Terraform syntax..."
if terraform fmt -check=true -recursive . &> /dev/null; then
    log_success "Terraform files are properly formatted"
else
    warning "Terraform files need formatting. Run 'terraform fmt -recursive .'"
fi

# Initialize and validate (if not already initialized)
if [[ ! -d ".terraform" ]]; then
    log_info "Initializing Terraform for validation..."
    if terraform init -backend=false &> /dev/null; then
        log_success "Terraform initialization successful"
    else
        error "Terraform initialization failed"
    fi
fi

# Validate configuration
log_info "Validating Terraform configuration..."
if terraform validate &> /dev/null; then
    log_success "Terraform configuration is valid"
else
    error "Terraform configuration validation failed"
    terraform validate
fi

# Check for required provider versions
log_info "Checking provider versions..."
if grep -q 'version.*"~> 5.0"' main.tf; then
    log_success "AWS provider version constraint found"
else
    warning "AWS provider version constraint not found or incorrect"
fi

# Check for proper tagging
log_info "Checking tagging configuration..."
if grep -q "common_tags" main.tf; then
    log_success "Common tags configuration found"
else
    warning "Common tags configuration not found"
fi

# Check for security best practices
log_info "Checking security best practices..."

# Check for least privilege IAM
if grep -q "execution_role_arn.*aws_iam_role.execution_role.arn" main.tf; then
    log_success "Proper IAM role separation found"
else
    warning "IAM role configuration should be reviewed"
fi

# Check for egress restrictions (should have a comment about why it's open)
if grep -q "ALLOW_PUBLIC_EXEMPT\|All outbound traffic" main.tf; then
    log_success "Egress rules are documented"
else
    warning "Egress rules should be documented with security exceptions"
fi

# Check for secrets handling
if grep -q "secrets.*valueFrom" main.tf; then
    log_success "Proper secrets handling found"
else
    log_info "Secrets handling is optional but recommended"
fi

# Check environment-specific configuration
log_info "Checking environment-specific configuration..."
if grep -q "environment_config.*dev.*staging.*prod" variables.tf; then
    log_success "Environment-specific configuration found"
else
    warning "Environment-specific configuration should be defined"
fi

# Check auto scaling configuration
if grep -q "enable_autoscaling" variables.tf && grep -q "aws_appautoscaling_target" main.tf; then
    log_success "Auto scaling configuration found"
else
    warning "Auto scaling configuration incomplete"
fi

# Check health check configuration
if grep -q "health_check" main.tf; then
    log_success "Health check configuration found"
else
    warning "Health check configuration should be defined"
fi

# Validate example configurations
log_info "Validating example configurations..."
for example in examples/*.tf; do
    if [[ -f "$example" ]]; then
        if terraform validate -chdir="$(dirname "$example")" &> /dev/null; then
            log_success "Example $(basename "$example") is valid"
        else
            warning "Example $(basename "$example") has validation issues"
        fi
    fi
done

# Check documentation completeness
log_info "Checking documentation completeness..."
if [[ -f "README.md" ]]; then
    doc_sections=("Overview" "Prerequisites" "Quick Start" "Configuration Reference" "Examples" "Troubleshooting")
    for section in "${doc_sections[@]}"; do
        if grep -q "$section" README.md; then
            log_success "Documentation section found: $section"
        else
            warning "Documentation section missing: $section"
        fi
    done
fi

# Check version tagging
if [[ -f "VERSION" ]]; then
    VERSION=$(cat VERSION)
    log_success "Version file found: $VERSION"
    
    if [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_success "Version format is correct (semantic versioning)"
    else
        warning "Version format should follow semantic versioning (vX.Y.Z)"
    fi
else
    warning "VERSION file not found"
fi

# Summary
echo
log_info "📊 Validation Summary"
echo "  Errors: $ERRORS"
echo "  Warnings: $WARNINGS"

if [[ $ERRORS -eq 0 ]]; then
    log_success "🎉 Addon validation passed!"
    if [[ $WARNINGS -gt 0 ]]; then
        log_warning "Consider addressing the warnings above for best practices"
    fi
    exit 0
else
    log_error "❌ Addon validation failed with $ERRORS errors"
    log_info "Please fix the errors above before using this addon"
    exit 1
fi