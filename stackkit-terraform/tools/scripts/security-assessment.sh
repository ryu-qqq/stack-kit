#!/bin/bash

# StackKit Security Assessment Script
# Comprehensive security posture evaluation and validation

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$SECURITY_DIR")"
REPORT_DIR="$PROJECT_ROOT/claudedocs/security-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ASSESSMENT_REPORT="$REPORT_DIR/security-assessment-$TIMESTAMP.md"

# AWS CLI and tools validation
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI not found${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform not found${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${RED}❌ jq not found${NC}"; exit 1; }

# Create report directory
mkdir -p "$REPORT_DIR"

# Initialize report
cat > "$ASSESSMENT_REPORT" << 'EOF'
# StackKit Security Assessment Report

**Generated**: $(date)
**Assessment Type**: Automated Security Posture Evaluation
**Framework Version**: v1.0.0

## Executive Summary

This report provides a comprehensive security assessment of the StackKit infrastructure deployment, evaluating controls across access management, network security, secrets management, and compliance monitoring.

EOF

echo -e "${BLUE}🔍 StackKit Security Assessment Starting${NC}"
echo -e "${CYAN}📊 Report will be generated at: $ASSESSMENT_REPORT${NC}"

# Function: Print section header
print_section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
    echo -e "\n## $1\n" >> "$ASSESSMENT_REPORT"
}

# Function: Print test result
print_result() {
    local status="$1"
    local message="$2"
    local details="${3:-}"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✅ $message${NC}"
            echo "- ✅ **PASS**: $message" >> "$ASSESSMENT_REPORT"
            ;;
        "FAIL") 
            echo -e "${RED}❌ $message${NC}"
            echo "- ❌ **FAIL**: $message" >> "$ASSESSMENT_REPORT"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️ $message${NC}"
            echo "- ⚠️ **WARNING**: $message" >> "$ASSESSMENT_REPORT"
            ;;
        "INFO")
            echo -e "${CYAN}ℹ️ $message${NC}"
            echo "- ℹ️ **INFO**: $message" >> "$ASSESSMENT_REPORT"
            ;;
    esac
    
    if [[ -n "$details" ]]; then
        echo "  $details" >> "$ASSESSMENT_REPORT"
    fi
}

# Function: Check AWS connectivity
check_aws_connectivity() {
    print_section "AWS Connectivity and Permissions"
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
        print_result "PASS" "AWS connectivity established"
        print_result "INFO" "Account ID: $account_id"
        print_result "INFO" "User ARN: $user_arn"
    else
        print_result "FAIL" "AWS connectivity failed - check credentials"
        return 1
    fi
}

# Function: Assess team boundary implementation
assess_team_boundaries() {
    print_section "Team Boundary Assessment"
    
    local team_roles_count=0
    local boundary_policies_count=0
    
    # Check for team roles
    if aws iam list-roles --path-prefix "/teams/" >/dev/null 2>&1; then
        team_roles_count=$(aws iam list-roles --path-prefix "/teams/" --query 'length(Roles)' --output text)
        if [[ "$team_roles_count" -gt 0 ]]; then
            print_result "PASS" "Team roles configured ($team_roles_count roles found)"
        else
            print_result "WARN" "No team roles found in /teams/ path"
        fi
    else
        print_result "FAIL" "Unable to list team roles"
    fi
    
    # Check for boundary policies  
    if aws iam list-policies --path-prefix "/teams/" >/dev/null 2>&1; then
        boundary_policies_count=$(aws iam list-policies --path-prefix "/teams/" --query 'length(Policies)' --output text)
        if [[ "$boundary_policies_count" -gt 0 ]]; then
            print_result "PASS" "Team boundary policies configured ($boundary_policies_count policies found)"
        else
            print_result "WARN" "No team boundary policies found"
        fi
    fi
    
    # Check MFA enforcement
    local mfa_policies=$(aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `MFA`)]' --output text 2>/dev/null | wc -l)
    if [[ "$mfa_policies" -gt 0 ]]; then
        print_result "PASS" "MFA enforcement policies detected"
    else
        print_result "WARN" "No MFA enforcement policies found"
    fi
}

# Function: Assess secrets management
assess_secrets_management() {
    print_section "Secrets Management Assessment"
    
    # Check for StackKit secrets
    local stackkit_secrets=$(aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name, `stackkit/`)]' --output json 2>/dev/null)
    local secrets_count=$(echo "$stackkit_secrets" | jq '. | length')
    
    if [[ "$secrets_count" -gt 0 ]]; then
        print_result "PASS" "StackKit secrets configured ($secrets_count secrets found)"
        
        # Check for KMS encryption
        local encrypted_secrets=$(echo "$stackkit_secrets" | jq '[.[] | select(.KmsKeyId != null)] | length')
        if [[ "$encrypted_secrets" == "$secrets_count" ]]; then
            print_result "PASS" "All secrets encrypted with KMS"
        else
            print_result "WARN" "Some secrets not encrypted with KMS ($encrypted_secrets/$secrets_count)"
        fi
        
        # Check for cross-region replication
        local replicated_secrets=$(echo "$stackkit_secrets" | jq '[.[] | select(.ReplicationStatus != null)] | length')
        if [[ "$replicated_secrets" -gt 0 ]]; then
            print_result "PASS" "Cross-region replication configured for $replicated_secrets secrets"
        else
            print_result "WARN" "No cross-region replication detected"
        fi
    else
        print_result "WARN" "No StackKit secrets found"
    fi
    
    # Check for rotation configuration
    local lambda_functions=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `rotation`)]' --output json 2>/dev/null)
    local rotation_functions_count=$(echo "$lambda_functions" | jq '. | length')
    
    if [[ "$rotation_functions_count" -gt 0 ]]; then
        print_result "PASS" "Secret rotation functions deployed ($rotation_functions_count functions)"
    else
        print_result "WARN" "No rotation functions found"
    fi
}

# Function: Assess network security
assess_network_security() {
    print_section "Network Security Assessment"
    
    # Check for VPC configuration
    local vpcs=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=StackKit" --query 'Vpcs' --output json 2>/dev/null)
    local vpc_count=$(echo "$vpcs" | jq '. | length')
    
    if [[ "$vpc_count" -gt 0 ]]; then
        print_result "PASS" "StackKit VPC configuration found"
        
        local vpc_id=$(echo "$vpcs" | jq -r '.[0].VpcId')
        
        # Check for VPC Flow Logs
        local flow_logs=$(aws ec2 describe-flow-logs --filters "Name=resource-id,Values=$vpc_id" --query 'FlowLogs' --output json 2>/dev/null)
        local flow_logs_count=$(echo "$flow_logs" | jq '. | length')
        
        if [[ "$flow_logs_count" -gt 0 ]]; then
            print_result "PASS" "VPC Flow Logs enabled"
        else
            print_result "FAIL" "VPC Flow Logs not configured"
        fi
        
        # Check for custom NACLs
        local nacls=$(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$vpc_id" "Name=default,Values=false" --query 'NetworkAcls' --output json 2>/dev/null)
        local custom_nacls_count=$(echo "$nacls" | jq '. | length')
        
        if [[ "$custom_nacls_count" -gt 0 ]]; then
            print_result "PASS" "Custom Network ACLs configured ($custom_nacls_count NACLs)"
        else
            print_result "WARN" "No custom Network ACLs found"
        fi
        
        # Check security groups
        local security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:ManagedBy,Values=StackKit*" --query 'SecurityGroups' --output json 2>/dev/null)
        local sg_count=$(echo "$security_groups" | jq '. | length')
        
        if [[ "$sg_count" -gt 0 ]]; then
            print_result "PASS" "StackKit security groups configured ($sg_count groups)"
            
            # Check for unrestricted ingress
            local unrestricted_ingress=$(echo "$security_groups" | jq '[.[] | select(.IpPermissions[] | .IpRanges[] | select(.CidrIp == "0.0.0.0/0"))] | length')
            if [[ "$unrestricted_ingress" -gt 0 ]]; then
                print_result "WARN" "Some security groups allow unrestricted ingress ($unrestricted_ingress groups)"
            else
                print_result "PASS" "No unrestricted ingress rules detected"
            fi
        else
            print_result "WARN" "No StackKit-managed security groups found"
        fi
    else
        print_result "INFO" "No StackKit VPC found - may be using existing infrastructure"
    fi
}

# Function: Assess compliance monitoring
assess_compliance_monitoring() {
    print_section "Compliance Monitoring Assessment"
    
    # Check AWS Config
    local config_recorders=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders' --output json 2>/dev/null)
    local recorder_count=$(echo "$config_recorders" | jq '. | length')
    
    if [[ "$recorder_count" -gt 0 ]]; then
        print_result "PASS" "AWS Config recorders configured ($recorder_count recorders)"
        
        # Check if recorders are recording
        local recorder_status=$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
        if [[ "$recorder_status" == "true" ]]; then
            print_result "PASS" "Configuration recording is active"
        else
            print_result "FAIL" "Configuration recording is not active"
        fi
    else
        print_result "WARN" "No AWS Config recorders found"
    fi
    
    # Check Config Rules
    local config_rules=$(aws configservice describe-config-rules --query 'ConfigRules[?starts_with(ConfigRuleName, `stackkit`)]' --output json 2>/dev/null)
    local rules_count=$(echo "$config_rules" | jq '. | length')
    
    if [[ "$rules_count" -gt 0 ]]; then
        print_result "PASS" "StackKit Config rules deployed ($rules_count rules)"
    else
        print_result "WARN" "No StackKit Config rules found"
    fi
    
    # Check Security Hub
    if aws securityhub get-enabled-standards >/dev/null 2>&1; then
        print_result "PASS" "AWS Security Hub enabled"
        
        local enabled_standards=$(aws securityhub get-enabled-standards --query 'length(StandardsSubscriptions)' --output text 2>/dev/null)
        print_result "INFO" "Security Hub standards enabled: $enabled_standards"
    else
        print_result "WARN" "AWS Security Hub not enabled"
    fi
    
    # Check GuardDuty
    local guardduty_detectors=$(aws guardduty list-detectors --query 'DetectorIds' --output json 2>/dev/null)
    local detector_count=$(echo "$guardduty_detectors" | jq '. | length')
    
    if [[ "$detector_count" -gt 0 ]]; then
        print_result "PASS" "GuardDuty enabled ($detector_count detectors)"
    else
        print_result "WARN" "GuardDuty not enabled"
    fi
}

# Function: Check Terraform security implementation
check_terraform_security() {
    print_section "Terraform Security Implementation"
    
    cd "$SECURITY_DIR"
    
    # Validate Terraform configuration
    if terraform validate >/dev/null 2>&1; then
        print_result "PASS" "Terraform configuration is valid"
    else
        print_result "FAIL" "Terraform configuration validation failed"
    fi
    
    # Check for security modules
    local security_modules=("iam" "secrets" "network" "compliance")
    for module in "${security_modules[@]}"; do
        if [[ -d "$module" ]]; then
            print_result "PASS" "Security module '$module' present"
        else
            print_result "FAIL" "Security module '$module' missing"
        fi
    done
    
    # Check for OPA policies
    if [[ -f "compliance/opa-policies/security-policies.rego" ]]; then
        print_result "PASS" "OPA security policies configured"
    else
        print_result "WARN" "OPA security policies not found"
    fi
    
    cd "$PROJECT_ROOT"
}

# Function: Generate security score
generate_security_score() {
    print_section "Security Score Assessment"
    
    local total_checks=0
    local passed_checks=0
    
    # Count results from the report
    total_checks=$(grep -c "^\- [✅❌⚠️]" "$ASSESSMENT_REPORT" 2>/dev/null || echo 0)
    passed_checks=$(grep -c "^\- ✅" "$ASSESSMENT_REPORT" 2>/dev/null || echo 0)
    
    if [[ "$total_checks" -gt 0 ]]; then
        local score=$((passed_checks * 100 / total_checks))
        print_result "INFO" "Security Score: $score/100 ($passed_checks/$total_checks checks passed)"
        
        # Score interpretation
        if [[ "$score" -ge 90 ]]; then
            print_result "PASS" "Security posture: EXCELLENT (Enterprise Grade)"
        elif [[ "$score" -ge 80 ]]; then
            print_result "PASS" "Security posture: GOOD (Production Ready)"
        elif [[ "$score" -ge 70 ]]; then
            print_result "WARN" "Security posture: FAIR (Improvements Needed)"
        else
            print_result "FAIL" "Security posture: POOR (Critical Issues)"
        fi
    else
        print_result "WARN" "Unable to calculate security score"
    fi
}

# Function: Generate recommendations
generate_recommendations() {
    print_section "Security Recommendations"
    
    echo "" >> "$ASSESSMENT_REPORT"
    echo "### Priority Actions" >> "$ASSESSMENT_REPORT"
    echo "" >> "$ASSESSMENT_REPORT"
    
    # Extract failed and warning items for recommendations
    local failures=$(grep "^\- ❌" "$ASSESSMENT_REPORT" 2>/dev/null | wc -l)
    local warnings=$(grep "^\- ⚠️" "$ASSESSMENT_REPORT" 2>/dev/null | wc -l)
    
    if [[ "$failures" -gt 0 ]]; then
        echo "**🔴 Critical Issues ($failures items)**:" >> "$ASSESSMENT_REPORT"
        echo "- Address all failed security controls immediately" >> "$ASSESSMENT_REPORT"
        echo "- Review and remediate configuration issues" >> "$ASSESSMENT_REPORT"
        echo "" >> "$ASSESSMENT_REPORT"
    fi
    
    if [[ "$warnings" -gt 0 ]]; then
        echo "**🟡 Improvement Opportunities ($warnings items)**:" >> "$ASSESSMENT_REPORT"
        echo "- Enhance security controls for defense in depth" >> "$ASSESSMENT_REPORT"
        echo "- Consider implementing additional monitoring" >> "$ASSESSMENT_REPORT"
        echo "" >> "$ASSESSMENT_REPORT"
    fi
    
    echo "### Next Steps" >> "$ASSESSMENT_REPORT"
    echo "" >> "$ASSESSMENT_REPORT"
    echo "1. **Immediate (24 hours)**: Address all critical failures" >> "$ASSESSMENT_REPORT"
    echo "2. **Short-term (1 week)**: Implement warning-level improvements" >> "$ASSESSMENT_REPORT"
    echo "3. **Medium-term (1 month)**: Establish ongoing security monitoring" >> "$ASSESSMENT_REPORT"
    echo "4. **Long-term (quarterly)**: Regular security assessments and updates" >> "$ASSESSMENT_REPORT"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting StackKit Security Assessment${NC}"
    echo -e "${CYAN}📅 $(date)${NC}\n"
    
    # Update report with current timestamp
    sed -i.bak "s/\*\*Generated\*\*:.*/\*\*Generated\*\*: $(date)/g" "$ASSESSMENT_REPORT"
    
    # Run assessment functions
    check_aws_connectivity || exit 1
    assess_team_boundaries
    assess_secrets_management  
    assess_network_security
    assess_compliance_monitoring
    check_terraform_security
    generate_security_score
    generate_recommendations
    
    echo -e "\n${GREEN}✅ Security assessment completed${NC}"
    echo -e "${CYAN}📊 Report generated: $ASSESSMENT_REPORT${NC}"
    
    # Append completion timestamp
    echo "" >> "$ASSESSMENT_REPORT"
    echo "---" >> "$ASSESSMENT_REPORT"
    echo "" >> "$ASSESSMENT_REPORT"
    echo "*Assessment completed at $(date)*" >> "$ASSESSMENT_REPORT"
    echo "*Report generated by StackKit Security Assessment v1.0.0*" >> "$ASSESSMENT_REPORT"
    
    # Clean up backup file
    rm -f "${ASSESSMENT_REPORT}.bak"
    
    echo -e "\n${PURPLE}📋 Assessment Summary${NC}"
    echo -e "${CYAN}Report location: $ASSESSMENT_REPORT${NC}"
    echo -e "${CYAN}Use: cat '$ASSESSMENT_REPORT' | head -50${NC} to view summary"
}

# Handle script termination
cleanup() {
    echo -e "\n${YELLOW}⚠️ Assessment interrupted${NC}"
    if [[ -f "${ASSESSMENT_REPORT}.bak" ]]; then
        rm -f "${ASSESSMENT_REPORT}.bak"
    fi
    exit 1
}

trap cleanup SIGINT SIGTERM

# Execute main function
main "$@"