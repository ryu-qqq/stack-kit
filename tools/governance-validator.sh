#!/bin/bash
set -euo pipefail

# 🔒 Terraform Governance Validator
# 중앙 정책 기반 인프라 코드 검증

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Configuration
CENTRAL_REPO="${CENTRAL_REPO:-https://github.com/company/stackkit-terraform.git}"
MAX_COST_DEV=500
MAX_COST_STAGING=1000
MAX_COST_PROD=5000
ERRORS=0
WARNINGS=0

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

🔒 Terraform 거버넌스 검증 도구

Options:
    --dir DIR               검증할 디렉토리 (기본: .)
    --environment ENV       환경 (dev|staging|prod)
    --strict               경고도 오류로 처리
    --skip-cost            비용 검증 건너뛰기
    --skip-security        보안 검증 건너뛰기
    --central-repo REPO    중앙 레포 URL
    --help                 도움말 표시

Examples:
    # 현재 디렉토리 검증
    $0

    # 특정 환경에 대해 엄격한 검증
    $0 --environment prod --strict

    # 보안 검증만
    $0 --skip-cost

EOF
}

# Parse arguments
DIR="."
ENVIRONMENT=""
STRICT=false
SKIP_COST=false
SKIP_SECURITY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            DIR="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --strict)
            STRICT=true
            shift
            ;;
        --skip-cost)
            SKIP_COST=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        --central-repo)
            CENTRAL_REPO="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Change to target directory
cd "$DIR"

# Detect environment if not specified
if [[ -z "$ENVIRONMENT" ]]; then
    if [[ -f "terraform.tfvars" ]]; then
        ENVIRONMENT=$(grep -E "^environment\s*=" terraform.tfvars | cut -d'"' -f2 || echo "")
    fi
    if [[ -z "$ENVIRONMENT" ]]; then
        log_warning "Environment not detected, using 'dev' as default"
        ENVIRONMENT="dev"
    fi
fi

log_info "Starting governance validation..."
log_info "Directory: $(pwd)"
log_info "Environment: $ENVIRONMENT"

# 1. Module Version Check
check_module_versions() {
    log_info "Checking module versions..."
    
    local unversioned=0
    
    # Find all module sources
    while IFS= read -r line; do
        if [[ "$line" == *"ref="* ]]; then
            continue
        fi
        if [[ "$line" == *"git::"* ]] || [[ "$line" == *"github.com"* ]]; then
            log_error "Unversioned module found: $line"
            unversioned=$((unversioned + 1))
        fi
    done < <(grep -h "source\s*=" *.tf 2>/dev/null | grep -v "^#")
    
    if [[ $unversioned -eq 0 ]]; then
        log_success "All modules are versioned"
    else
        log_error "Found $unversioned unversioned modules"
        ERRORS=$((ERRORS + unversioned))
    fi
}

# 2. Required Tags Check
check_required_tags() {
    log_info "Checking required tags..."
    
    local required_tags=("Project" "Team" "Environment" "CostCenter" "Owner" "ManagedBy")
    local missing_tags=0
    
    # Check if common_tags or tags include all required tags
    for tag in "${required_tags[@]}"; do
        if ! grep -q "$tag" *.tf 2>/dev/null; then
            log_warning "Required tag '$tag' not found in any .tf file"
            missing_tags=$((missing_tags + 1))
        fi
    done
    
    if [[ $missing_tags -eq 0 ]]; then
        log_success "All required tags are present"
    else
        log_warning "Missing $missing_tags required tags"
        WARNINGS=$((WARNINGS + missing_tags))
    fi
}

# 3. Resource Naming Convention
check_naming_convention() {
    log_info "Checking resource naming conventions..."
    
    local invalid_names=0
    
    # Check resource names follow pattern: {project}-{env}-{service}-{type}
    while IFS= read -r line; do
        # Extract resource name
        if [[ "$line" =~ resource[[:space:]]+\"[^\"]+\"[[:space:]]+\"([^\"]+)\" ]]; then
            local resource_name="${BASH_REMATCH[1]}"
            
            # Check if name contains environment
            if [[ ! "$resource_name" == *"${ENVIRONMENT}"* ]] && [[ ! "$resource_name" == *'${var.environment}'* ]] && [[ ! "$resource_name" == *'${local.'* ]]; then
                log_warning "Resource name doesn't include environment: $resource_name"
                invalid_names=$((invalid_names + 1))
            fi
        fi
    done < <(grep "^resource\s" *.tf 2>/dev/null)
    
    if [[ $invalid_names -eq 0 ]]; then
        log_success "All resource names follow convention"
    else
        log_warning "Found $invalid_names resources with non-standard names"
        WARNINGS=$((WARNINGS + invalid_names))
    fi
}

# 4. Backend Configuration Check
check_backend_config() {
    log_info "Checking backend configuration..."
    
    if [[ ! -f "backend.tf" ]] && [[ ! -f "backend.hcl" ]]; then
        log_error "No backend configuration found (backend.tf or backend.hcl)"
        ERRORS=$((ERRORS + 1))
        return
    fi
    
    # Check for S3 backend with encryption
    if [[ -f "backend.tf" ]]; then
        if ! grep -q "encrypt\s*=\s*true" backend.tf; then
            log_error "Backend encryption is not enabled"
            ERRORS=$((ERRORS + 1))
        fi
        
        if ! grep -q "dynamodb_table" backend.tf; then
            log_warning "No DynamoDB table for state locking"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    log_success "Backend configuration validated"
}

# 5. Instance Type Restrictions
check_instance_types() {
    log_info "Checking instance type restrictions..."
    
    local invalid_types=0
    local allowed_types_dev="t3.micro t3.small t3.medium"
    local allowed_types_staging="t3.small t3.medium t3.large"
    local allowed_types_prod="t3.medium t3.large t3.xlarge m5.large m5.xlarge"
    
    # Get allowed types for environment
    local allowed_types=""
    case "$ENVIRONMENT" in
        dev)
            allowed_types="$allowed_types_dev"
            ;;
        staging)
            allowed_types="$allowed_types_staging"
            ;;
        prod)
            allowed_types="$allowed_types_prod"
            ;;
    esac
    
    # Check instance types in .tf files
    while IFS= read -r line; do
        if [[ "$line" =~ instance_type[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            local instance_type="${BASH_REMATCH[1]}"
            
            # Skip if it's a variable reference
            if [[ "$instance_type" == *'${'* ]]; then
                continue
            fi
            
            if [[ ! " $allowed_types " =~ " $instance_type " ]]; then
                log_error "Instance type '$instance_type' not allowed in $ENVIRONMENT environment"
                invalid_types=$((invalid_types + 1))
            fi
        fi
    done < <(grep "instance_type\s*=" *.tf 2>/dev/null)
    
    if [[ $invalid_types -eq 0 ]]; then
        log_success "All instance types are compliant"
    else
        ERRORS=$((ERRORS + invalid_types))
    fi
}

# 6. Security Group Rules Check
check_security_groups() {
    if [[ "$SKIP_SECURITY" == true ]]; then
        log_info "Skipping security checks"
        return
    fi
    
    log_info "Checking security group rules..."
    
    local open_ingress=0
    
    # Check for 0.0.0.0/0 in security groups
    if grep -q "0.0.0.0/0" *.tf 2>/dev/null; then
        # Check if it's properly exempted
        while IFS= read -r line; do
            if [[ "$line" == *"0.0.0.0/0"* ]] && [[ "$line" != *"ALLOW_PUBLIC_EXEMPT"* ]]; then
                log_error "Unrestricted ingress rule found (0.0.0.0/0) without exemption"
                open_ingress=$((open_ingress + 1))
            fi
        done < <(grep "0.0.0.0/0" *.tf)
    fi
    
    if [[ $open_ingress -eq 0 ]]; then
        log_success "No unrestricted security group rules"
    else
        ERRORS=$((ERRORS + open_ingress))
    fi
}

# 7. Encryption Check
check_encryption() {
    if [[ "$SKIP_SECURITY" == true ]]; then
        return
    fi
    
    log_info "Checking encryption settings..."
    
    local unencrypted=0
    
    # Check S3 buckets for encryption
    if grep -q "aws_s3_bucket\"" *.tf 2>/dev/null; then
        local bucket_count=$(grep -c "resource.*aws_s3_bucket\"" *.tf)
        local encryption_count=$(grep -c "aws_s3_bucket_server_side_encryption" *.tf 2>/dev/null || echo 0)
        
        if [[ $encryption_count -lt $bucket_count ]]; then
            log_error "Not all S3 buckets have encryption configured"
            unencrypted=$((unencrypted + 1))
        fi
    fi
    
    # Check RDS for encryption
    if grep -q "aws_db_instance\"" *.tf 2>/dev/null; then
        if ! grep -q "storage_encrypted\s*=\s*true" *.tf; then
            log_error "RDS instances without encryption found"
            unencrypted=$((unencrypted + 1))
        fi
    fi
    
    # Check EBS volumes for encryption
    if grep -q "aws_ebs_volume\"" *.tf 2>/dev/null; then
        if ! grep -q "encrypted\s*=\s*true" *.tf; then
            log_warning "EBS volumes without encryption found"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    if [[ $unencrypted -eq 0 ]]; then
        log_success "Encryption requirements met"
    else
        ERRORS=$((ERRORS + unencrypted))
    fi
}

# 8. Cost Estimation Check
check_cost_limits() {
    if [[ "$SKIP_COST" == true ]]; then
        log_info "Skipping cost validation"
        return
    fi
    
    log_info "Checking cost limits..."
    
    # Check if Infracost is available
    if ! command -v infracost &> /dev/null; then
        log_warning "Infracost not installed, skipping cost validation"
        return
    fi
    
    # Initialize Terraform
    terraform init -backend=false &> /dev/null || {
        log_warning "Failed to initialize Terraform for cost estimation"
        return
    }
    
    # Generate plan
    terraform plan -out=tfplan &> /dev/null || {
        log_warning "Failed to generate plan for cost estimation"
        return
    }
    
    # Run Infracost
    infracost breakdown --path . --format json --out-file /tmp/infracost.json &> /dev/null || {
        log_warning "Failed to run cost estimation"
        return
    }
    
    # Check cost against limits
    local monthly_cost=$(jq -r '.totalMonthlyCost // "0"' /tmp/infracost.json)
    local max_cost=0
    
    case "$ENVIRONMENT" in
        dev)
            max_cost=$MAX_COST_DEV
            ;;
        staging)
            max_cost=$MAX_COST_STAGING
            ;;
        prod)
            max_cost=$MAX_COST_PROD
            ;;
    esac
    
    # Remove currency symbols and convert to number
    monthly_cost=$(echo "$monthly_cost" | sed 's/[^0-9.]//g')
    
    if (( $(echo "$monthly_cost > $max_cost" | bc -l) )); then
        log_error "Estimated monthly cost (\$$monthly_cost) exceeds limit (\$$max_cost) for $ENVIRONMENT"
        ERRORS=$((ERRORS + 1))
    else
        log_success "Cost within limits: \$$monthly_cost / \$$max_cost"
    fi
    
    # Clean up
    rm -f tfplan tfplan.json /tmp/infracost.json
}

# 9. Terraform Format Check
check_terraform_format() {
    log_info "Checking Terraform formatting..."
    
    if ! terraform fmt -check -recursive . &> /dev/null; then
        log_warning "Terraform files are not properly formatted"
        log_info "Run 'terraform fmt -recursive' to fix"
        WARNINGS=$((WARNINGS + 1))
    else
        log_success "Terraform files are properly formatted"
    fi
}

# 10. Validate Terraform Configuration
validate_terraform() {
    log_info "Validating Terraform configuration..."
    
    # Initialize without backend
    if ! terraform init -backend=false &> /dev/null; then
        log_error "Failed to initialize Terraform"
        ERRORS=$((ERRORS + 1))
        return
    fi
    
    # Validate
    if ! terraform validate &> /dev/null; then
        log_error "Terraform validation failed"
        ERRORS=$((ERRORS + 1))
    else
        log_success "Terraform configuration is valid"
    fi
}

# 11. Check for Hardcoded Secrets
check_secrets() {
    log_info "Checking for hardcoded secrets..."
    
    local secrets_found=0
    
    # Common patterns for secrets
    local patterns=(
        "aws_access_key_id"
        "aws_secret_access_key"
        "password\s*="
        "token\s*="
        "api_key\s*="
        "secret\s*="
        "private_key"
    )
    
    for pattern in "${patterns[@]}"; do
        if grep -i "$pattern" *.tf *.tfvars 2>/dev/null | grep -v "^#" | grep -v "var\." | grep -v "data\." > /dev/null; then
            log_error "Potential hardcoded secret found (pattern: $pattern)"
            secrets_found=$((secrets_found + 1))
        fi
    done
    
    if [[ $secrets_found -eq 0 ]]; then
        log_success "No hardcoded secrets detected"
    else
        ERRORS=$((ERRORS + secrets_found))
    fi
}

# 12. Check Remote State References
check_remote_state() {
    log_info "Checking remote state references..."
    
    # Check if data.tf exists
    if [[ ! -f "data.tf" ]]; then
        log_warning "No data.tf file found - might be missing shared infrastructure references"
        WARNINGS=$((WARNINGS + 1))
        return
    fi
    
    # Check for shared VPC reference
    if ! grep -q "terraform_remote_state.*vpc\|aws_vpc.*existing\|data.*vpc" data.tf; then
        log_warning "No VPC reference found - ensure you're using shared VPC"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    log_success "Remote state references checked"
}

# Main validation flow
main() {
    echo "="
    echo "🔒 TERRAFORM GOVERNANCE VALIDATION"
    echo "="
    echo
    
    # Run all checks
    check_terraform_format
    validate_terraform
    check_backend_config
    check_module_versions
    check_required_tags
    check_naming_convention
    check_instance_types
    check_security_groups
    check_encryption
    check_secrets
    check_remote_state
    check_cost_limits
    
    # Summary
    echo
    echo "="
    echo "📊 VALIDATION SUMMARY"
    echo "="
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        log_success "All governance checks passed! 🎉"
        exit 0
    else
        if [[ $ERRORS -gt 0 ]]; then
            log_error "Found $ERRORS error(s)"
        fi
        if [[ $WARNINGS -gt 0 ]]; then
            log_warning "Found $WARNINGS warning(s)"
        fi
        
        if [[ "$STRICT" == true && $WARNINGS -gt 0 ]]; then
            log_error "Strict mode enabled - warnings treated as errors"
            exit 1
        fi
        
        if [[ $ERRORS -gt 0 ]]; then
            exit 1
        fi
    fi
}

main