import boto3
import json
import os
import urllib3
from datetime import datetime, timedelta
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Automated ECR image cleanup Lambda function
    Cleans up old images beyond lifecycle policy for additional management
    """

    ecr_client = boto3.client('ecr')
    repository_name = os.environ.get('ECR_REPOSITORY')
    max_images = int(os.environ.get('MAX_IMAGES', '10'))
    region = os.environ.get('REGION', 'us-west-2')
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL', '')
    cleanup_enabled = os.environ.get('CLEANUP_ENABLED', 'true').lower() == 'true'
    dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'

    logger.info(f"Starting ECR cleanup for repository: {repository_name}")
    logger.info(f"Max images to retain: {max_images}")

    try:
        # List all images in the repository
        response = ecr_client.describe_images(
            repositoryName=repository_name,
            maxResults=1000
        )

        images = response.get('imageDetails', [])
        logger.info(f"Found {len(images)} total images")

        if len(images) <= max_images:
            logger.info(f"Image count ({len(images)}) is within limit ({max_images}). No cleanup needed.")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No cleanup needed',
                    'images_found': len(images),
                    'max_images': max_images
                })
            }

        # Sort images by push date (newest first)
        images.sort(key=lambda x: x.get('imagePushedAt', datetime.min), reverse=True)

        # Identify images to keep and delete
        images_to_keep = []
        images_to_delete = []

        for i, image in enumerate(images):
            image_tags = image.get('imageTags', [])
            push_date = image.get('imagePushedAt')
            image_digest = image.get('imageDigest')

            # Always keep production and release tagged images
            if any(tag.startswith(('v', 'release-', 'stable-')) for tag in image_tags):
                images_to_keep.append({
                    'tags': image_tags,
                    'digest': image_digest,
                    'pushed': push_date,
                    'reason': 'production_tag'
                })
                continue

            # Keep recent images within the max limit
            if i < max_images:
                images_to_keep.append({
                    'tags': image_tags,
                    'digest': image_digest,
                    'pushed': push_date,
                    'reason': 'recent'
                })
            else:
                # Check if image is older than 7 days for non-production images
                if push_date and push_date < datetime.now(push_date.tzinfo) - timedelta(days=7):
                    images_to_delete.append({
                        'tags': image_tags,
                        'digest': image_digest,
                        'pushed': push_date
                    })
                else:
                    # Keep newer images even if over limit
                    images_to_keep.append({
                        'tags': image_tags,
                        'digest': image_digest,
                        'pushed': push_date,
                        'reason': 'too_new'
                    })

        logger.info(f"Images to keep: {len(images_to_keep)}")
        logger.info(f"Images to delete: {len(images_to_delete)}")

        # Delete old images
        deleted_images = []
        if images_to_delete:
            for image in images_to_delete:
                try:
                    # Delete by digest (more reliable than tags)
                    ecr_client.batch_delete_image(
                        repositoryName=repository_name,
                        imageIds=[{'imageDigest': image['digest']}]
                    )

                    deleted_images.append({
                        'tags': image['tags'],
                        'digest': image['digest'][:19] + '...',  # Truncate for logging
                        'pushed': image['pushed'].isoformat() if image['pushed'] else 'unknown'
                    })

                    logger.info(f"Deleted image: {image['tags']} (pushed: {image['pushed']})")

                except Exception as e:
                    logger.error(f"Failed to delete image {image['digest'][:19]}...: {str(e)}")

        # Summary
        summary = {
            'total_images_found': len(images),
            'images_kept': len(images_to_keep),
            'images_deleted': len(deleted_images),
            'max_images_limit': max_images,
            'repository': repository_name,
            'cleanup_timestamp': datetime.utcnow().isoformat(),
            'deleted_image_details': deleted_images[:10]  # Limit log size
        }

        logger.info(f"Cleanup completed: {json.dumps(summary, indent=2)}")

        # Send Slack notification if webhook is configured
        if slack_webhook_url:
            send_slack_notification(slack_webhook_url, summary, deleted_images, dry_run)

        # Send notification to SNS if configured
        if deleted_images:
            try:
                sns_client = boto3.client('sns')
                topic_arn = f"arn:aws:sns:{region}:{context.invoked_function_arn.split(':')[4]}:atlantis-alerts"

                message = {
                    "AlarmName": "ECR Cleanup Completed",
                    "AlarmDescription": f"Cleaned up {len(deleted_images)} old images from {repository_name}",
                    "NewStateValue": "OK",
                    "OldStateValue": "OK",
                    "NewStateReason": f"Automated cleanup removed {len(deleted_images)} images",
                    "StateChangeTime": datetime.utcnow().isoformat(),
                    "Region": region
                }

                sns_client.publish(
                    TopicArn=topic_arn,
                    Message=json.dumps(message),
                    Subject="ECR Cleanup Notification"
                )

                logger.info("Sent SNS notification for cleanup completion")

            except Exception as e:
                logger.warning(f"Failed to send SNS notification: {str(e)}")

        return {
            'statusCode': 200,
            'body': json.dumps(summary)
        }

    except Exception as e:
        logger.error(f"ECR cleanup failed: {str(e)}")

        # Send error notification
        try:
            sns_client = boto3.client('sns')
            topic_arn = f"arn:aws:sns:{region}:{context.invoked_function_arn.split(':')[4]}:atlantis-alerts"

            error_message = {
                "AlarmName": "ECR Cleanup Failed",
                "AlarmDescription": f"Automated ECR cleanup failed for {repository_name}",
                "NewStateValue": "ALARM",
                "OldStateValue": "OK",
                "NewStateReason": str(e)[:200],  # Truncate error message
                "StateChangeTime": datetime.utcnow().isoformat(),
                "Region": region
            }

            sns_client.publish(
                TopicArn=topic_arn,
                Message=json.dumps(error_message),
                Subject="ECR Cleanup Error"
            )

        except Exception as sns_e:
            logger.error(f"Failed to send error notification: {str(sns_e)}")

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'repository': repository_name
            })
        }

def send_slack_notification(webhook_url, summary, deleted_images, dry_run):
    """Send ECR cleanup summary to Slack"""
    try:
        color = '#28a745' if summary['images_deleted'] > 0 else '#ffc107'
        title = f"🧹 ECR Cleanup Report: {summary['repository']}"

        if dry_run:
            title += " (DRY RUN)"
            color = '#17a2b8'

        fields = [
            {
                "title": "Total Images Found",
                "value": str(summary['total_images_found']),
                "short": True
            },
            {
                "title": "Images Kept",
                "value": str(summary['images_kept']),
                "short": True
            },
            {
                "title": "Images Deleted",
                "value": str(summary['images_deleted']),
                "short": True
            },
            {
                "title": "Max Limit",
                "value": str(summary['max_images_limit']),
                "short": True
            }
        ]

        # Add details of deleted images if any
        if deleted_images and len(deleted_images) > 0:
            deleted_details = []
            for img in deleted_images[:5]:  # Show max 5 deleted images
                tags_str = ', '.join(img['tags']) if img['tags'] else 'untagged'
                deleted_details.append(f"• {tags_str} (pushed: {img['pushed']})")

            fields.append({
                "title": f"Recently Deleted ({len(deleted_images)} total)",
                "value": '\n'.join(deleted_details),
                "short": False
            })

        payload = {
            "username": "ECR Cleanup Bot",
            "icon_emoji": ":broom:",
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "fields": fields,
                    "footer": f"ECR Automated Cleanup • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
                    "ts": int(datetime.utcnow().timestamp())
                }
            ]
        }

        http = urllib3.PoolManager()
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(payload),
            headers={'Content-Type': 'application/json'}
        )

        if response.status == 200:
            logger.info("ECR cleanup Slack notification sent successfully")
        else:
            logger.warning(f"Failed to send ECR cleanup Slack notification: {response.status}")

    except Exception as e:
        logger.error(f"Error sending ECR cleanup Slack notification: {str(e)}")

def send_error_notification(webhook_url, error_msg, repository_name):
    """Send ECR cleanup error notification to Slack"""
    try:
        payload = {
            "username": "ECR Cleanup Bot",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": "#dc3545",
                    "title": f"🚨 ECR Cleanup Failed: {repository_name}",
                    "fields": [
                        {
                            "title": "Error",
                            "value": error_msg,
                            "short": False
                        }
                    ],
                    "footer": f"ECR Cleanup Error • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
                    "ts": int(datetime.utcnow().timestamp())
                }
            ]
        }

        http = urllib3.PoolManager()
        http.request(
            'POST',
            webhook_url,
            body=json.dumps(payload),
            headers={'Content-Type': 'application/json'}
        )

    except Exception as e:
        logger.error(f"Error sending ECR cleanup error notification to Slack: {str(e)}")
