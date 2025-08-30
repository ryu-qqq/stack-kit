#!/usr/bin/env bash
set -euo pipefail

# Stack validation and cost estimation script
# Usage: scripts/validate.sh <stack_name> <env> [OPTIONS]

show_help() {
    cat << EOF
Usage: $0 <stack_name> <env> [OPTIONS]

Arguments:
    stack_name    Name of the stack to validate
    env          Environment (dev|staging|prod)

Options:
    --cost-only      Only run cost estimation
    --validate-only  Only run validation (skip cost estimation)
    --format=FORMAT  Output format: table|json|html (default: table)
    --detailed       Show detailed validation output
    --help          Show this help message

Examples:
    $0 my-web-app prod
    $0 my-api dev --cost-only
    $0 custom-stack staging --format=json --detailed
EOF
}

# Parse arguments
STACK="${1:-}"
ENV="${2:-}"
COST_ONLY=false
VALIDATE_ONLY=false
FORMAT="table"
DETAILED=false

if [[ -z "$STACK" || -z "$ENV" ]]; then
    show_help
    exit 1
fi

# Parse optional arguments
for arg in "${@:3}"; do
    case $arg in
        --cost-only)
            COST_ONLY=true
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            ;;
        --format=*)
            FORMAT="${arg#*=}"
            ;;
        --detailed)
            DETAILED=true
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

# Validate format
if [[ ! "$FORMAT" =~ ^(table|json|html)$ ]]; then
    echo "❌ Invalid format: $FORMAT. Must be: table|json|html"
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

echo "🔍 Validating stack: $STACK ($ENV)"
echo "📁 Stack directory: $STACK_DIR"
echo ""

# Check required tools
check_tools() {
    echo "🔧 Checking required tools..."
    
    local missing_tools=()
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    else
        echo "  ✅ Terraform: $(terraform version -json | jq -r '.terraform_version')"
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    else
        echo "  ✅ AWS CLI: $(aws --version | cut -d' ' -f1)"
    fi
    
    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    else
        echo "  ✅ jq: $(jq --version)"
    fi
    
    # Check Infracost (optional)
    if command -v infracost &> /dev/null; then
        echo "  ✅ Infracost: $(infracost --version)"
        INFRACOST_AVAILABLE=true
    else
        echo "  ⚠️  Infracost: Not installed (cost estimation will be limited)"
        INFRACOST_AVAILABLE=false
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo ""
        echo "❌ Missing required tools: ${missing_tools[*]}"
        echo "Please install missing tools and try again."
        exit 1
    fi
    
    echo "  🎉 All required tools are available"
    echo ""
}

# Terraform validation
run_terraform_validation() {
    echo "🔧 Running Terraform validation..."
    
    cd "$STACK_DIR"
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        echo "  📦 Initializing Terraform..."
        if ! terraform init -backend-config=backend.hcl > init.log 2>&1; then
            echo "  ❌ Terraform init failed"
            if [[ "$DETAILED" == "true" ]]; then
                cat init.log
            fi
            return 1
        fi
        echo "  ✅ Terraform initialized"
    fi
    
    # Format check
    echo "  📝 Checking format..."
    if terraform fmt -check=true -diff=true; then
        echo "  ✅ Code formatting is correct"
    else
        echo "  ⚠️  Code formatting issues found"
        if [[ "$DETAILED" == "true" ]]; then
            terraform fmt -check=false -diff=true
        fi
    fi
    
    # Validation
    echo "  🔍 Validating configuration..."
    if terraform validate; then
        echo "  ✅ Configuration is valid"
    else
        echo "  ❌ Configuration validation failed"
        return 1
    fi
    
    # Plan check
    echo "  📋 Generating plan..."
    if terraform plan -out=tfplan -detailed-exitcode > plan.log 2>&1; then
        plan_exit_code=$?
        case $plan_exit_code in
            0)
                echo "  ✅ No changes needed"
                ;;
            2)
                echo "  📋 Changes planned"
                if [[ "$DETAILED" == "true" ]]; then
                    terraform show tfplan
                fi
                ;;
        esac
    else
        echo "  ❌ Plan generation failed"
        if [[ "$DETAILED" == "true" ]]; then
            cat plan.log
        fi
        return 1
    fi
    
    echo ""
    return 0
}

# Policy validation using tf_forbidden.sh
run_policy_validation() {
    echo "🛡️  Running policy validation..."
    
    if [[ -f "$INFRA_ROOT/scripts/tf_forbidden.sh" ]]; then
        if bash "$INFRA_ROOT/scripts/tf_forbidden.sh"; then
            echo "  ✅ Policy validation passed"
        else
            echo "  ❌ Policy validation failed"
            return 1
        fi
    else
        echo "  ⚠️  Policy script not found (skipping)"
    fi
    
    echo ""
    return 0
}

# Cost estimation
run_cost_estimation() {
    echo "💰 Running cost estimation..."
    
    cd "$STACK_DIR"
    
    if [[ "$INFRACOST_AVAILABLE" == "true" ]]; then
        echo "  📊 Using Infracost for detailed estimation..."
        
        # Generate cost breakdown
        if infracost breakdown --path=. --format="$FORMAT" --show-skipped > cost_breakdown.out 2>&1; then
            echo "  ✅ Cost estimation completed"
            
            case $FORMAT in
                table)
                    cat cost_breakdown.out
                    ;;
                json)
                    echo "  💾 Cost data saved to: cost_breakdown.out"
                    if command -v jq &> /dev/null; then
                        echo "  📈 Monthly cost: $(jq -r '.totalMonthlyCost // "N/A"' cost_breakdown.out)"
                    fi
                    ;;
                html)
                    echo "  💾 Cost report saved to: cost_breakdown.out"
                    ;;
            esac
        else
            echo "  ❌ Cost estimation failed"
            if [[ "$DETAILED" == "true" ]]; then
                cat cost_breakdown.out
            fi
        fi
    else
        echo "  📋 Basic cost estimation (install Infracost for detailed analysis):"
        echo ""
        
        # Basic cost estimates based on resources
        if [[ -f "tfplan" ]]; then
            terraform show -json tfplan > tfplan.json
            
            # Count resources by type
            local ec2_count=$(jq -r '[.planned_values.root_module.child_modules[]?.resources[]? | select(.type == "aws_instance")] | length' tfplan.json 2>/dev/null || echo "0")
            local rds_count=$(jq -r '[.planned_values.root_module.child_modules[]?.resources[]? | select(.type == "aws_db_instance")] | length' tfplan.json 2>/dev/null || echo "0")
            local lambda_count=$(jq -r '[.planned_values.root_module.child_modules[]?.resources[]? | select(.type == "aws_lambda_function")] | length' tfplan.json 2>/dev/null || echo "0")
            
            echo "  📊 Resource summary:"
            echo "    - EC2 instances: $ec2_count"
            echo "    - RDS instances: $rds_count"  
            echo "    - Lambda functions: $lambda_count"
            echo ""
            echo "  💡 Install Infracost for accurate cost estimates:"
            echo "     curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh"
            
            rm -f tfplan.json
        fi
    fi
    
    echo ""
    return 0
}

# Security scan
run_security_scan() {
    echo "🔒 Running security scan..."
    
    cd "$STACK_DIR"
    
    # Check for tfsec
    if command -v tfsec &> /dev/null; then
        echo "  🛡️  Running tfsec scan..."
        if tfsec --format=$FORMAT . > security_scan.out 2>&1; then
            echo "  ✅ Security scan completed"
            if [[ "$FORMAT" == "table" ]]; then
                cat security_scan.out
            else
                echo "  💾 Security report saved to: security_scan.out"
            fi
        else
            echo "  ⚠️  Security issues found"
            if [[ "$DETAILED" == "true" || "$FORMAT" == "table" ]]; then
                cat security_scan.out
            fi
        fi
    else
        echo "  ⚠️  tfsec not installed (skipping security scan)"
        echo "     Install: https://github.com/aquasecurity/tfsec"
    fi
    
    echo ""
    return 0
}

# Main execution
main() {
    local validation_passed=true
    
    # Always check tools
    check_tools
    
    # Run validations based on flags
    if [[ "$COST_ONLY" != "true" ]]; then
        if ! run_terraform_validation; then
            validation_passed=false
        fi
        
        if ! run_policy_validation; then
            validation_passed=false
        fi
        
        run_security_scan
    fi
    
    if [[ "$VALIDATE_ONLY" != "true" ]]; then
        run_cost_estimation
    fi
    
    # Summary
    echo "📋 Validation Summary"
    echo "===================="
    echo "Stack: $STACK ($ENV)"
    echo "Directory: $STACK_DIR"
    
    if [[ "$validation_passed" == "true" ]]; then
        echo "Status: ✅ PASSED"
        echo ""
        echo "🚀 Ready for deployment!"
        echo "   terraform -chdir=$STACK_DIR apply"
    else
        echo "Status: ❌ FAILED"
        echo ""
        echo "🔧 Fix validation issues before deploying"
        exit 1
    fi
}

# Run main function
main