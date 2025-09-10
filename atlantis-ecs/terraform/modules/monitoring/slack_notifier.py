#!/usr/bin/env python3
"""
StackKit Slack Notifier Lambda Function
CloudWatch 알람을 Slack으로 전송
"""

import json
import urllib3
import os
from datetime import datetime

# Slack webhook URL from environment variable
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '${webhook_url}')

http = urllib3.PoolManager()

def handler(event, context):
    """
    Lambda handler for SNS notifications to Slack
    """
    try:
        # Parse SNS message
        sns_message = json.loads(event['Records'][0]['Sns']['Message'])
        
        # Extract alarm details
        alarm_name = sns_message.get('AlarmName', 'Unknown Alarm')
        alarm_description = sns_message.get('AlarmDescription', 'No description')
        new_state = sns_message.get('NewStateValue', 'UNKNOWN')
        old_state = sns_message.get('OldStateValue', 'UNKNOWN')
        reason = sns_message.get('NewStateReason', 'No reason provided')
        timestamp = sns_message.get('StateChangeTime', datetime.now().isoformat())
        
        # Determine color based on alarm state
        color_map = {
            'ALARM': '#FF0000',      # Red
            'OK': '#00FF00',         # Green
            'INSUFFICIENT_DATA': '#FFFF00'  # Yellow
        }
        color = color_map.get(new_state, '#808080')  # Gray for unknown
        
        # Determine emoji based on alarm state
        emoji_map = {
            'ALARM': '🚨',
            'OK': '✅',
            'INSUFFICIENT_DATA': '⚠️'
        }
        emoji = emoji_map.get(new_state, '📊')
        
        # Create Slack message
        slack_message = {
            "username": "StackKit Monitor",
            "icon_emoji": ":bar_chart:",
            "attachments": [
                {
                    "color": color,
                    "title": f"{emoji} CloudWatch Alarm: {alarm_name}",
                    "title_link": f"https://console.aws.amazon.com/cloudwatch/home#alarmsV2:alarm/{alarm_name}",
                    "fields": [
                        {
                            "title": "State Change",
                            "value": f"{old_state} → {new_state}",
                            "short": True
                        },
                        {
                            "title": "Timestamp",
                            "value": timestamp,
                            "short": True
                        },
                        {
                            "title": "Description",
                            "value": alarm_description,
                            "short": False
                        },
                        {
                            "title": "Reason",
                            "value": reason,
                            "short": False
                        }
                    ],
                    "footer": "StackKit DevOps",
                    "footer_icon": "https://aws.amazon.com/favicon.ico",
                    "ts": int(datetime.now().timestamp())
                }
            ]
        }
        
        # Add action buttons based on alarm type
        if 'deployment' in alarm_name.lower():
            slack_message["attachments"][0]["actions"] = [
                {
                    "type": "button",
                    "text": "View Dashboard",
                    "url": "https://console.aws.amazon.com/cloudwatch/home#dashboards"
                },
                {
                    "type": "button",
                    "text": "Check Logs",
                    "url": "https://console.aws.amazon.com/cloudwatch/home#logsV2"
                }
            ]
        
        # Send to Slack
        encoded_msg = json.dumps(slack_message).encode('utf-8')
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=encoded_msg,
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
                'body': json.dumps(f'Failed to send notification: {response.status}')
            }
            
    except Exception as e:
        print(f"Error processing SNS message: {str(e)}")
        
        # Send error notification to Slack
        error_message = {
            "username": "StackKit Monitor",
            "icon_emoji": ":warning:",
            "text": f"🚨 Error processing CloudWatch alarm notification: {str(e)}",
            "color": "danger"
        }
        
        try:
            encoded_msg = json.dumps(error_message).encode('utf-8')
            http.request(
                'POST',
                SLACK_WEBHOOK_URL,
                body=encoded_msg,
                headers={'Content-Type': 'application/json'}
            )
        except:
            pass  # Ignore errors in error notification
        
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def test_notification():
    """
    Test function for local development
    """
    test_event = {
        'Records': [
            {
                'Sns': {
                    'Message': json.dumps({
                        'AlarmName': 'test-deployment-failure-rate',
                        'AlarmDescription': 'Test alarm for deployment failures',
                        'NewStateValue': 'ALARM',
                        'OldStateValue': 'OK',
                        'NewStateReason': 'Threshold exceeded for testing',
                        'StateChangeTime': datetime.now().isoformat()
                    })
                }
            }
        ]
    }
    
    return handler(test_event, None)

if __name__ == "__main__":
    # For local testing
    test_result = test_notification()
    print(f"Test result: {test_result}")