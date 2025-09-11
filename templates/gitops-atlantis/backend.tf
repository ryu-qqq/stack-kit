terraform {
  backend "s3" {
    bucket         = "TERRAFORM_STATE_BUCKET_PLACEHOLDER"
    key            = "gitops/atlantis/terraform.tfstate"
    region         = "REGION_PLACEHOLDER"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}