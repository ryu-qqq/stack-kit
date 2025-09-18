# Atlantis Wildcard Configuration Testing Guide

## Overview

This guide explains how to test the new wildcard configuration that enables automatic project detection without requiring Atlantis redeployment.

## What Changed?

### Before (Manual Configuration)

- Every new project required updating `atlantis.yaml`
- Each update required redeploying Atlantis
- Maintenance overhead for each new repository

### After (Wildcard Configuration)

- Projects automatically detected via `**/*` pattern
- Organization-level repository allowlist
- No redeployment needed for new projects

## Configuration Details

### 1. Wildcard Patterns in Atlantis.yaml

```yaml
projects:
# Global pattern - catches ALL Terraform projects
- name: all-terraform-auto
  dir: "**/*"
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars", "**/*.hcl"]

# Environment-specific patterns
- name: auto-production
  dir: "**/production/**"
  workspace: prod

- name: auto-staging
  dir: "**/staging/**"
  workspace: staging

- name: auto-dev
  dir: "**/dev/**"
  workspace: dev
```

### 2. Repository Allowlist

```hcl
# terraform.tfvars
atlantis_repo_allowlist = "github.com/GITHUB_USER_PLACEHOLDER/*,github.com/ORG_NAME_PLACEHOLDER/*,github.com/ORG_NAME_PLACEHOLDER-inc/*"
```

## Testing Procedures

### Quick Validation

Run the provided validation script:

```bash
cd gitops-atlantis
./scripts/validate-wildcard-config.sh
```

Expected output:

- ✅ YAML syntax validation
- ✅ Wildcard pattern detection
- ✅ Repository allowlist validation
- ✅ Auto-plan trigger verification

### Manual Testing Steps

#### 1. Test with New Project (Without Redeployment)

```bash
# Create a new test repository
mkdir test-terraform-project
cd test-terraform-project
git init

# Create Terraform configuration
mkdir -p infrastructure/production
cat > infrastructure/production/main.tf <<EOF
terraform {
  required_version = ">= 1.0"
}

resource "aws_s3_bucket" "test" {
  bucket = "test-atlantis-wildcard-\${random_id.test.hex}"
}

resource "random_id" "test" {
  byte_length = 4
}
EOF

# Push to GitHub (to any repo under allowed organizations)
git add .
git commit -m "test: Add test Terraform configuration"
git remote add origin https://github.com/ORG_NAME_PLACEHOLDER/test-terraform.git
git push -u origin main
```

#### 2. Create Pull Request

```bash
# Create feature branch
git checkout -b test-wildcard-config

# Modify Terraform file
echo "# Test comment" >> infrastructure/production/main.tf

# Push and create PR
git add .
git commit -m "test: Trigger Atlantis auto-plan"
git push origin test-wildcard-config
```

#### 3. Verify Atlantis Response

Check the PR for:

- ✅ Atlantis auto-plans without configuration
- ✅ Correct workspace selection (prod/staging/dev)
- ✅ No manual Atlantis.yaml updates needed

### Environment-Specific Testing

Test different directory structures:

```bash
# Production environment
mkdir -p services/api/production
echo 'resource "null_resource" "prod" {}' > services/api/production/main.tf

# Staging environment
mkdir -p services/api/staging
echo 'resource "null_resource" "staging" {}' > services/api/staging/main.tf

# Development environment
mkdir -p services/api/dev
echo 'resource "null_resource" "dev" {}' > services/api/dev/main.tf

# Generic project (uses default workspace)
mkdir -p modules/networking
echo 'resource "null_resource" "network" {}' > modules/networking/main.tf
```

### Validation Checklist

- [ ] **Syntax Validation**: Atlantis.yaml is valid YAML
- [ ] **Pattern Coverage**: Wildcards match all directory structures
- [ ] **Repo Allowlist**: Organization wildcards include all repos
- [ ] **Auto-plan Triggers**: Changes to .tf/.tfvars trigger plans
- [ ] **No Redeployment**: New projects work without Atlantis restart
- [ ] **Environment Detection**: Correct workspace based on path
- [ ] **Legacy Compatibility**: Existing explicit projects still work

## Troubleshooting

### Issue: Atlantis doesn't detect new project

**Check**:

1. Repository is under allowed organization (GITHUB_USER_PLACEHOLDER, ORG_NAME_PLACEHOLDER, ORG_NAME_PLACEHOLDER-inc)
2. Files have correct extensions (.tf, .tfvars, .hcl)
3. Directory structure matches patterns

### Issue: Wrong workspace selected

**Check**:

1. Directory path contains environment keyword (production/staging/dev)
2. More specific patterns take precedence

### Issue: Auto-plan not triggering

**Check**:

1. Modified files match `when_modified` patterns
2. PR is from allowed repository

## Rollback Procedure

If issues occur, rollback to explicit configuration:

```bash
# Revert atlantis.yaml
git revert <wildcard-commit-hash>

# Redeploy Atlantis with previous configuration
terraform apply -var-file=terraform.tfvars
```

## Benefits Summary

1. **Zero-Touch Onboarding**: New projects automatically included
2. **Reduced Maintenance**: No Atlantis.yaml updates
3. **Faster Development**: No deployment delays
4. **Consistent Standards**: Enforces directory conventions
5. **Scalability**: Handles unlimited projects

## Security Considerations

- Repository allowlist prevents unauthorized repos
- Organization-level wildcards maintain security boundary
- Explicit overrides possible for sensitive projects
- Audit logs track all Atlantis operations

## Next Steps

1. ✅ Run validation script
2. ✅ Test with sample project
3. ⏳ Deploy to Atlantis server
4. ⏳ Monitor first auto-detected projects
5. ⏳ Document any edge cases
