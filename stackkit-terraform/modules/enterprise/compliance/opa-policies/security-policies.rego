# StackKit Security Policies - Open Policy Agent (OPA)
# Enterprise security controls for Infrastructure as Code

package stackkit.security

import future.keywords.in
import future.keywords.if
import future.keywords.every

# ==============================================================================
# TEAM BOUNDARY POLICIES
# ==============================================================================

# Team resource naming convention enforcement
team_resource_naming_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource_name := resource.name
    
    # Extract team from resource name or tags
    team := get_team_from_resource(resource)
    
    # Validate team prefix in resource name
    not startswith(resource_name, sprintf("%s-", [team]))
    
    msg := sprintf("Resource %s must be prefixed with team name '%s-'", [resource_name, team])
}

# Team resource access boundary validation
team_boundary_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_policy"
    
    policy_doc := json.unmarshal(resource.values.policy)
    statement := policy_doc.Statement[_]
    
    # Check for wildcard resource access
    statement.Resource == "*"
    
    # Get team context
    team := get_team_from_resource(resource)
    
    # Validate team has boundary policy applied
    not has_permission_boundary(resource, team)
    
    msg := sprintf("IAM policy %s for team %s must have permission boundary", [resource.name, team])
}

# Cross-team resource access validation
cross_team_access_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["aws_iam_role_policy", "aws_iam_policy"]
    
    policy_doc := json.unmarshal(resource.values.policy)
    statement := policy_doc.Statement[_]
    
    # Check for cross-team resource access
    resource_arn := statement.Resource[_]
    source_team := get_team_from_resource(resource)
    target_team := get_team_from_arn(resource_arn)
    
    source_team != target_team
    not is_approved_cross_team_access(source_team, target_team, resource_arn)
    
    msg := sprintf("Team %s attempting unauthorized access to %s team resource: %s", [source_team, target_team, resource_arn])
}

# ==============================================================================
# NETWORK SECURITY POLICIES  
# ==============================================================================

# Public ingress restriction
public_ingress_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    
    # Check for public ingress
    resource.values.type == "ingress"
    cidr_block := resource.values.cidr_blocks[_]
    cidr_block == "0.0.0.0/0"
    
    # Allow exceptions for ALB and specific approved services
    not is_alb_security_group(resource)
    not is_approved_public_service(resource)
    
    msg := sprintf("Security group rule %s allows public ingress access without approval", [resource.name])
}

# Unrestricted egress validation
unrestricted_egress_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    
    # Check for unrestricted egress
    resource.values.type == "egress"
    resource.values.from_port == 0
    resource.values.to_port == 0
    resource.values.protocol == "-1"
    cidr_block := resource.values.cidr_blocks[_]
    cidr_block == "0.0.0.0/0"
    
    # Require justification for unrestricted egress
    not has_egress_justification(resource)
    
    msg := sprintf("Security group rule %s has unrestricted egress without justification", [resource.name])
}

# Network ACL compliance validation
nacl_compliance_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_subnet"
    
    # Check if subnet has network ACL association
    not has_custom_nacl(resource)
    
    # Require custom NACLs for all subnets
    msg := sprintf("Subnet %s must have custom Network ACL for defense in depth", [resource.name])
}

# ==============================================================================
# ENCRYPTION POLICIES
# ==============================================================================

# S3 bucket encryption enforcement
s3_encryption_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    
    # Check for bucket encryption configuration
    not has_s3_encryption(resource)
    
    msg := sprintf("S3 bucket %s must have encryption enabled", [resource.name])
}

# EBS volume encryption enforcement
ebs_encryption_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ebs_volume"
    
    # Check for EBS encryption
    not resource.values.encrypted
    
    msg := sprintf("EBS volume %s must be encrypted", [resource.name])
}

# RDS encryption enforcement
rds_encryption_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_db_instance"
    
    # Check for RDS encryption
    not resource.values.storage_encrypted
    
    msg := sprintf("RDS instance %s must have storage encryption enabled", [resource.name])
}

# Secrets Manager encryption with KMS
secrets_encryption_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_secretsmanager_secret"
    
    # Check for KMS encryption
    not resource.values.kms_key_id
    
    msg := sprintf("Secrets Manager secret %s must use KMS encryption", [resource.name])
}

# ==============================================================================
# ACCESS CONTROL POLICIES
# ==============================================================================

# MFA requirement for privileged roles
mfa_requirement_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    
    # Check if role requires MFA for assume role
    assume_policy := json.unmarshal(resource.values.assume_role_policy)
    statement := assume_policy.Statement[_]
    
    # Validate MFA condition exists for privileged roles
    is_privileged_role(resource)
    not has_mfa_condition(statement)
    
    msg := sprintf("Privileged IAM role %s must require MFA", [resource.name])
}

# Administrative action approval requirement
admin_approval_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_policy"
    
    policy_doc := json.unmarshal(resource.values.policy)
    statement := policy_doc.Statement[_]
    
    # Check for administrative actions
    action := statement.Action[_]
    is_administrative_action(action)
    
    # Require approval condition
    not has_approval_condition(statement)
    
    msg := sprintf("Policy %s contains administrative action %s without approval requirement", [resource.name, action])
}

# Service account policy restrictions
service_account_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    
    # Check if this is a service account role (ECS, Lambda, etc.)
    is_service_account_role(resource)
    
    # Validate least privilege principles
    not follows_least_privilege(resource)
    
    msg := sprintf("Service account role %s violates least privilege principles", [resource.name])
}

# ==============================================================================
# COMPLIANCE POLICIES
# ==============================================================================

# SOC2 compliance validation
soc2_compliance_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    
    # Check for required SOC2 tags
    not has_required_soc2_tags(resource)
    
    msg := sprintf("Resource %s missing required SOC2 compliance tags", [resource.name])
}

# Data classification enforcement
data_classification_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    
    # Resources that store or process data
    resource.type in ["aws_s3_bucket", "aws_rds_instance", "aws_dynamodb_table"]
    
    # Check for data classification tags
    not has_data_classification(resource)
    
    msg := sprintf("Data resource %s must have data classification tags", [resource.name])
}

# Environment separation validation
environment_separation_violation[msg] {
    resource := input.planned_values.root_module.resources[_]
    
    # Check for environment tagging
    environment := get_environment_from_resource(resource)
    
    # Validate environment-specific restrictions
    violations := get_environment_violations(resource, environment)
    violation := violations[_]
    
    msg := sprintf("Resource %s violates environment separation: %s", [resource.name, violation])
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Extract team from resource name or tags
get_team_from_resource(resource) := team {
    # Try to get from tags first
    team := resource.values.tags.Team
}

get_team_from_resource(resource) := team {
    # Extract from resource name if no tag
    not resource.values.tags.Team
    name_parts := split(resource.name, "-")
    team := name_parts[1]  # Assuming format: stackkit-team-resource
}

# Extract team from ARN
get_team_from_arn(arn) := team {
    # Parse ARN for team identifier
    arn_parts := split(arn, ":")
    resource_part := arn_parts[5]
    resource_parts := split(resource_part, "/")
    resource_name := resource_parts[count(resource_parts) - 1]
    name_parts := split(resource_name, "-")
    team := name_parts[1]
}

# Check if resource has permission boundary
has_permission_boundary(resource, team) {
    resource.values.permissions_boundary
    contains(resource.values.permissions_boundary, sprintf("%s-Boundary", [title(team)]))
}

# Check approved cross-team access
is_approved_cross_team_access(source_team, target_team, resource_arn) {
    # Define approved cross-team access patterns
    approved_patterns := {
        "devops": ["*"],  # DevOps can access all resources
        "security": ["*"],  # Security can access all resources  
        "frontend": ["*shared*", "*common*"],  # Frontend can access shared resources
        "backend": ["*shared*", "*common*"]   # Backend can access shared resources
    }
    
    allowed_resources := approved_patterns[source_team]
    pattern := allowed_resources[_]
    glob.match(pattern, [], resource_arn)
}

# Check if security group belongs to ALB
is_alb_security_group(resource) {
    contains(resource.name, "alb")
}

# Check if service is approved for public access
is_approved_public_service(resource) {
    approved_services := ["alb", "cloudfront", "api-gateway"]
    service := approved_services[_]
    contains(resource.name, service)
}

# Check if resource has egress justification
has_egress_justification(resource) {
    resource.values.description
    contains(resource.values.description, "ALLOW_PUBLIC_EXEMPT")
}

# Check if subnet has custom NACL
has_custom_nacl(resource) {
    # This would need to check for aws_network_acl_association
    # or custom NACL attachment
    true  # Simplified for demonstration
}

# Check if S3 bucket has encryption
has_s3_encryption(resource) {
    # Check for aws_s3_bucket_server_side_encryption_configuration
    # This is simplified - real implementation would check for companion resources
    resource.values.server_side_encryption_configuration
}

# Check if role is privileged
is_privileged_role(resource) {
    privileged_indicators := ["admin", "root", "privileged", "security"]
    indicator := privileged_indicators[_]
    contains(lower(resource.name), indicator)
}

# Check if statement has MFA condition
has_mfa_condition(statement) {
    statement.Condition.Bool["aws:MultiFactorAuthPresent"] == "true"
}

# Check if action is administrative
is_administrative_action(action) {
    admin_actions := [
        "iam:CreateUser", "iam:DeleteUser", "iam:CreateRole", "iam:DeleteRole",
        "iam:AttachUserPolicy", "iam:DetachUserPolicy", "kms:CreateKey",
        "kms:ScheduleKeyDeletion", "s3:DeleteBucket", "rds:DeleteDBInstance"
    ]
    action in admin_actions
}

# Check if statement has approval condition
has_approval_condition(statement) {
    # Look for approval-based conditions
    statement.Condition.StringEquals["aws:PrincipalTag/ApprovalRequired"]
}

# Check if role is service account
is_service_account_role(resource) {
    service_principals := ["ecs-tasks.amazonaws.com", "lambda.amazonaws.com", "ec2.amazonaws.com"]
    assume_policy := json.unmarshal(resource.values.assume_role_policy)
    statement := assume_policy.Statement[_]
    statement.Principal.Service in service_principals
}

# Check least privilege compliance
follows_least_privilege(resource) {
    # Simplified check - real implementation would analyze attached policies
    not contains(resource.name, "admin")
    not contains(resource.name, "full")
}

# Check for required SOC2 tags
has_required_soc2_tags(resource) {
    required_tags := ["Environment", "DataClassification", "Owner", "Project"]
    every tag in required_tags {
        resource.values.tags[tag]
    }
}

# Check for data classification tags
has_data_classification(resource) {
    classification_levels := ["public", "internal", "confidential", "restricted"]
    resource.values.tags.DataClassification in classification_levels
}

# Get environment from resource
get_environment_from_resource(resource) := environment {
    environment := resource.values.tags.Environment
}

get_environment_from_resource(resource) := environment {
    not resource.values.tags.Environment
    # Extract from resource name
    name_parts := split(resource.name, "-")
    environment := name_parts[0]
}

# Get environment-specific violations
get_environment_violations(resource, environment) := violations {
    violations := []
    environment == "prod"
    # Production-specific checks would go here
}

get_environment_violations(resource, environment) := violations {
    violations := []
    environment != "prod"
    # Non-production checks would go here
}