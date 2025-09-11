# PROJECT_NAME_PLACEHOLDER Infrastructure

Infrastructure as Code for the PROJECT_NAME_PLACEHOLDER project using StackKit v2 GitOps Atlantis template.

## Project Information
- **Team**: TEAM_NAME_PLACEHOLDER
- **Organization**: ORG_NAME_PLACEHOLDER
- **Template**: gitops-atlantis
- **Environments**: dev,staging,prod

## Quick Start

```bash
# Validate configuration
terraform validate

# Plan changes
terraform plan -var-file=terraform.tfvars.example

# Apply changes (via Atlantis in production)
terraform apply -var-file=terraform.tfvars.example
```

## Directory Structure

```
.
├── atlantis.yaml             # Atlantis configuration with enhanced features
├── terraform.tfvars.example  # Example variables configuration
├── variables.tf              # Variable definitions (47+ StackKit standard variables)
├── locals.tf                 # Computed local values
├── main.tf                   # Provider configuration
├── data.tf                   # Data sources
├── networking.tf             # VPC, subnets, security groups
├── security.tf               # IAM roles, policies, secrets
├── compute.tf                # ECS cluster, services, auto-scaling
├── load_balancer.tf          # ALB, target groups, listeners
├── storage.tf                # EFS, S3, DynamoDB
├── outputs.tf                # Output values
├── environments/             # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── scripts/
    └── connect.sh            # Repository connection script
```

## StackKit GitOps Atlantis Features

This template includes enhanced Atlantis configuration with enterprise-grade features:

### 🔍 Enhanced Analysis
- **Resource Change Analysis** - Detailed plan analysis with resource counts
- **Cost Impact Assessment** - Infracost integration for monthly cost estimation
- **Security Validation** - Automated checks for common security issues
- **Rich Reporting** - Comprehensive logging and debugging information

### 💬 Communication & Notifications
- **Slack Integration** - Rich notifications with structured messages
- **GitHub Comments** - Automated Infracost cost breakdown comments
- **Status Updates** - Real-time plan and apply status notifications
- **Error Reporting** - Detailed error information with debugging context

### 🛡️ Security & Governance
- **Manual Approval** - Required approval before infrastructure changes
- **Branch Protection** - Configured webhook events for safe operations
- **Secret Management** - Secure webhook secret handling
- **Audit Trail** - Complete tracking of infrastructure changes

## Repository Connection

To connect this repository to your Atlantis server, use the included connection script:

```bash
# Basic connection
./scripts/connect.sh \
  --atlantis-url https://atlantis.your-company.com \
  --repo-name ORG_NAME_PLACEHOLDER/PROJECT_NAME_PLACEHOLDER \
  --github-token ghp_your_token

# Full featured connection with notifications and cost analysis
./scripts/connect.sh \
  --atlantis-url https://atlantis.your-company.com \
  --repo-name ORG_NAME_PLACEHOLDER/PROJECT_NAME_PLACEHOLDER \
  --github-token ghp_your_token \
  --slack-webhook https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  --infracost-key ico_your_infracost_key \
  --environment prod
```

The connection script will automatically:
- ✅ **Setup GitHub Webhooks** - Configure repository webhooks for Atlantis events
- ✅ **Configure Repository Variables** - Set GitHub repository variables for integrations
- ✅ **Update Project Settings** - Customize atlantis.yaml for your project
- ✅ **Verify Configuration** - Validate StackKit project structure

## Atlantis Workflow

### 1. Development Workflow
1. **Create Feature Branch**: `git checkout -b feature/your-feature`
2. **Modify Infrastructure**: Update `.tf` files as needed
3. **Create Pull Request**: Atlantis automatically runs `terraform plan`
4. **Review Changes**: Review plan output, cost analysis, and security checks
5. **Approve PR**: Get team approval for infrastructure changes
6. **Apply Changes**: Run `atlantis apply` to deploy infrastructure

### 2. Notifications & Monitoring
- **Plan Notifications**: Slack alerts with resource counts and cost estimates
- **Apply Notifications**: Success/failure notifications with deployment details
- **Cost Tracking**: Infracost integration provides cost impact for every change
- **Security Alerts**: Automated warnings for potential security issues

### 3. Available Commands
```bash
# Plan infrastructure changes
atlantis plan

# Apply approved changes  
atlantis apply

# Unlock repository if needed
atlantis unlock

# Get help
atlantis help
```

## Configuration

### Required Environment Variables (Atlantis Server)
```bash
# GitHub Integration
ATLANTIS_GH_TOKEN=ghp_your_github_token_with_repo_access

# Optional: Enhanced Features
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
INFRACOST_API_KEY=ico_your_infracost_api_key
```

### Project Variables (Set by connect.sh)
These are automatically configured by the connection script:
- `ATLANTIS_WEBHOOK_SECRET` - Secure webhook authentication
- `AWS_REGION` - Target AWS region for deployment
- `PROJECT_NAME` - Project identifier for resources
- `ENVIRONMENT` - Target environment (dev/staging/prod)
- `SLACK_WEBHOOK_URL` - Slack notifications endpoint (if provided)
- `INFRACOST_API_KEY` - Cost analysis API key (if provided)

## Customization

### Terraform Variables
Update `terraform.tfvars.example` with your project-specific values:
```hcl
# Project Metadata
project_name = "PROJECT_NAME_PLACEHOLDER"
team         = "TEAM_NAME_PLACEHOLDER" 
organization = "ORG_NAME_PLACEHOLDER"
environment  = "prod"

# AWS Configuration
aws_region = "REGION_PLACEHOLDER"

# Atlantis Configuration  
atlantis_host = "atlantis.ORG_NAME_PLACEHOLDER.com"
atlantis_repo_allowlist = "github.com/ORG_NAME_PLACEHOLDER/*"
```

### Atlantis Configuration
The `atlantis.yaml` file includes the `stackkit-enhanced` workflow with:
- Enhanced plan analysis with resource counting
- Infracost integration for cost estimation
- Basic security validation
- Slack notifications with rich formatting
- Automatic cleanup of temporary files
- Comprehensive error handling

## Troubleshooting

### Common Issues
1. **Webhook Not Triggering**
   - Verify webhook URL is accessible from GitHub
   - Check webhook secret matches in both GitHub and Atlantis
   - Ensure GitHub token has `repo` permissions

2. **Plan Failures** 
   - Check AWS credentials and permissions
   - Verify Terraform backend configuration
   - Review variable validation errors

3. **Cost Analysis Missing**
   - Verify `INFRACOST_API_KEY` is set correctly
   - Check infracost binary is available in Atlantis container
   - Review infracost configuration and API limits

4. **Slack Notifications Not Working**
   - Verify `SLACK_WEBHOOK_URL` is correct
   - Test webhook URL manually with curl
   - Check Slack app permissions

### Debug Mode
Enable verbose logging by setting environment variables:
```bash
# In Atlantis server configuration
ATLANTIS_LOG_LEVEL=debug
TF_LOG=DEBUG
```

## Documentation

- [StackKit v2 Documentation](https://github.com/company/stackkit-terraform-modules)
- [Atlantis Documentation](https://www.runatlantis.io/)
- [Infracost Documentation](https://www.infracost.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

## Support

For issues and questions:
- 📚 [StackKit Documentation](https://github.com/company/stackkit-terraform-modules)
- 🐛 [Report Issues](https://github.com/company/stackkit-terraform-modules/issues)
- 💬 Team Slack: #infrastructure

---

Generated by StackKit v2 CLI with Enhanced GitOps Atlantis Template
🚀 Enterprise-ready infrastructure automation with cost analysis and notifications