import json
import urllib3
import os
from datetime import datetime

# Slack webhook notification handler for Atlantis monitoring
def handler(event, context):
    """
    Lambda function to send CloudWatch alarm notifications to Slack
    """

    # Environment variables
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    service_name = os.environ.get('SERVICE_NAME', 'atlantis')
    atlantis_url = os.environ.get('ATLANTIS_URL', 'https://atlantis.set-of.com')

    if not slack_webhook_url:
        print("SLACK_WEBHOOK_URL not configured")
        return {
            'statusCode': 400,
            'body': json.dumps('Slack webhook URL not configured')
        }

    try:
        # Parse SNS message
        sns_message = json.loads(event['Records'][0]['Sns']['Message'])
        alarm_name = sns_message['AlarmName']
        alarm_description = sns_message['AlarmDescription']
        new_state = sns_message['NewStateValue']
        old_state = sns_message['OldStateValue']
        reason = sns_message['NewStateReason']
        timestamp = sns_message['StateChangeTime']
        region = sns_message['Region']

        # Determine alert color and icon based on alarm state
        if new_state == 'ALARM':
            color = '#dc3545'  # Red
            icon = '🚨'
            title = f"{icon} Atlantis Alert: {alarm_name}"
        elif new_state == 'OK':
            color = '#28a745'  # Green
            icon = '✅'
            title = f"{icon} Atlantis Recovery: {alarm_name}"
        else:
            color = '#ffc107'  # Yellow
            icon = '⚠️'
            title = f"{icon} Atlantis Warning: {alarm_name}"

        # Format timestamp
        formatted_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M:%S UTC')

        # Create action buttons based on alarm type
        actions = []

        # Add CloudWatch dashboard link
        dashboard_url = f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#dashboards:name={service_name}-dashboard"
        actions.append({
            "type": "button",
            "text": {"type": "plain_text", "text": "📊 View Dashboard"},
            "url": dashboard_url
        })

        # Add Atlantis service link
        actions.append({
            "type": "button",
            "text": {"type": "plain_text", "text": "🔗 Open Atlantis"},
            "url": atlantis_url
        })

        # Add ECS service link if ECS-related alarm
        if 'ecs' in alarm_name.lower() or 'task' in alarm_name.lower():
            ecs_url = f"https://{region}.console.aws.amazon.com/ecs/home?region={region}#/clusters/{service_name}-cluster/services"
            actions.append({
                "type": "button",
                "text": {"type": "plain_text", "text": "🏗️ View ECS Service"},
                "url": ecs_url
            })

        # Create Slack message payload
        payload = {
            "username": "Atlantis Monitor",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "fields": [
                        {
                            "title": "Description",
                            "value": alarm_description,
                            "short": False
                        },
                        {
                            "title": "State Change",
                            "value": f"{old_state} → {new_state}",
                            "short": True
                        },
                        {
                            "title": "Region",
                            "value": region,
                            "short": True
                        },
                        {
                            "title": "Time",
                            "value": formatted_time,
                            "short": True
                        },
                        {
                            "title": "Service",
                            "value": service_name,
                            "short": True
                        },
                        {
                            "title": "Reason",
                            "value": reason,
                            "short": False
                        }
                    ],
                    "actions": actions,
                    "footer": f"AWS CloudWatch • {region}",
                    "ts": int(datetime.now().timestamp())
                }
            ]
        }

        # Add specific context based on alarm type
        if 'unhealthy' in alarm_name.lower():
            payload["attachments"][0]["fields"].append({
                "title": "Suggested Actions",
                "value": "• Check ECS service health\n• Review application logs\n• Verify load balancer target groups",
                "short": False
            })
        elif 'response-time' in alarm_name.lower():
            payload["attachments"][0]["fields"].append({
                "title": "Performance Impact",
                "value": "• Users may experience slow response times\n• Check CPU/Memory utilization\n• Review database performance",
                "short": False
            })
        elif 'vaultdb' in alarm_name.lower():
            payload["attachments"][0]["fields"].append({
                "title": "VaultDB Issue",
                "value": "• VaultDB connection problems detected\n• Check single-task deployment constraints\n• Review database connectivity",
                "short": False
            })
        elif 'deployment' in alarm_name.lower():
            payload["attachments"][0]["fields"].append({
                "title": "Deployment Issue",
                "value": "• Check ECS task definition\n• Review deployment logs\n• Verify container image availability",
                "short": False
            })

        # Send to Slack
        http = urllib3.PoolManager()

        response = http.request(
            'POST',
            slack_webhook_url,
            body=json.dumps(payload),
            headers={'Content-Type': 'application/json'}
        )

        if response.status == 200:
            print(f"Successfully sent Slack notification for alarm: {alarm_name}")
            return {
                'statusCode': 200,
                'body': json.dumps('Notification sent successfully')
            }
        else:
            print(f"Failed to send Slack notification. Status: {response.status}")
            return {
                'statusCode': response.status,
                'body': json.dumps(f'Failed to send notification: {response.data}')
            }

    except Exception as e:
        print(f"Error processing alarm notification: {str(e)}")
        print(f"Event: {json.dumps(event)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
