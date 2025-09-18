#!/bin/bash
set -e

# GitHub Actions용 AWS OIDC 설정 스크립트

echo "🔧 Setting up AWS OIDC for GitHub Actions..."

# Variables
AWS_ACCOUNT_ID="646886795421"
GITHUB_REPO="ryu-qqq/connectly-shared-infra"
ROLE_NAME="GitHubActionsAtlantisRole"

# Create trust policy
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Check if OIDC provider exists
echo "📋 Checking OIDC provider..."
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" 2>/dev/null; then
    echo "🔄 Creating OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ OIDC provider created successfully"
else
    echo "✅ OIDC provider already exists"
fi

# Check if role exists
echo "📋 Checking IAM role..."
if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
    echo "🔄 Creating IAM role..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for GitHub Actions to manage Atlantis infrastructure"
    echo "✅ IAM role created successfully"
else
    echo "✅ IAM role already exists"
    echo "🔄 Updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name $ROLE_NAME \
        --policy-document file:///tmp/trust-policy.json
fi

# Create and attach custom policy for Atlantis
cat > /tmp/atlantis-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "iam:*",
        "logs:*",
        "elasticloadbalancing:*",
        "secretsmanager:*",
        "efs:*",
        "application-autoscaling:*",
        "cloudwatch:*",
        "ecr:*",
        "s3:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_NAME="${ROLE_NAME}Policy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

# Check if policy exists
if ! aws iam get-policy --policy-arn $POLICY_ARN 2>/dev/null; then
    echo "🔄 Creating custom policy..."
    aws iam create-policy \
        --policy-name $POLICY_NAME \
        --policy-document file:///tmp/atlantis-policy.json \
        --description "Custom policy for Atlantis GitHub Actions"
    echo "✅ Custom policy created"
else
    echo "✅ Custom policy already exists"
    echo "🔄 Updating policy..."
    aws iam create-policy-version \
        --policy-arn $POLICY_ARN \
        --policy-document file:///tmp/atlantis-policy.json \
        --set-as-default
fi

# Attach policy to role
echo "🔄 Attaching policy to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN

# Clean up
rm -f /tmp/trust-policy.json /tmp/atlantis-policy.json

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Add this secret to your GitHub repository:"
echo "   AWS_ROLE_ARN = arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "2. Go to: https://github.com/${GITHUB_REPO}/settings/secrets/actions"
echo "3. Add the AWS_ROLE_ARN secret"
echo ""
echo "✅ Your GitHub Actions workflows are now ready to use!"
