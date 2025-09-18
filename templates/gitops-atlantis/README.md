# GitOps Atlantis MVP Template

A simplified, production-ready GitOps infrastructure template using Atlantis for Terraform automation.

## 🎯 Template Overview

This MVP template provides a streamlined GitOps setup with:
- **Atlantis** for Terraform automation via pull requests
- **AWS ECS Fargate** for container orchestration
- **GitHub Actions** with OIDC authentication
- **Application Load Balancer** with health checks
- **ECR** for container image management
- **CloudWatch** for logging and monitoring

## 📋 Prerequisites

1. **AWS Account** with administrative access
2. **GitHub Repository** for your infrastructure code
3. **Domain** for Atlantis web interface (optional but recommended)
4. **GitHub Token** with repository access permissions

## 🔧 Setup Instructions

### 1. Replace Placeholders

Run the placeholder replacement script to customize for your environment:

```bash
# Update placeholders in the script first
vim replace-placeholders.sh

# Execute replacement
./replace-placeholders.sh
```

### 2. Required Placeholder Values

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `ACCOUNT_ID_PLACEHOLDER` | Your AWS Account ID | `123456789012` |
| `ORG_NAME_PLACEHOLDER` | Your organization name | `mycompany` |
| `PROJECT_NAME_PLACEHOLDER` | Your project name | `myproject-atlantis` |
| `REPO_NAME_PLACEHOLDER` | Your repository name | `infrastructure` |
| `GITHUB_USER_PLACEHOLDER` | Your GitHub username | `myusername` |
| `OWNER_EMAIL_PLACEHOLDER` | Infrastructure owner email | `ops@mycompany.com` |
| `VPC_ID_PLACEHOLDER` | Your VPC ID | `vpc-abc123def` |
| `SUBNET_ID_PLACEHOLDER` | Your subnet IDs | `subnet-abc123,subnet-def456` |
| `TERRAFORM_STATE_BUCKET_PLACEHOLDER` | S3 bucket for Terraform state | `mycompany-terraform-state-bucket` |
| `ECR_REPOSITORY_PLACEHOLDER` | ECR repository URL | `123456789012.dkr.ecr.us-east-1.amazonaws.com/mycompany/atlantis` |
| `ALB_DNS_PLACEHOLDER` | ALB DNS name | `myproject-alb-123456789.us-east-1.elb.amazonaws.com` |
| `EFS_ID_PLACEHOLDER` | EFS file system ID | `fs-abc123def` |
| `CERTIFICATE_ARN_PLACEHOLDER` | SSL certificate ARN | `arn:aws:acm:us-east-1:123456789012:certificate/abc123def` |
| `SLACK_WEBHOOK_URL_PLACEHOLDER` | Slack webhook URL | `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX` |

### 3. Infrastructure Components

The template includes:

- **ECS Cluster**: Fargate-based container orchestration
- **Application Load Balancer**: Public-facing load balancer with health checks
- **Security Groups**: Properly configured network security
- **CloudWatch**: Comprehensive logging and monitoring
- **ECR Repository**: Container image storage with lifecycle policies
- **GitHub Actions**: Automated deployment pipeline

### 4. Deployment Steps

1. **Prepare AWS Infrastructure**:
   ```bash
   # Create S3 bucket for Terraform state
   aws s3 mb s3://TERRAFORM_STATE_BUCKET_PLACEHOLDER

   # Create ECR repository
   aws ecr create-repository --repository-name ORG_NAME_PLACEHOLDER/atlantis
   ```

2. **Configure GitHub Secrets**:
   - `AWS_ACCOUNT_ID`: Your AWS account ID
   - `AWS_REGION`: Your preferred AWS region
   - `ATLANTIS_GITHUB_TOKEN`: GitHub token for Atlantis

3. **Deploy Infrastructure**:
   ```bash
   # Initialize Terraform
   terraform init

   # Plan deployment
   terraform plan

   # Apply infrastructure
   terraform apply
   ```

4. **Deploy Atlantis Container**:
   - Push changes to main branch
   - GitHub Actions will build and deploy automatically

### 5. Configuration

#### Atlantis Configuration (`atlantis.yaml`)
```yaml
version: 3
projects:
- name: infrastructure
  dir: .
  terraform_version: v1.5.0
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
  apply_requirements: ["approved", "mergeable"]
```

#### Environment Variables
Key environment variables configured in ECS:
- `ATLANTIS_GITHUB_USER`: GitHub username
- `ATLANTIS_GITHUB_TOKEN`: GitHub token
- `ATLANTIS_REPO_ALLOWLIST`: Allowed repositories
- `ATLANTIS_ATLANTIS_URL`: Atlantis web interface URL

## 🔒 Security Features

- **OIDC Authentication**: Passwordless GitHub Actions authentication
- **IAM Roles**: Principle of least privilege
- **Security Groups**: Restricted network access
- **Private Subnets**: ECS tasks run in private subnets
- **Secrets Management**: Sensitive data stored in AWS Secrets Manager

## 💰 Cost Estimation

Estimated monthly costs:
- **ECS Fargate**: $15-25 (0.25 vCPU, 0.5 GB RAM)
- **Application Load Balancer**: $16
- **CloudWatch Logs**: $1-3
- **ECR Storage**: $0.10/GB
- **Data Transfer**: $2-5

**Total**: ~$35-55/month

## 🔧 Customization

### Scaling Configuration
Modify `ecs.tf` to adjust:
- CPU and memory allocation
- Auto-scaling parameters
- Health check settings

### Monitoring Enhancement
Add custom CloudWatch alarms in `monitoring.tf`:
- Memory utilization alerts
- Error rate monitoring
- Custom application metrics

### Security Hardening
Additional security measures:
- WAF integration
- VPC Flow Logs
- GuardDuty enablement

## 📊 Monitoring & Troubleshooting

### Health Checks
- **ALB Health Check**: `/healthz` endpoint
- **ECS Health Check**: Container health monitoring
- **CloudWatch Metrics**: CPU, memory, network utilization

### Common Issues
1. **Deployment Failures**: Check CloudWatch logs
2. **Health Check Failures**: Verify application startup
3. **GitHub Integration**: Validate webhook configuration

### Useful Commands
```bash
# Check ECS service status
aws ecs describe-services --cluster ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER-cluster --services ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER-service

# View logs
aws logs tail /ecs/ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER --follow

# Restart service
aws ecs update-service --cluster ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER-cluster --service ENV_PLACEHOLDER-PROJECT_NAME_PLACEHOLDER-service --force-new-deployment
```

## 🚀 Next Steps

After deployment:
1. Configure domain and SSL certificate
2. Set up Slack notifications
3. Add monitoring dashboards
4. Configure backup procedures
5. Document team runbooks

## 📞 Support

For template issues or questions:
- Review CloudWatch logs for deployment errors
- Check GitHub Actions for CI/CD issues
- Validate AWS IAM permissions
- Consult Atlantis documentation for GitOps workflows

---

**Template Version**: MVP 1.0
**Last Updated**: 2025-09-19
**Terraform Version**: >= 1.5.0
