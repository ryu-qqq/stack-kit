import boto3
import os
import json
from datetime import datetime, timedelta

def handler(event, context):
    """Auto-cleanup Lambda for ephemeral dev environments"""

    environment_name = os.environ['ENVIRONMENT_NAME']
    ttl_hours = int(os.environ['TTL_HOURS'])
    cluster_name = os.environ['CLUSTER_NAME']
    service_name = os.environ['SERVICE_NAME']

    ecs = boto3.client('ecs', region_name='ap-northeast-2')
    ec2 = boto3.client('ec2', region_name='ap-northeast-2')

    try:
        # Check environment age
        response = ecs.describe_services(
            cluster=cluster_name,
            services=[service_name]
        )

        if not response['services']:
            print(f"Service {service_name} not found")
            return {'statusCode': 404}

        service = response['services'][0]
        created_at = service['createdAt']
        age_hours = (datetime.now(created_at.tzinfo) - created_at).total_seconds() / 3600

        print(f"Environment {environment_name} age: {age_hours:.2f} hours (TTL: {ttl_hours})")

        # Check if TTL exceeded
        if age_hours >= ttl_hours:
            print(f"TTL exceeded, initiating cleanup...")

            # Scale down to 0
            ecs.update_service(
                cluster=cluster_name,
                service=service_name,
                desiredCount=0
            )

            # Tag for deletion
            ecs.tag_resource(
                resourceArn=service['serviceArn'],
                tags=[
                    {'key': 'ScheduledForDeletion', 'value': 'true'},
                    {'key': 'DeletionTime', 'value': datetime.now().isoformat()}
                ]
            )

            # Send notification
            send_cleanup_notification(environment_name, age_hours)

            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Environment {environment_name} scheduled for cleanup',
                    'age_hours': age_hours
                })
            }

        # Check idle time
        check_idle_status(cluster_name, service_name, environment_name)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Environment {environment_name} still within TTL',
                'age_hours': age_hours,
                'remaining_hours': ttl_hours - age_hours
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def check_idle_status(cluster_name, service_name, environment_name):
    """Check if environment is idle and scale down if needed"""

    cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-2')
    ecs = boto3.client('ecs', region_name='ap-northeast-2')

    # Get CPU utilization for last 30 minutes
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=30)

    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/ECS',
        MetricName='CPUUtilization',
        Dimensions=[
            {'Name': 'ClusterName', 'Value': cluster_name},
            {'Name': 'ServiceName', 'Value': service_name}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Average']
    )

    if response['Datapoints']:
        avg_cpu = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
        print(f"Average CPU utilization: {avg_cpu:.2f}%")

        if avg_cpu < 5:  # Less than 5% CPU usage
            print(f"Environment {environment_name} is idle, scaling down to 0")

            # Get current desired count
            services = ecs.describe_services(
                cluster=cluster_name,
                services=[service_name]
            )

            if services['services'][0]['desiredCount'] > 0:
                ecs.update_service(
                    cluster=cluster_name,
                    service=service_name,
                    desiredCount=0
                )

                send_idle_notification(environment_name)


def send_cleanup_notification(environment_name, age_hours):
    """Send notification about environment cleanup"""

    # If Slack webhook is configured
    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if webhook_url:
        import requests

        payload = {
            'text': f'🧹 Dev environment `{environment_name}` has been cleaned up',
            'attachments': [{
                'color': 'warning',
                'fields': [
                    {'title': 'Environment', 'value': environment_name, 'short': True},
                    {'title': 'Age', 'value': f'{age_hours:.1f} hours', 'short': True},
                    {'title': 'Action', 'value': 'Scaled to 0, scheduled for deletion', 'short': False}
                ]
            }]
        }

        try:
            requests.post(webhook_url, json=payload)
        except Exception as e:
            print(f"Failed to send Slack notification: {e}")


def send_idle_notification(environment_name):
    """Send notification about idle environment"""

    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if webhook_url:
        import requests

        payload = {
            'text': f'💤 Dev environment `{environment_name}` scaled down due to inactivity',
            'attachments': [{
                'color': '#36a64f',
                'fields': [
                    {'title': 'Environment', 'value': environment_name, 'short': True},
                    {'title': 'Action', 'value': 'Scaled to 0 (idle)', 'short': True},
                    {'title': 'To Resume', 'value': 'Push new commits or manually scale up', 'short': False}
                ]
            }]
        }

        try:
            requests.post(webhook_url, json=payload)
        except Exception as e:
            print(f"Failed to send Slack notification: {e}")
