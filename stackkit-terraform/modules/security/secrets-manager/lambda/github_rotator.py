"""
GitHub Token Rotation Lambda Function
Automatically rotates GitHub tokens with validation and backup token management
"""

import json
import boto3
import requests
import secrets
import string
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')
sns_client = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

# Configuration
GITHUB_ORG = "${github_org}"
SNS_TOPIC_ARN = None  # Set by environment variable
VALIDATION_ENABLED = True


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for GitHub token rotation
    """
    global SNS_TOPIC_ARN
    SNS_TOPIC_ARN = context.get('SNS_TOPIC_ARN', '')
    
    try:
        # Extract secret information from event
        secret_arn = event['Step']
        token_type = event.get('TokenType', 'classic')  # classic or fine_grained
        
        logger.info(f"Starting GitHub token rotation for: {secret_arn}")
        
        # Perform rotation based on step
        step = event['Step']
        if step == 'createSecret':
            return create_secret(event, secret_arn, token_type)
        elif step == 'setSecret':
            return set_secret(event, secret_arn)
        elif step == 'testSecret':
            return test_secret(event, secret_arn, token_type)
        elif step == 'finishSecret':
            return finish_secret(event, secret_arn)
        else:
            raise ValueError(f"Invalid rotation step: {step}")
            
    except Exception as e:
        error_msg = f"GitHub token rotation failed: {str(e)}"
        logger.error(error_msg)
        
        # Send failure notification
        if SNS_TOPIC_ARN:
            send_notification('FAILED', error_msg, secret_arn)
        
        # Publish CloudWatch metric
        publish_metric('RotationFailure', 1)
        
        raise e


def create_secret(event: Dict[str, Any], secret_arn: str, token_type: str) -> Dict[str, Any]:
    """
    Step 1: Create new GitHub token
    """
    logger.info("Creating new GitHub token")
    
    try:
        # Get current secret to extract GitHub app information
        current_secret = get_secret_value(secret_arn, 'AWSCURRENT')
        if not current_secret:
            raise ValueError("Could not retrieve current secret")
        
        # Extract GitHub credentials
        github_data = json.loads(current_secret)
        
        if token_type == 'fine_grained':
            # Create fine-grained personal access token
            new_token = create_fine_grained_token(github_data)
        else:
            # Create classic personal access token
            new_token = create_classic_token(github_data)
        
        # Store new token as pending secret
        new_secret_data = github_data.copy()
        new_secret_data['github_token'] = new_token
        new_secret_data['token_created'] = datetime.utcnow().isoformat()
        new_secret_data['token_type'] = token_type
        
        secrets_client.put_secret_value(
            SecretId=secret_arn,
            SecretString=json.dumps(new_secret_data),
            VersionStage='AWSPENDING'
        )
        
        logger.info("Successfully created new GitHub token")
        publish_metric('TokenCreated', 1)
        
        return {"statusCode": 200, "message": "New token created successfully"}
        
    except Exception as e:
        logger.error(f"Failed to create new GitHub token: {str(e)}")
        raise


def set_secret(event: Dict[str, Any], secret_arn: str) -> Dict[str, Any]:
    """
    Step 2: Set secret in target systems (GitHub webhooks, etc.)
    """
    logger.info("Setting new GitHub token in target systems")
    
    try:
        # Get the pending secret
        pending_secret = get_secret_value(secret_arn, 'AWSPENDING')
        if not pending_secret:
            raise ValueError("Could not retrieve pending secret")
        
        github_data = json.loads(pending_secret)
        new_token = github_data['github_token']
        
        # Update GitHub webhook configurations if needed
        if 'webhook_repos' in github_data:
            update_webhook_configs(new_token, github_data['webhook_repos'])
        
        # Test token permissions
        if not test_token_permissions(new_token):
            raise ValueError("New token does not have required permissions")
        
        logger.info("Successfully set new GitHub token in target systems")
        publish_metric('TokenSet', 1)
        
        return {"statusCode": 200, "message": "New token set successfully"}
        
    except Exception as e:
        logger.error(f"Failed to set new GitHub token: {str(e)}")
        raise


def test_secret(event: Dict[str, Any], secret_arn: str, token_type: str) -> Dict[str, Any]:
    """
    Step 3: Test the new GitHub token
    """
    logger.info("Testing new GitHub token")
    
    try:
        # Get the pending secret
        pending_secret = get_secret_value(secret_arn, 'AWSPENDING')
        if not pending_secret:
            raise ValueError("Could not retrieve pending secret")
        
        github_data = json.loads(pending_secret)
        new_token = github_data['github_token']
        
        # Test GitHub API access
        if not test_github_api_access(new_token):
            raise ValueError("GitHub API access test failed")
        
        # Test specific permissions based on token type
        if token_type == 'fine_grained':
            if not test_fine_grained_permissions(new_token, github_data):
                raise ValueError("Fine-grained token permission test failed")
        else:
            if not test_classic_permissions(new_token):
                raise ValueError("Classic token permission test failed")
        
        # Test Atlantis webhook if configured
        if 'atlantis_webhook_url' in github_data:
            if not test_atlantis_webhook(new_token, github_data['atlantis_webhook_url']):
                logger.warning("Atlantis webhook test failed, but continuing rotation")
        
        logger.info("Successfully tested new GitHub token")
        publish_metric('TokenTested', 1)
        
        return {"statusCode": 200, "message": "New token tested successfully"}
        
    except Exception as e:
        logger.error(f"Failed to test new GitHub token: {str(e)}")
        raise


def finish_secret(event: Dict[str, Any], secret_arn: str) -> Dict[str, Any]:
    """
    Step 4: Finish rotation by promoting new secret and cleaning up
    """
    logger.info("Finishing GitHub token rotation")
    
    try:
        # Get current and pending secrets
        current_secret = get_secret_value(secret_arn, 'AWSCURRENT')
        pending_secret = get_secret_value(secret_arn, 'AWSPENDING')
        
        if not current_secret or not pending_secret:
            raise ValueError("Could not retrieve current or pending secret")
        
        current_data = json.loads(current_secret)
        pending_data = json.loads(pending_secret)
        
        # Store old token as backup if configured
        if 'backup_tokens' in current_data:
            backup_tokens = current_data.get('backup_tokens', [])
            backup_tokens.append({
                'token': current_data['github_token'],
                'created': current_data.get('token_created'),
                'revoked': datetime.utcnow().isoformat()
            })
            # Keep only last 2 backup tokens
            pending_data['backup_tokens'] = backup_tokens[-2:]
        
        # Revoke old GitHub token
        old_token = current_data['github_token']
        if old_token and old_token != pending_data['github_token']:
            revoke_github_token(old_token)
        
        # Promote pending to current
        secrets_client.update_secret_version_stage(
            SecretId=secret_arn,
            VersionStage='AWSCURRENT',
            MoveToVersionId=get_version_id_for_stage(secret_arn, 'AWSPENDING'),
            RemoveFromVersionId=get_version_id_for_stage(secret_arn, 'AWSCURRENT')
        )
        
        # Send success notification
        success_msg = f"GitHub token rotation completed successfully for {secret_arn}"
        send_notification('SUCCESS', success_msg, secret_arn)
        
        logger.info("Successfully finished GitHub token rotation")
        publish_metric('RotationCompleted', 1)
        
        return {"statusCode": 200, "message": "Token rotation completed successfully"}
        
    except Exception as e:
        logger.error(f"Failed to finish GitHub token rotation: {str(e)}")
        raise


def create_classic_token(github_data: Dict[str, Any]) -> str:
    """
    Create a new classic GitHub personal access token
    """
    # Note: GitHub API doesn't allow programmatic creation of personal access tokens
    # This would need to be implemented with GitHub Apps or manual token management
    # For now, generate a placeholder that would be replaced with actual implementation
    
    logger.warning("Classic token creation requires manual process or GitHub App")
    
    # In a real implementation, this would:
    # 1. Use GitHub App to create installation token
    # 2. Or use OAuth flow to create user token
    # 3. Or integrate with GitHub's token management API when available
    
    raise NotImplementedError("Classic token creation requires GitHub App integration")


def create_fine_grained_token(github_data: Dict[str, Any]) -> str:
    """
    Create a new fine-grained GitHub personal access token
    """
    # Similar to classic tokens, this requires GitHub App integration
    # or manual token management process
    
    logger.warning("Fine-grained token creation requires manual process or GitHub App")
    
    raise NotImplementedError("Fine-grained token creation requires GitHub App integration")


def test_github_api_access(token: str) -> bool:
    """
    Test basic GitHub API access with the token
    """
    try:
        headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        response = requests.get('https://api.github.com/user', headers=headers, timeout=10)
        
        if response.status_code == 200:
            user_data = response.json()
            logger.info(f"GitHub API test successful for user: {user_data.get('login')}")
            return True
        else:
            logger.error(f"GitHub API test failed: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"GitHub API test exception: {str(e)}")
        return False


def test_classic_permissions(token: str) -> bool:
    """
    Test required permissions for classic GitHub token
    """
    try:
        headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        # Test repo access
        response = requests.get(f'https://api.github.com/orgs/{GITHUB_ORG}/repos', 
                              headers=headers, timeout=10)
        
        if response.status_code != 200:
            logger.error("Token does not have required repository access")
            return False
        
        # Test webhook access
        repos = response.json()[:1]  # Test with first repo
        if repos:
            repo_name = repos[0]['name']
            webhook_response = requests.get(
                f'https://api.github.com/repos/{GITHUB_ORG}/{repo_name}/hooks',
                headers=headers, timeout=10
            )
            
            if webhook_response.status_code not in [200, 404]:
                logger.error("Token does not have required webhook access")
                return False
        
        return True
        
    except Exception as e:
        logger.error(f"Permission test exception: {str(e)}")
        return False


def test_fine_grained_permissions(token: str, github_data: Dict[str, Any]) -> bool:
    """
    Test required permissions for fine-grained GitHub token
    """
    # Implementation would test specific fine-grained permissions
    # based on the token's scope and repository access
    
    return test_classic_permissions(token)  # Simplified for now


def test_atlantis_webhook(token: str, webhook_url: str) -> bool:
    """
    Test Atlantis webhook functionality with new token
    """
    try:
        # Send a test ping to Atlantis webhook endpoint
        # This is a simplified test - actual implementation would depend on
        # Atlantis webhook configuration
        
        test_payload = {
            'action': 'ping',
            'zen': 'Token rotation test'
        }
        
        headers = {
            'X-GitHub-Event': 'ping',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(webhook_url, 
                               json=test_payload, 
                               headers=headers, 
                               timeout=10)
        
        return response.status_code in [200, 202]
        
    except Exception as e:
        logger.error(f"Atlantis webhook test exception: {str(e)}")
        return False


def test_token_permissions(token: str) -> bool:
    """
    Test that token has required permissions
    """
    return test_github_api_access(token) and test_classic_permissions(token)


def update_webhook_configs(token: str, webhook_repos: list) -> None:
    """
    Update webhook configurations with new token if needed
    """
    # In most cases, webhooks don't need token updates as they use
    # webhook secrets for authentication, not the GitHub token
    logger.info("Webhook configurations don't require token updates")


def revoke_github_token(token: str) -> None:
    """
    Revoke old GitHub token
    """
    try:
        # Note: GitHub doesn't provide API to revoke personal access tokens
        # This would need to be done manually or through GitHub Apps
        
        logger.info("Token revocation would be handled through GitHub UI or Apps")
        
        # In a GitHub App implementation, you would:
        # DELETE /installation/token or similar endpoint
        
    except Exception as e:
        logger.warning(f"Token revocation failed (this may be expected): {str(e)}")


def get_secret_value(secret_arn: str, version_stage: str) -> Optional[str]:
    """
    Get secret value for specific version stage
    """
    try:
        response = secrets_client.get_secret_value(
            SecretId=secret_arn,
            VersionStage=version_stage
        )
        return response['SecretString']
    except Exception as e:
        logger.error(f"Failed to get secret value: {str(e)}")
        return None


def get_version_id_for_stage(secret_arn: str, stage: str) -> Optional[str]:
    """
    Get version ID for specific stage
    """
    try:
        response = secrets_client.describe_secret(SecretId=secret_arn)
        for version_id, stages in response['VersionIdsToStages'].items():
            if stage in stages:
                return version_id
        return None
    except Exception as e:
        logger.error(f"Failed to get version ID: {str(e)}")
        return None


def send_notification(status: str, message: str, secret_arn: str) -> None:
    """
    Send SNS notification about rotation status
    """
    try:
        if not SNS_TOPIC_ARN:
            return
        
        notification = {
            'status': status,
            'message': message,
            'secret_arn': secret_arn,
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'GitHub Token Rotation'
        }
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(notification, indent=2),
            Subject=f'StackKit Secret Rotation: {status}'
        )
        
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")


def publish_metric(metric_name: str, value: float) -> None:
    """
    Publish CloudWatch metric
    """
    try:
        cloudwatch.put_metric_data(
            Namespace='StackKit/Security/Rotation',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Service',
                            'Value': 'GitHubTokenRotation'
                        }
                    ]
                }
            ]
        )
    except Exception as e:
        logger.error(f"Failed to publish metric: {str(e)}")