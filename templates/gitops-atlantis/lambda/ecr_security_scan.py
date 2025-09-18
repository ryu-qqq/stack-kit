import json
import boto3
import os
import urllib3
from datetime import datetime

def handler(event, context):
    """
    ECR security scan results processor with Slack notifications
    Monitors scan results and sends alerts for vulnerabilities
    """

    # Environment variables
    repository_name = os.environ.get('ECR_REPOSITORY', '${repository_name}')
    region = os.environ.get('REGION', 'us-east-1')
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL', '')

    ecr_client = boto3.client('ecr', region_name=region)

    try:
        # Get latest images in the repository
        response = ecr_client.describe_images(
            repositoryName=repository_name,
            maxResults=10
        )

        images = response['imageDetails']

        # Sort by push date (newest first)
        images.sort(key=lambda x: x['imagePushedAt'], reverse=True)

        scan_results = []
        critical_vulnerabilities = 0
        high_vulnerabilities = 0
        medium_vulnerabilities = 0
        low_vulnerabilities = 0

        # Check scan results for recent images
        for image in images[:5]:  # Check latest 5 images
            image_digest = image['imageDigest']
            image_tags = image.get('imageTags', ['untagged'])

            try:
                # Get scan results
                scan_response = ecr_client.describe_image_scan_findings(
                    repositoryName=repository_name,
                    imageId={'imageDigest': image_digest}
                )

                scan_status = scan_response['imageScanStatus']['status']

                if scan_status == 'COMPLETE':
                    findings = scan_response['imageScanFindings']
                    finding_counts = findings.get('findingCounts', {})

                    critical = finding_counts.get('CRITICAL', 0)
                    high = finding_counts.get('HIGH', 0)
                    medium = finding_counts.get('MEDIUM', 0)
                    low = finding_counts.get('LOW', 0)

                    critical_vulnerabilities += critical
                    high_vulnerabilities += high
                    medium_vulnerabilities += medium
                    low_vulnerabilities += low

                    scan_results.append({
                        'image_tags': image_tags,
                        'digest': image_digest[:19] + '...',
                        'pushed_at': image['imagePushedAt'].isoformat(),
                        'scan_status': scan_status,
                        'vulnerabilities': {
                            'critical': critical,
                            'high': high,
                            'medium': medium,
                            'low': low
                        },
                        'total_vulnerabilities': critical + high + medium + low
                    })

                elif scan_status == 'FAILED':
                    scan_results.append({
                        'image_tags': image_tags,
                        'digest': image_digest[:19] + '...',
                        'scan_status': 'FAILED',
                        'error': 'Scan failed'
                    })

            except ecr_client.exceptions.ScanNotFoundException:
                # Start scan if not already done
                try:
                    ecr_client.start_image_scan(
                        repositoryName=repository_name,
                        imageId={'imageDigest': image_digest}
                    )

                    scan_results.append({
                        'image_tags': image_tags,
                        'digest': image_digest[:19] + '...',
                        'scan_status': 'IN_PROGRESS',
                        'message': 'Scan started'
                    })

                except Exception as scan_error:
                    print(f"Failed to start scan for {image_digest}: {str(scan_error)}")

            except Exception as e:
                print(f"Error processing scan for {image_digest}: {str(e)}")

        # Prepare summary
        summary = {
            'repository': repository_name,
            'scan_timestamp': datetime.utcnow().isoformat(),
            'images_scanned': len([r for r in scan_results if r.get('scan_status') == 'COMPLETE']),
            'total_vulnerabilities': {
                'critical': critical_vulnerabilities,
                'high': high_vulnerabilities,
                'medium': medium_vulnerabilities,
                'low': low_vulnerabilities
            },
            'scan_results': scan_results
        }

        print(f"Security scan summary: {json.dumps(summary, indent=2)}")

        # Send Slack notification if webhook is configured
        if slack_webhook_url:
            send_slack_notification(slack_webhook_url, summary)

        # Send SNS alert for critical vulnerabilities
        if critical_vulnerabilities > 0 or high_vulnerabilities > 5:
            send_sns_alert(region, summary, context)

        return {
            'statusCode': 200,
            'body': json.dumps(summary)
        }

    except Exception as e:
        error_msg = f"ECR security scan failed: {str(e)}"
        print(error_msg)

        if slack_webhook_url:
            send_error_notification(slack_webhook_url, error_msg, repository_name)

        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }

def send_slack_notification(webhook_url, summary):
    """Send security scan results to Slack"""
    try:
        vulnerabilities = summary['total_vulnerabilities']
        critical = vulnerabilities['critical']
        high = vulnerabilities['high']
        medium = vulnerabilities['medium']
        low = vulnerabilities['low']

        # Determine color and urgency based on vulnerabilities
        if critical > 0:
            color = '#dc3545'  # Red
            icon = '🚨'
            urgency = 'CRITICAL'
        elif high > 5:
            color = '#fd7e14'  # Orange
            icon = '⚠️'
            urgency = 'HIGH'
        elif high > 0 or medium > 10:
            color = '#ffc107'  # Yellow
            icon = '🔍'
            urgency = 'MEDIUM'
        else:
            color = '#28a745'  # Green
            icon = '✅'
            urgency = 'LOW'

        title = f"{icon} ECR Security Scan: {summary['repository']} [{urgency}]"

        fields = [
            {
                "title": "Critical Vulnerabilities",
                "value": str(critical),
                "short": True
            },
            {
                "title": "High Vulnerabilities",
                "value": str(high),
                "short": True
            },
            {
                "title": "Medium Vulnerabilities",
                "value": str(medium),
                "short": True
            },
            {
                "title": "Low Vulnerabilities",
                "value": str(low),
                "short": True
            },
            {
                "title": "Images Scanned",
                "value": str(summary['images_scanned']),
                "short": True
            },
            {
                "title": "Total Issues",
                "value": str(critical + high + medium + low),
                "short": True
            }
        ]

        # Add recommendations based on vulnerability levels
        if critical > 0:
            fields.append({
                "title": "🚨 Immediate Action Required",
                "value": f"• {critical} critical vulnerabilities found\n• Review and patch immediately\n• Consider blocking deployment",
                "short": False
            })
        elif high > 5:
            fields.append({
                "title": "⚠️ High Priority Review",
                "value": f"• {high} high-severity vulnerabilities\n• Schedule patching within 48 hours\n• Review deployment timeline",
                "short": False
            })

        # Add scan results details
        if summary['scan_results']:
            scan_details = []
            for result in summary['scan_results'][:3]:  # Show first 3 results
                if result.get('vulnerabilities'):
                    vuln = result['vulnerabilities']
                    tags = ', '.join(result['image_tags'])
                    scan_details.append(
                        f"• **{tags}**: C:{vuln['critical']} H:{vuln['high']} M:{vuln['medium']} L:{vuln['low']}"
                    )

            if scan_details:
                fields.append({
                    "title": "Recent Image Scan Results",
                    "value": '\n'.join(scan_details),
                    "short": False
                })

        # Add action buttons
        actions = [
            {
                "type": "button",
                "text": {"type": "plain_text", "text": "🔍 View ECR Console"},
                "url": f"https://console.aws.amazon.com/ecr/repositories/private/{summary['repository']}"
            }
        ]

        payload = {
            "username": "ECR Security Scanner",
            "icon_emoji": ":shield:",
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "fields": fields,
                    "actions": actions,
                    "footer": f"ECR Security Scan • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
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
            print("ECR security scan Slack notification sent successfully")
        else:
            print(f"Failed to send ECR security scan Slack notification: {response.status}")

    except Exception as e:
        print(f"Error sending ECR security scan Slack notification: {str(e)}")

def send_sns_alert(region, summary, context):
    """Send SNS alert for critical vulnerabilities"""
    try:
        sns_client = boto3.client('sns')
        topic_arn = f"arn:aws:sns:{region}:{context.invoked_function_arn.split(':')[4]}:atlantis-alerts"

        vulnerabilities = summary['total_vulnerabilities']
        critical = vulnerabilities['critical']
        high = vulnerabilities['high']

        message = {
            "AlarmName": "ECR Critical Vulnerabilities",
            "AlarmDescription": f"Critical security vulnerabilities found in {summary['repository']}",
            "NewStateValue": "ALARM",
            "OldStateValue": "OK",
            "NewStateReason": f"Found {critical} critical and {high} high vulnerabilities",
            "StateChangeTime": datetime.utcnow().isoformat(),
            "Region": region
        }

        sns_client.publish(
            TopicArn=topic_arn,
            Message=json.dumps(message),
            Subject="ECR Security Alert"
        )

        print("Sent SNS alert for critical vulnerabilities")

    except Exception as e:
        print(f"Failed to send SNS alert: {str(e)}")

def send_error_notification(webhook_url, error_msg, repository_name):
    """Send error notification to Slack"""
    try:
        payload = {
            "username": "ECR Security Scanner",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": "#dc3545",
                    "title": f"🚨 ECR Security Scan Failed: {repository_name}",
                    "fields": [
                        {
                            "title": "Error",
                            "value": error_msg,
                            "short": False
                        }
                    ],
                    "footer": f"ECR Security Scan Error • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
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
        print(f"Error sending ECR security scan error notification to Slack: {str(e)}")
