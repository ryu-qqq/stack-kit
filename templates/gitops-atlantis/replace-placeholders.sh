#!/bin/bash

# Replace specific values with placeholders
echo "🔄 Replacing specific values with placeholders..."

# Account ID
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/646886795421/ACCOUNT_ID_PLACEHOLDER/g' {} \;

# Organization and project names
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/connectly-atlantis/PROJECT_NAME_PLACEHOLDER/g' {} \;

find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/connectly-shared-infra/REPO_NAME_PLACEHOLDER/g' {} \;

find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/connectly/ORG_NAME_PLACEHOLDER/g' {} \;

# GitHub usernames and orgs
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/ryu-qqq/GITHUB_USER_PLACEHOLDER/g' {} \;

# Email
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/platform@ORG_NAME_PLACEHOLDER\.com/OWNER_EMAIL_PLACEHOLDER/g' {} \;

# Specific resource names
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/prod-ORG_NAME_PLACEHOLDER-atlantis/ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER/g' {} \;

# VPC and subnet IDs
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/vpc-[a-z0-9]+/VPC_ID_PLACEHOLDER/g' {} \;

find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/subnet-[a-z0-9]+/SUBNET_ID_PLACEHOLDER/g' {} \;

# S3 bucket names
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/ORG_NAME_PLACEHOLDER-terraform-state-[0-9]+/TERRAFORM_STATE_BUCKET_PLACEHOLDER/g' {} \;

# ECR repository
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/ACCOUNT_ID_PLACEHOLDER\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com\/ORG_NAME_PLACEHOLDER\/atlantis/ECR_REPOSITORY_PLACEHOLDER/g' {} \;

# ALB DNS names
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/[a-z0-9-]+\.[a-z0-9-]+\.elb\.amazonaws\.com/ALB_DNS_PLACEHOLDER/g' {} \;

# EFS IDs
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/fs-[a-z0-9]+/EFS_ID_PLACEHOLDER/g' {} \;

# Certificate ARN
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's/arn:aws:acm:[a-z0-9-]+:ACCOUNT_ID_PLACEHOLDER:certificate\/[a-z0-9-]+/CERTIFICATE_ARN_PLACEHOLDER/g' {} \;

# Slack webhook
find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" \) \
  -exec sed -i '' 's|https://hooks\.slack\.com/services/[A-Z0-9/]+|SLACK_WEBHOOK_URL_PLACEHOLDER|g' {} \;

echo "✅ Placeholders replaced successfully!"