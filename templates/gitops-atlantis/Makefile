# =======================================
# Makefile for VaultDB-Compatible Deployments
# =======================================
# Deployment automation for different environments

.PHONY: help plan apply deploy-dev deploy-staging deploy-prod destroy validate format check-vault

# Default variables
ENV ?= dev
AWS_REGION ?= ap-northeast-2
TF_VERSION ?= 1.8.5

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RESET := \033[0m

help: ## Show this help message
	@echo "$(BLUE)VaultDB-Compatible Terraform Deployment$(RESET)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Environment-specific deployments:$(RESET)"
	@echo "  $(GREEN)deploy-dev         $(RESET) Fast deployment for development"
	@echo "  $(GREEN)deploy-staging     $(RESET) Blue/Green deployment for staging"
	@echo "  $(GREEN)deploy-prod        $(RESET) Safe Blue/Green deployment for production"

# =====================================
# ENVIRONMENT SETUP
# =====================================

init: ## Initialize Terraform with backend configuration
	@echo "$(BLUE)Initializing Terraform for $(ENV) environment...$(RESET)"
	terraform init \
		-backend-config="bucket=prod-connectly" \
		-backend-config="key=atlantis/$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=prod-connectly-tf-lock"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(RESET)"
	terraform validate
	terraform fmt -check -recursive

format: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(RESET)"
	terraform fmt -recursive

# =====================================
# PLANNING AND APPLICATION
# =====================================

plan: init validate ## Create execution plan
	@echo "$(BLUE)Creating execution plan for $(ENV)...$(RESET)"
	terraform plan \
		-var-file="environments/$(ENV)/terraform.tfvars" \
		-out=$(ENV).tfplan

apply: ## Apply Terraform changes
	@echo "$(BLUE)Applying Terraform changes for $(ENV)...$(RESET)"
	terraform apply $(ENV).tfplan

# =====================================
# ENVIRONMENT-SPECIFIC DEPLOYMENTS
# =====================================

deploy-dev: ## Deploy to development environment (fast, direct strategy)
	@echo "$(YELLOW)Deploying to Development Environment$(RESET)"
	@echo "$(BLUE)Strategy: Direct deployment for fast iteration$(RESET)"
	$(MAKE) ENV=dev plan
	@echo "$(GREEN)Plan complete. Applying changes...$(RESET)"
	$(MAKE) ENV=dev apply
	@echo "$(GREEN)Development deployment complete!$(RESET)"

deploy-staging: ## Deploy to staging environment (blue/green strategy)
	@echo "$(YELLOW)Deploying to Staging Environment$(RESET)"
	@echo "$(BLUE)Strategy: Blue/Green deployment with validation$(RESET)"
	$(MAKE) ENV=staging plan
	@read -p "Review the plan above. Continue with deployment? [y/N] " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(MAKE) ENV=staging apply && \
		$(MAKE) verify-staging; \
	else \
		echo "$(YELLOW)Deployment cancelled$(RESET)"; \
	fi

deploy-prod: ## Deploy to production environment (safe blue/green strategy)
	@echo "$(YELLOW)Deploying to Production Environment$(RESET)"
	@echo "$(RED)⚠️  PRODUCTION DEPLOYMENT - EXTRA CAUTION REQUIRED$(RESET)"
	@echo "$(BLUE)Strategy: Blue/Green deployment with VaultDB protection$(RESET)"
	@$(MAKE) check-vault
	@$(MAKE) ENV=prod plan
	@echo "$(RED)IMPORTANT: Review the plan carefully!$(RESET)"
	@read -p "Deploy to PRODUCTION? Type 'DEPLOY_PROD' to confirm: " confirm && \
	if [ "$$confirm" = "DEPLOY_PROD" ]; then \
		$(MAKE) ENV=prod apply && \
		$(MAKE) verify-prod; \
	else \
		echo "$(YELLOW)Production deployment cancelled$(RESET)"; \
	fi

# =====================================
# VAULT HEALTH CHECKS
# =====================================

check-vault: ## Check VaultDB health before deployment
	@echo "$(BLUE)Checking VaultDB health...$(RESET)"
	@python3 scripts/check_vault_health.py || \
	(echo "$(RED)VaultDB health check failed!$(RESET)" && exit 1)
	@echo "$(GREEN)VaultDB is healthy$(RESET)"

verify-staging: ## Verify staging deployment
	@echo "$(BLUE)Verifying staging deployment...$(RESET)"
	@sleep 60  # Wait for services to stabilize
	@curl -f https://atlantis-staging.set-of.com/healthz > /dev/null && \
	echo "$(GREEN)Staging deployment verified!$(RESET)" || \
	(echo "$(RED)Staging verification failed!$(RESET)" && exit 1)

verify-prod: ## Verify production deployment
	@echo "$(BLUE)Verifying production deployment...$(RESET)"
	@sleep 120  # Longer wait for production
	@curl -f https://atlantis.set-of.com/healthz > /dev/null && \
	echo "$(GREEN)Production deployment verified!$(RESET)" || \
	(echo "$(RED)Production verification failed!$(RESET)" && exit 1)

# =====================================
# DEPLOYMENT AUTOMATION
# =====================================

blue-green-switch: ## Switch traffic between blue and green environments
	@echo "$(BLUE)Initiating Blue/Green traffic switch...$(RESET)"
	@python3 scripts/deploy.py \
		--cluster $(CLUSTER_NAME) \
		--service $(SERVICE_NAME) \
		--task-definition $(TASK_DEFINITION) \
		--strategy blue_green \
		--environment $(ENV) \
		--blue-tg $(BLUE_TG_ARN) \
		--green-tg $(GREEN_TG_ARN) \
		--listener $(LISTENER_ARN)

rollback: ## Rollback to previous deployment
	@echo "$(YELLOW)Rolling back deployment...$(RESET)"
	@python3 scripts/rollback.py \
		--cluster $(CLUSTER_NAME) \
		--service $(SERVICE_NAME) \
		--environment $(ENV)

# =====================================
# MAINTENANCE AND CLEANUP
# =====================================

destroy: ## Destroy infrastructure (with confirmation)
	@echo "$(RED)⚠️  DESTRUCTIVE OPERATION$(RESET)"
	@read -p "Destroy $(ENV) infrastructure? Type 'DESTROY_$(ENV)' to confirm: " confirm && \
	if [ "$$confirm" = "DESTROY_$(ENV)" ]; then \
		terraform destroy \
			-var-file="environments/$(ENV)/terraform.tfvars" \
			-auto-approve; \
	else \
		echo "$(YELLOW)Destruction cancelled$(RESET)"; \
	fi

clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up temporary files...$(RESET)"
	rm -f *.tfplan
	rm -f *.tfstate.backup
	rm -rf .terraform/
	@echo "$(GREEN)Cleanup complete$(RESET)"

# =====================================
# MONITORING AND TROUBLESHOOTING
# =====================================

logs: ## Show recent ECS logs
	@echo "$(BLUE)Fetching recent logs for $(ENV)...$(RESET)"
	aws logs tail /ecs/$(ENV)-connectly-atlantis \
		--follow \
		--since 1h \
		--region $(AWS_REGION)

status: ## Show deployment status
	@echo "$(BLUE)Checking deployment status for $(ENV)...$(RESET)"
	@echo "$(YELLOW)ECS Service Status:$(RESET)"
	aws ecs describe-services \
		--cluster $(ENV)-connectly-atlantis-cluster \
		--services $(ENV)-connectly-atlantis-service \
		--region $(AWS_REGION) \
		--query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}'
	@echo "$(YELLOW)Target Group Health:$(RESET)"
	aws elbv2 describe-target-health \
		--target-group-arn $(TARGET_GROUP_ARN) \
		--region $(AWS_REGION) \
		--query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}'

health: ## Check application health
	@echo "$(BLUE)Checking application health...$(RESET)"
	@if [ "$(ENV)" = "prod" ]; then \
		curl -f https://atlantis.set-of.com/healthz; \
	elif [ "$(ENV)" = "staging" ]; then \
		curl -f https://atlantis-staging.set-of.com/healthz; \
	else \
		curl -f https://atlantis-dev.set-of.com/healthz; \
	fi
	@echo "$(GREEN)Application is healthy$(RESET)"

# =====================================
# DEVELOPMENT HELPERS
# =====================================

shell: ## Open shell in running container
	@echo "$(BLUE)Opening shell in Atlantis container...$(RESET)"
	aws ecs execute-command \
		--cluster $(ENV)-connectly-atlantis-cluster \
		--task $(shell aws ecs list-tasks --cluster $(ENV)-connectly-atlantis-cluster --service-name $(ENV)-connectly-atlantis-service --query 'taskArns[0]' --output text) \
		--container atlantis \
		--interactive \
		--command "/bin/sh" \
		--region $(AWS_REGION)

debug: ## Debug deployment issues
	@echo "$(BLUE)Running deployment diagnostics...$(RESET)"
	@echo "$(YELLOW)1. Service Status:$(RESET)"
	@$(MAKE) status
	@echo "$(YELLOW)2. Health Check:$(RESET)"
	@$(MAKE) health || echo "$(YELLOW)Health check failed$(RESET)"
	@echo "$(YELLOW)3. Recent Events:$(RESET)"
	aws ecs describe-services \
		--cluster $(ENV)-connectly-atlantis-cluster \
		--services $(ENV)-connectly-atlantis-service \
		--region $(AWS_REGION) \
		--query 'services[0].events[:5]'

# =====================================
# EXAMPLE USAGE
# =====================================

example: ## Show example usage
	@echo "$(YELLOW)Example Usage:$(RESET)"
	@echo ""
	@echo "$(GREEN)# Development deployment$(RESET)"
	@echo "make deploy-dev"
	@echo ""
	@echo "$(GREEN)# Staging deployment$(RESET)"
	@echo "make deploy-staging"
	@echo ""
	@echo "$(GREEN)# Production deployment$(RESET)"
	@echo "make deploy-prod"
	@echo ""
	@echo "$(GREEN)# Check status$(RESET)"
	@echo "make ENV=prod status"
	@echo ""
	@echo "$(GREEN)# View logs$(RESET)"
	@echo "make ENV=prod logs"
