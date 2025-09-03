# Outputs for StackKit Atlantis Infrastructure
# These outputs are used by GitHub Actions and for user reference

output "atlantis_url" {
  description = "Atlantis server URL"
  value       = "http://${aws_lb.atlantis.dns_name}"
}

output "atlantis_dns_name" {
  description = "Atlantis load balancer DNS name"
  value       = aws_lb.atlantis.dns_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for Atlantis artifacts"
  value       = module.s3_bucket.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for Atlantis artifacts"
  value       = module.s3_bucket.bucket_arn
}

output "webhook_secret" {
  description = "GitHub webhook secret for repository setup"
  value       = random_password.webhook_secret.result
  sensitive   = true
}

output "sqs_queue_url" {
  description = "SQS queue URL for AI review events"
  value       = module.sqs_queue.queue_url
}

output "lambda_function_name" {
  description = "AI reviewer Lambda function name"
  value       = module.ai_reviewer_lambda.function_name
}

output "lambda_function_arn" {
  description = "AI reviewer Lambda function ARN"
  value       = module.ai_reviewer_lambda.function_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name for Atlantis"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name for Atlantis"
  value       = module.ecs_cluster.service_name
}

output "vpc_id" {
  description = "VPC ID created for Atlantis infrastructure"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "security_group_alb_id" {
  description = "ALB security group ID"
  value       = aws_security_group.atlantis_alb.id
}

output "github_webhook_url" {
  description = "GitHub webhook URL for repository setup"
  value       = "http://${aws_lb.atlantis.dns_name}/events"
}

# Configuration summary for user reference
output "configuration_summary" {
  description = "Summary of deployed configuration"
  value = {
    organization = local.org_name
    environment  = local.environment
    region      = var.aws_region
    
    atlantis = {
      url           = "http://${aws_lb.atlantis.dns_name}"
      webhook_url   = "http://${aws_lb.atlantis.dns_name}/events"
      cluster_name  = module.ecs_cluster.cluster_name
    }
    
    storage = {
      s3_bucket    = module.s3_bucket.bucket_name
      sqs_queue    = module.sqs_queue.queue_name
    }
    
    ai_reviewer = {
      lambda_function = module.ai_reviewer_lambda.function_name
      model          = local.ai_config.model
      language       = local.ai_config.language
      cost_threshold = local.ai_config.cost_threshold
    }
    
    networking = {
      vpc_id             = module.vpc.vpc_id
      public_subnets     = module.vpc.public_subnet_ids
      private_subnets    = module.vpc.private_subnet_ids
      load_balancer_dns  = aws_lb.atlantis.dns_name
    }
  }
}

# Secrets Manager ARNs (for external reference)
output "secrets" {
  description = "Secrets Manager ARNs for sensitive configuration"
  value = {
    github_token_arn    = aws_secretsmanager_secret.github_token.arn
    webhook_secret_arn  = aws_secretsmanager_secret.webhook_secret.arn
  }
  sensitive = true
}

# Repository configuration for project repos
output "repository_config_template" {
  description = "Template configuration for project repositories"
  value = {
    atlantis_yaml = {
      version = 3
      projects = [{
        name = "example-project"
        dir  = "terraform/"
        workflow = "stackkit-ai-review"
        autoplan = {
          enabled = true
          when_modified = ["**/*.tf", "**/*.tfvars"]
        }
        apply_requirements = local.atlantis_config.approval_requirements[local.environment]
      }]
      
      workflows = {
        "stackkit-ai-review" = {
          plan = {
            steps = [
              "init",
              "plan"
            ]
          }
          apply = {
            steps = [
              "apply"
            ]
          }
        }
      }
    }
    
    github_webhook = {
      url          = "http://${aws_lb.atlantis.dns_name}/events"
      content_type = "json"
      events       = ["push", "pull_request", "issue_comment", "pull_request_review"]
    }
  }
}

# Cost tracking outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    ecs_fargate   = local.environment == "prod" ? 45 : 25
    alb           = 18
    lambda        = 2
    s3            = 5
    sqs           = 1
    secrets       = 1
    cloudwatch    = 3
    data_transfer = 10
    total         = local.environment == "prod" ? 85 : 65
  }
}

# Next steps guidance
output "next_steps" {
  description = "Next steps to complete the setup"
  value = {
    step_1 = "GitHub webhook has been automatically configured"
    step_2 = "Create a new repository for your infrastructure projects"
    step_3 = "Add atlantis.yaml to your project repository (see repository_config_template output)"
    step_4 = "Create a PR with Terraform changes to test AI reviews"
    step_5 = "Use 'atlantis apply' comment to deploy after approval"
    
    documentation = "https://github.com/your-org/stackkit-template#usage"
    support       = "Create an issue at https://github.com/your-org/stackkit-template/issues"
  }
}