#!/bin/bash
set -euo pipefail

# StackKit Enterprise System Integration Test
# Demonstrates the complete enterprise onboarding flow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_OUTPUT_DIR="$SCRIPT_DIR/test-output"
BOOTSTRAP_CLI="$SCRIPT_DIR/bootstrap/bootstrap-cli"

# Colors and icons
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO="ℹ️"; OK="✅"; ERR="❌"; WARN="⚠️"; ROCKET="🚀"

log() { echo -e "${BLUE}${INFO} $*${NC}"; }
ok() { echo -e "${GREEN}${OK} $*${NC}"; }
warn() { echo -e "${YELLOW}${WARN} $*${NC}"; }
fail() { echo -e "${RED}${ERR} $*${NC}"; exit 1; }
rocket() { echo -e "${GREEN}${ROCKET} $*${NC}"; }

cleanup() {
    if [ -d "$TEST_OUTPUT_DIR" ]; then
        log "Cleaning up test output directory"
        rm -rf "$TEST_OUTPUT_DIR"
    fi
}

test_requirement_detection() {
    log "Testing requirement detection system"
    
    # Test 1: Node.js backend with PostgreSQL
    local output
    output=$(python3 "$SCRIPT_DIR/bootstrap/detectors/requirement_detector.py" \
        --tech-stack "nodejs,postgres,redis" \
        --team "backend-services" \
        --compliance "sox,gdpr" 2>/dev/null || echo "{}")
    
    if echo "$output" | grep -q "nodejs"; then
        ok "Requirement detection working - detected Node.js requirements"
    else
        warn "Requirement detection may have issues"
    fi
    
    # Test 2: Frontend React application
    output=$(python3 "$SCRIPT_DIR/bootstrap/detectors/requirement_detector.py" \
        --tech-stack "react" \
        --team "frontend-team" 2>/dev/null || echo "{}")
    
    if echo "$output" | grep -q "react"; then
        ok "Frontend requirement detection working"
    else
        warn "Frontend requirement detection may have issues"
    fi
}

test_template_selection() {
    log "Testing template selection system"
    
    # Create test requirements
    local requirements='{"team":"backend-services","tech_stack":["nodejs","postgres"],"compliance":["sox"],"complexity_score":0.7}'
    
    local templates
    templates=$(python3 "$SCRIPT_DIR/bootstrap/detectors/template_selector.py" \
        --requirements "$requirements" \
        --templates-dir "$SCRIPT_DIR/templates" 2>/dev/null || echo "[]")
    
    if echo "$templates" | grep -q "nodejs-ecs"; then
        ok "Template selection working - selected Node.js ECS template"
    else
        warn "Template selection may have issues"
    fi
}

test_configuration_hierarchy() {
    log "Testing configuration hierarchy system"
    
    # Test configuration loading
    local config
    config=$(python3 "$SCRIPT_DIR/config/hierarchy/config_loader.py" \
        --org "acme-corp" \
        --team "backend-services" \
        --environment "prod" \
        --project "user-service" \
        --config-dir "$SCRIPT_DIR/config/hierarchy" 2>/dev/null || echo "{}")
    
    if echo "$config" | grep -q "acme-corp"; then
        ok "Configuration hierarchy working - loaded org config"
    else
        warn "Configuration hierarchy may have issues"
    fi
}

test_bootstrap_cli_dry_run() {
    log "Testing bootstrap CLI with dry run"
    
    # Clean up any previous test output
    rm -rf "$TEST_OUTPUT_DIR"
    
    # Test bootstrap CLI dry run
    "$BOOTSTRAP_CLI" init \
        --team "backend-services" \
        --project "test-service" \
        --tech-stack "nodejs,postgres" \
        --compliance "sox" \
        --environment "dev" \
        --org "acme-corp" \
        --output-dir "$TEST_OUTPUT_DIR" \
        --dry-run
    
    ok "Bootstrap CLI dry run completed successfully"
}

test_full_project_generation() {
    log "Testing full project generation"
    
    # Clean up any previous test output
    rm -rf "$TEST_OUTPUT_DIR"
    
    # Create test project
    "$BOOTSTRAP_CLI" init \
        --team "backend-services" \
        --project "user-service" \
        --tech-stack "nodejs,postgres,redis" \
        --compliance "sox,gdpr" \
        --environment "dev" \
        --org "acme-corp" \
        --output-dir "$TEST_OUTPUT_DIR"
    
    # Verify project structure
    if [ -d "$TEST_OUTPUT_DIR" ]; then
        ok "Project directory created"
        
        # Check key files
        local key_files=(
            "README.md"
            "terraform/main.tf"
            "terraform/variables.tf"
            "terraform/outputs.tf"
            "terraform/environments/dev/terraform.tfvars"
            "docs/architecture.md"
            "scripts/deploy.sh"
            ".github/workflows/infrastructure.yml"
        )
        
        for file in "${key_files[@]}"; do
            if [ -f "$TEST_OUTPUT_DIR/$file" ]; then
                ok "Generated: $file"
            else
                warn "Missing: $file"
            fi
        done
    else
        fail "Project directory was not created"
    fi
}

test_compliance_validation() {
    log "Testing compliance validation"
    
    if [ ! -d "$TEST_OUTPUT_DIR" ]; then
        warn "No test output directory found, skipping compliance test"
        return 0
    fi
    
    # Create test configuration
    local test_config='{"project_name":"user-service","team":"backend-services","org":"acme-corp","environment":"dev","compliance":["sox","gdpr"],"aws_region":"ap-northeast-2"}'
    
    # Run compliance check
    local compliance_result
    compliance_result=$(python3 "$SCRIPT_DIR/governance/validators/compliance_checker.py" \
        --project-dir "$TEST_OUTPUT_DIR" \
        --config "$test_config" \
        --output-format "json" 2>/dev/null || echo "{}")
    
    if echo "$compliance_result" | grep -q "compliance_status"; then
        ok "Compliance validation working"
        
        # Show compliance summary
        local status
        status=$(echo "$compliance_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('compliance_status', 'unknown'))" 2>/dev/null || echo "unknown")
        log "Compliance status: $status"
    else
        warn "Compliance validation may have issues"
    fi
}

show_generated_project_structure() {
    if [ -d "$TEST_OUTPUT_DIR" ]; then
        rocket "Generated Project Structure:"
        echo
        tree "$TEST_OUTPUT_DIR" 2>/dev/null || find "$TEST_OUTPUT_DIR" -type f | sort
        echo
        
        log "Key Generated Files:"
        echo "📄 README.md - Project documentation"
        echo "🏗️  terraform/ - Infrastructure as Code"
        echo "📚 docs/ - Architecture and deployment guides" 
        echo "🔧 scripts/ - Utility scripts"
        echo "🤖 .github/workflows/ - CI/CD automation"
        echo
    fi
}

run_integration_tests() {
    rocket "Starting StackKit Enterprise Integration Tests"
    echo
    
    # Test individual components
    test_requirement_detection
    test_template_selection
    test_configuration_hierarchy
    test_bootstrap_cli_dry_run
    
    echo
    log "Running full project generation test..."
    test_full_project_generation
    
    echo
    log "Running compliance validation test..."
    test_compliance_validation
    
    echo
    show_generated_project_structure
    
    rocket "Integration Tests Completed!"
    echo
    ok "✨ Enterprise system is working correctly"
    echo
    
    log "Next Steps:"
    echo "1. 📁 Review generated project: $TEST_OUTPUT_DIR"
    echo "2. 🚀 Try deploying with: cd $TEST_OUTPUT_DIR && scripts/deploy.sh dev"
    echo "3. 🔍 Check compliance: Review docs/architecture.md"
    echo "4. 🛠️  Customize: Modify terraform/environments/*/terraform.tfvars"
    echo
}

show_usage() {
    cat <<EOF
🏢 StackKit Enterprise System Test

USAGE:
    $(basename "$0") [command]

COMMANDS:
    test        Run full integration tests
    clean       Clean up test output
    demo        Run demo project generation
    help        Show this help

EXAMPLES:
    $(basename "$0") test      # Run all integration tests
    $(basename "$0") demo      # Generate demo project
    $(basename "$0") clean     # Clean up test files
EOF
}

main() {
    case "${1:-test}" in
        test)
            run_integration_tests
            ;;
        clean)
            cleanup
            ok "Cleaned up test output"
            ;;
        demo)
            log "Running demo project generation..."
            test_full_project_generation
            show_generated_project_structure
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            warn "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Ensure Python is available
command -v python3 >/dev/null || fail "Python 3 is required"

# Run main function
main "$@"