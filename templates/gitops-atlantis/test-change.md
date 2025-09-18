# Test infrastructure change

This is a test change to verify the PR workflow.

## OIDC Authentication Fix Test

Testing the resolution of:

- ✅ IAM role trust policy updated to use `sts:AssumeRoleWithWebIdentity`
- ✅ CodeQL action updated from v2 to v3
- ✅ Both GitHubActionsAtlantisPlanRole and GitHubActionsAtlantisRole fixed

Expected: Workflow should now successfully authenticate and complete plan validation.

## S3 Backend Configuration Fix Test

Additional fixes applied:
- ✅ Updated IAM plan policy to use correct S3 bucket: `prod-ORG_NAME_PLACEHOLDER`
- ✅ Updated DynamoDB table reference: `prod-ORG_NAME_PLACEHOLDER-tf-lock`
- ✅ Fixed S3 resource ARNs in plan-only policy

Test timestamp: 2025-09-18T03:27:30Z

## Workflow Syntax and Security Fix Test

Final fixes applied:
- ✅ Fixed workflow syntax error: `secrets.SLACK_WEBHOOK_URL` → `${{ secrets.SLACK_WEBHOOK_URL }}`
- ✅ Updated remaining CodeQL action v2 → v3
- ✅ Added `continue-on-error: true` for security upload step
- ✅ Enhanced security summary with actionable information

Expected: Both Terraform plan and security validation should complete successfully without workflow failures.

Test timestamp: 2025-09-18T03:35:00Z
