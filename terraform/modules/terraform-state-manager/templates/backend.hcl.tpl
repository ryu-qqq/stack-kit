# Terraform Backend Configuration for StackKit Infrastructure
# Generated automatically by terraform-state-manager module

terraform {
  backend "s3" {
    bucket         = "${bucket}"
    key            = "terraform.tfstate"  # Override this for each stack
    region         = "${region}"
    dynamodb_table = "${dynamodb_table}"
    encrypt        = true
    %{ if kms_key_id != null ~}
    kms_key_id     = "${kms_key_id}"
    %{ endif ~}
  }
}

# Usage Instructions:
# 1. Copy this configuration to your Terraform stack
# 2. Update the 'key' value to be unique for your stack (e.g., "stacks/web-app/terraform.tfstate")
# 3. Run 'terraform init' to configure the backend