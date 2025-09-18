import boto3
import os
import json
from datetime import datetime, timedelta

def handler(event, context):
    """
    Auto-cleanup Lambda function for ephemeral environments
    """
    environment_name = os.environ.get('ENVIRONMENT_NAME', 'dev')
    ttl_hours = int(os.environ.get('TTL_HOURS', 8))
    cluster_name = os.environ.get('CLUSTER_NAME')
    service_name = os.environ.get('SERVICE_NAME')

    ecs_client = boto3.client('ecs')

    try:
        response = ecs_client.describe_services(
            cluster=cluster_name,
            services=[service_name]
        )

        if not response['services']:
            return {'statusCode': 404, 'body': 'Service not found'}

        service = response['services'][0]
        created_at = service['createdAt']
        age_hours = (datetime.now(created_at.tzinfo) - created_at).total_seconds() / 3600

        if age_hours > ttl_hours:
            ecs_client.delete_service(
                cluster=cluster_name,
                service=service_name,
                force=True
            )
            return {'statusCode': 200, 'body': f'Cleaned up after {age_hours:.1f} hours'}

        return {'statusCode': 200, 'body': f'Valid for {ttl_hours - age_hours:.1f} more hours'}

    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
