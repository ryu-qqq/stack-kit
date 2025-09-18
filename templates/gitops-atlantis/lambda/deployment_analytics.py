import json
import boto3
import os
import urllib3
from datetime import datetime, timedelta
from typing import Dict, List, Any

def handler(event, context):
    """
    Generate weekly deployment analytics report for all monitored repositories
    """

    # Environment variables
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL', '')
    repositories = json.loads(os.environ.get('REPOSITORIES', '[]'))
    region = os.environ.get('REGION', 'us-east-1')

    cloudwatch = boto3.client('cloudwatch', region_name=region)
    logs_client = boto3.client('logs', region_name=region)

    # Time range for the last week
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=7)

    analytics_data = {
        'report_period': {
            'start': start_time.isoformat(),
            'end': end_time.isoformat()
        },
        'repositories': {},
        'summary': {
            'total_deployments': 0,
            'total_successes': 0,
            'total_failures': 0,
            'average_plan_duration': 0,
            'average_apply_duration': 0,
            'busiest_repository': None,
            'most_failures': None
        }
    }

    try:
        # Analyze each repository
        for repo in repositories:
            repo_stats = analyze_repository(cloudwatch, repo, start_time, end_time)
            analytics_data['repositories'][repo] = repo_stats

            # Update summary
            analytics_data['summary']['total_deployments'] += repo_stats['total_deployments']
            analytics_data['summary']['total_successes'] += repo_stats['successful_deployments']
            analytics_data['summary']['total_failures'] += repo_stats['failed_deployments']

        # Calculate averages and identify outliers
        calculate_summary_metrics(analytics_data)

        # Generate insights
        insights = generate_insights(analytics_data)

        # Send report to Slack
        if slack_webhook_url:
            send_slack_report(slack_webhook_url, analytics_data, insights)

        print(f"Analytics report generated: {json.dumps(analytics_data, indent=2, default=str)}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Analytics report generated successfully',
                'summary': analytics_data['summary']
            }, default=str)
        }

    except Exception as e:
        error_msg = f"Failed to generate analytics report: {str(e)}"
        print(error_msg)

        if slack_webhook_url:
            send_error_notification(slack_webhook_url, error_msg)

        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }

def analyze_repository(cloudwatch, repo: str, start_time: datetime, end_time: datetime) -> Dict[str, Any]:
    """
    Analyze deployment metrics for a specific repository
    """

    namespace = f"Atlantis/Repository/{repo}"

    stats = {
        'repository': repo,
        'successful_deployments': 0,
        'failed_deployments': 0,
        'total_deployments': 0,
        'average_plan_duration': 0,
        'average_apply_duration': 0,
        'max_plan_duration': 0,
        'max_apply_duration': 0,
        'success_rate': 0,
        'daily_deployments': []
    }

    try:
        # Get successful deployments
        success_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName='SuccessfulDeployments',
            Dimensions=[],
            StartTime=start_time,
            EndTime=end_time,
            Period=86400,  # Daily
            Statistics=['Sum']
        )

        if success_response['Datapoints']:
            stats['successful_deployments'] = sum(dp['Sum'] for dp in success_response['Datapoints'])
            stats['daily_deployments'] = [
                {
                    'date': dp['Timestamp'].isoformat(),
                    'successes': dp['Sum']
                }
                for dp in sorted(success_response['Datapoints'], key=lambda x: x['Timestamp'])
            ]

        # Get failed deployments
        failure_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName='FailedDeployments',
            Dimensions=[],
            StartTime=start_time,
            EndTime=end_time,
            Period=604800,  # Weekly total
            Statistics=['Sum']
        )

        if failure_response['Datapoints']:
            stats['failed_deployments'] = failure_response['Datapoints'][0]['Sum']

        # Calculate total and success rate
        stats['total_deployments'] = stats['successful_deployments'] + stats['failed_deployments']
        if stats['total_deployments'] > 0:
            stats['success_rate'] = round(
                (stats['successful_deployments'] / stats['total_deployments']) * 100, 2
            )

        # Get plan duration metrics
        plan_duration_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName='PlanDuration',
            Dimensions=[],
            StartTime=start_time,
            EndTime=end_time,
            Period=604800,  # Weekly
            Statistics=['Average', 'Maximum']
        )

        if plan_duration_response['Datapoints']:
            stats['average_plan_duration'] = round(plan_duration_response['Datapoints'][0]['Average'], 2)
            stats['max_plan_duration'] = round(plan_duration_response['Datapoints'][0]['Maximum'], 2)

        # Get apply duration metrics
        apply_duration_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName='ApplyDuration',
            Dimensions=[],
            StartTime=start_time,
            EndTime=end_time,
            Period=604800,  # Weekly
            Statistics=['Average', 'Maximum']
        )

        if apply_duration_response['Datapoints']:
            stats['average_apply_duration'] = round(apply_duration_response['Datapoints'][0]['Average'], 2)
            stats['max_apply_duration'] = round(apply_duration_response['Datapoints'][0]['Maximum'], 2)

    except Exception as e:
        print(f"Error analyzing repository {repo}: {str(e)}")

    return stats

def calculate_summary_metrics(analytics_data: Dict[str, Any]):
    """
    Calculate summary metrics across all repositories
    """
    summary = analytics_data['summary']
    repos_data = analytics_data['repositories'].values()

    if repos_data:
        # Find busiest repository
        busiest = max(repos_data, key=lambda x: x['total_deployments'])
        summary['busiest_repository'] = {
            'name': busiest['repository'],
            'deployments': busiest['total_deployments']
        }

        # Find repository with most failures
        most_failures = max(repos_data, key=lambda x: x['failed_deployments'])
        if most_failures['failed_deployments'] > 0:
            summary['most_failures'] = {
                'name': most_failures['repository'],
                'failures': most_failures['failed_deployments']
            }

        # Calculate overall averages
        avg_plan = [r['average_plan_duration'] for r in repos_data if r['average_plan_duration'] > 0]
        avg_apply = [r['average_apply_duration'] for r in repos_data if r['average_apply_duration'] > 0]

        if avg_plan:
            summary['average_plan_duration'] = round(sum(avg_plan) / len(avg_plan), 2)
        if avg_apply:
            summary['average_apply_duration'] = round(sum(avg_apply) / len(avg_apply), 2)

        # Overall success rate
        if summary['total_deployments'] > 0:
            summary['overall_success_rate'] = round(
                (summary['total_successes'] / summary['total_deployments']) * 100, 2
            )

def generate_insights(analytics_data: Dict[str, Any]) -> List[str]:
    """
    Generate actionable insights from analytics data
    """
    insights = []
    summary = analytics_data['summary']

    # Success rate insight
    if 'overall_success_rate' in summary:
        if summary['overall_success_rate'] < 90:
            insights.append(f"⚠️ Success rate is {summary['overall_success_rate']}% - below target of 90%")
        else:
            insights.append(f"✅ Excellent success rate: {summary['overall_success_rate']}%")

    # Performance insight
    if summary['average_apply_duration'] > 300:  # 5 minutes
        insights.append(f"⏱️ Average apply duration ({summary['average_apply_duration']}s) exceeds 5 minutes")

    # Repository-specific insights
    for repo_name, repo_data in analytics_data['repositories'].items():
        if repo_data['success_rate'] < 80:
            insights.append(f"🚨 {repo_name} has low success rate: {repo_data['success_rate']}%")

        if repo_data['max_apply_duration'] > 600:  # 10 minutes
            insights.append(f"⚠️ {repo_name} had deployment taking {repo_data['max_apply_duration']}s")

    # Volume insight
    if summary['busiest_repository']:
        insights.append(
            f"📊 Most active: {summary['busiest_repository']['name']} "
            f"({summary['busiest_repository']['deployments']} deployments)"
        )

    return insights

def send_slack_report(webhook_url: str, analytics_data: Dict[str, Any], insights: List[str]):
    """
    Send weekly analytics report to Slack
    """
    try:
        summary = analytics_data['summary']

        # Create repository stats table
        repo_stats = []
        for repo_name, repo_data in analytics_data['repositories'].items():
            repo_stats.append(
                f"• *{repo_name}*: "
                f"{repo_data['total_deployments']} deployments | "
                f"{repo_data['success_rate']}% success | "
                f"Avg apply: {repo_data['average_apply_duration']}s"
            )

        # Create insights section
        insights_text = "\n".join(insights) if insights else "No significant issues detected"

        payload = {
            "username": "Atlantis Analytics",
            "icon_emoji": ":chart_with_upwards_trend:",
            "attachments": [
                {
                    "color": "#36a64f" if summary.get('overall_success_rate', 0) >= 90 else "#ff9900",
                    "title": "📊 Weekly Atlantis Deployment Report",
                    "text": f"Report Period: Last 7 days",
                    "fields": [
                        {
                            "title": "📈 Overall Statistics",
                            "value": f"• Total Deployments: {summary['total_deployments']}\n"
                                    f"• Successful: {summary['total_successes']}\n"
                                    f"• Failed: {summary['total_failures']}\n"
                                    f"• Success Rate: {summary.get('overall_success_rate', 0)}%",
                            "short": True
                        },
                        {
                            "title": "⏱️ Performance Metrics",
                            "value": f"• Avg Plan Duration: {summary['average_plan_duration']}s\n"
                                    f"• Avg Apply Duration: {summary['average_apply_duration']}s",
                            "short": True
                        },
                        {
                            "title": "📦 Repository Performance",
                            "value": "\n".join(repo_stats[:5]) if repo_stats else "No deployment data",
                            "short": False
                        },
                        {
                            "title": "💡 Insights & Recommendations",
                            "value": insights_text,
                            "short": False
                        }
                    ],
                    "footer": f"Atlantis Analytics • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
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
            print("Weekly analytics report sent to Slack successfully")
        else:
            print(f"Failed to send report to Slack: {response.status}")

    except Exception as e:
        print(f"Error sending Slack report: {str(e)}")

def send_error_notification(webhook_url: str, error_msg: str):
    """
    Send error notification to Slack
    """
    try:
        payload = {
            "username": "Atlantis Analytics",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": "#dc3545",
                    "title": "🚨 Analytics Report Generation Failed",
                    "fields": [
                        {
                            "title": "Error",
                            "value": error_msg,
                            "short": False
                        }
                    ],
                    "footer": f"Atlantis Analytics Error • {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
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
        print(f"Error sending error notification to Slack: {str(e)}")
