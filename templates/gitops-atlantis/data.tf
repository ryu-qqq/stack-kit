# =======================================
# Data Sources for Shared Infrastructure
# =======================================

# GitHub Token from Secrets Manager (secure approach)
data "aws_secretsmanager_secret" "github_token" {
  name = "atlantis/github-token"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

# Current AWS Account ID
data "aws_caller_identity" "current" {}

# Current AWS Region
data "aws_region" "current" {}

# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

