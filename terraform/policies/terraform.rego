# OPA Conftest Policy for GUIDE.md Terraform Enforcement
# Policy as Code implementation of GUIDE.md rules

package terraform.analysis

import rego.v1

# GUIDE.md Rule: No backend blocks in modules
deny contains msg if {
    input.resource_changes
    some i
    resource := input.resource_changes[i]
    contains(resource.address, "module.")
    
    # Check if this is a backend configuration in a module
    file_path := resource.provider_config_key
    contains(file_path, "infra/modules/")
    
    msg := sprintf("GUIDE.md VIOLATION: Backend configuration found in module at %s. Move backend to stack level.", [file_path])
}

# GUIDE.md Rule: No provider blocks in modules  
deny contains msg if {
    input.configuration.provider_config
    some provider_key
    provider := input.configuration.provider_config[provider_key]
    
    # Check if provider is defined in a module
    contains(provider.module_address, "module.")
    
    msg := sprintf("GUIDE.md VIOLATION: Provider block found in module %s. Remove provider from modules.", [provider.module_address])
}

# GUIDE.md Rule: No data aws_* name lookups (specific to problematic ones)
deny contains msg if {
    input.configuration.root_module.data
    some resource_type
    some resource_name
    resource := input.configuration.root_module.data[resource_type][resource_name]
    
    # Check for problematic data sources that require List permissions
    prohibited_types := [
        "aws_sqs_queue",
        "aws_sns_topic", 
        "aws_sqs_queues",
        "aws_sns_topics"
    ]
    
    resource_type in prohibited_types
    
    msg := sprintf("GUIDE.md VIOLATION: Prohibited data source %s.%s found. Use remote_state or variables instead.", [resource_type, resource_name])
}

# GUIDE.md Rule: No terraform.workspace usage
deny contains msg if {
    input.configuration
    contains(sprintf("%v", [input.configuration]), "terraform.workspace")
    
    msg := "GUIDE.md VIOLATION: terraform.workspace usage detected. Use environment directories instead of workspaces."
}

# GUIDE.md Rule: Required tags on resources
deny contains msg if {
    input.planned_values.root_module.resources
    some i
    resource := input.planned_values.root_module.resources[i]
    
    # Resources that should have tags
    taggable_types := [
        "aws_instance",
        "aws_s3_bucket", 
        "aws_vpc",
        "aws_subnet",
        "aws_security_group",
        "aws_lb",
        "aws_ecs_cluster",
        "aws_ecs_service",
        "aws_lambda_function",
        "aws_sqs_queue",
        "aws_sns_topic",
        "aws_dynamodb_table",
        "aws_rds_instance",
        "aws_elasticache_cluster"
    ]
    
    resource.type in taggable_types
    
    # Check for required tags
    required_tags := ["Environment", "Project", "Component", "ManagedBy"]
    some tag
    tag in required_tags
    not resource.values.tags[tag]
    
    msg := sprintf("GUIDE.md VIOLATION: Required tag '%s' missing on %s.%s", [tag, resource.type, resource.name])
}

# GUIDE.md Rule: Standard naming convention
deny contains msg if {
    input.planned_values.root_module.resources
    some i
    resource := input.planned_values.root_module.resources[i]
    
    # Check naming pattern: environment-component-purpose
    name := resource.values.name
    name != null
    
    # Skip data sources and computed names
    not startswith(resource.address, "data.")
    not contains(name, "$")  # Skip interpolated names
    
    # Must contain environment prefix
    env_patterns := ["prod-", "dev-", "staging-"]
    not some pattern in env_patterns
    startswith(name, pattern)
    
    msg := sprintf("GUIDE.md VIOLATION: Resource name '%s' doesn't follow naming convention (environment-component-purpose)", [name])
}

# GUIDE.md Rule: No hardcoded regions outside variables
deny contains msg if {
    input.configuration.root_module.variables.aws_region
    
    # Check for hardcoded regions in resource configurations
    walk(input.configuration, [path, value])
    
    # Look for hardcoded AWS regions
    is_string(value)
    region_pattern := "^(us|eu|ap|sa|ca|af|me)-(north|south|east|west|central|northeast|northwest|southeast|southwest)-[0-9]$"
    regex.match(region_pattern, value)
    
    # Skip if it's in variables or data sources
    not contains(sprintf("%v", path), "variables")
    not contains(sprintf("%v", path), "data")
    
    msg := sprintf("GUIDE.md VIOLATION: Hardcoded region '%s' found at path %v. Use var.aws_region instead.", [value, path])
}

# GUIDE.md Rule: Module source should be local paths for internal modules
deny contains msg if {
    input.configuration.root_module.module_calls
    some module_name
    module_call := input.configuration.root_module.module_calls[module_name]
    
    # Check for external module sources when internal should be used
    source := module_call.source
    
    # Internal modules should use relative paths
    not startswith(source, "./")
    not startswith(source, "../")
    contains(source, "/modules/")
    
    msg := sprintf("GUIDE.md VIOLATION: Module '%s' source '%s' should use relative path for internal modules.", [module_name, source])
}

# Helper function to check if a resource is in a module
is_in_module(address) if {
    contains(address, "module.")
}

# Helper function to validate environment values
valid_environments := ["prod", "dev", "staging"]

is_valid_environment(env) if {
    env in valid_environments
}

# GUIDE.md Rule: Environment variable validation
warn contains msg if {
    input.configuration.root_module.variables.environment
    env_var := input.configuration.root_module.variables.environment
    
    env_var.default
    not is_valid_environment(env_var.default)
    
    msg := sprintf("GUIDE.md WARNING: Environment default value '%s' is not in approved list: %v", [env_var.default, valid_environments])
}

# GUIDE.md Rule: Required files structure validation (example)
warn contains msg if {
    # This would need to be implemented with file system checks
    # For now, just a placeholder for the concept
    
    # Check if required outputs are defined
    not input.configuration.root_module.outputs
    
    msg := "GUIDE.md WARNING: No outputs defined. Add outputs.tf file per GUIDE.md standards."
}