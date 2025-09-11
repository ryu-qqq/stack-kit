# Zero Trust Network Architecture with NACLs, VPC Flow Logs, and Intrusion Detection
# Layer 4 network controls and comprehensive traffic monitoring

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_vpc" "main" {
  id = var.vpc_id
}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Network segmentation tiers
  network_tiers = {
    dmz = {
      name        = "DMZ"
      subnet_type = "public"
      cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
      allowed_inbound = [
        { port = 80,   protocol = "tcp", source = "0.0.0.0/0", description = "HTTP from internet" },
        { port = 443,  protocol = "tcp", source = "0.0.0.0/0", description = "HTTPS from internet" }
      ]
      allowed_outbound = [
        { port = 0,    protocol = "-1",  destination = "10.0.0.0/16", description = "Internal VPC traffic" },
        { port = 80,   protocol = "tcp", destination = "0.0.0.0/0", description = "HTTP to internet" },
        { port = 443,  protocol = "tcp", destination = "0.0.0.0/0", description = "HTTPS to internet" }
      ]
    }
    
    application = {
      name        = "Application"
      subnet_type = "private"
      cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24"]
      allowed_inbound = [
        { port = 4141, protocol = "tcp", source = "10.0.1.0/24", description = "Atlantis from ALB" },
        { port = 2049, protocol = "tcp", source = "10.0.10.0/24", description = "EFS within app tier" },
        { port = 22,   protocol = "tcp", source = "10.0.20.0/24", description = "SSH from bastion (if exists)" }
      ]
      allowed_outbound = [
        { port = 443,  protocol = "tcp", destination = "0.0.0.0/0", description = "HTTPS to AWS APIs" },
        { port = 53,   protocol = "udp", destination = "0.0.0.0/0", description = "DNS queries" },
        { port = 80,   protocol = "tcp", destination = "0.0.0.0/0", description = "HTTP for package downloads" }
      ]
    }
    
    data = {
      name        = "Data"
      subnet_type = "isolated"
      cidr_blocks = ["10.0.20.0/24", "10.0.21.0/24"]
      allowed_inbound = [
        { port = 443,  protocol = "tcp", source = "10.0.10.0/24", description = "HTTPS from application tier" }
      ]
      allowed_outbound = [
        { port = 443,  protocol = "tcp", destination = "169.254.169.254/32", description = "AWS metadata service" }
      ]
    }
  }
  
  # Team-specific network boundaries
  team_network_rules = {
    frontend = {
      allowed_ports = [80, 443, 3000, 3001]
      allowed_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
    }
    backend = {
      allowed_ports = [8000, 8080, 9000]
      allowed_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
    }
    devops = {
      allowed_ports = [22, 2049, 4141]
      allowed_cidrs = ["10.0.0.0/16"]
    }
  }
}

# Enhanced Security Groups with team-based rules
resource "aws_security_group" "team_boundaries" {
  for_each = local.team_network_rules
  
  name_prefix = "stackkit-${each.key}-team-"
  vpc_id      = var.vpc_id
  description = "Team boundary security group for ${each.key} team"

  # Dynamic ingress rules based on team configuration
  dynamic "ingress" {
    for_each = each.value.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = each.value.allowed_cidrs
      description = "Team ${each.key} access to port ${ingress.value}"
    }
  }

  # Egress rules with logging
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }

  tags = {
    Name      = "stackkit-${each.key}-team-sg"
    Team      = each.key
    Purpose   = "TeamBoundary"
    ManagedBy = "StackKit-Security"
  }
}

# Network ACLs for layer 4 protection
resource "aws_network_acl" "dmz_tier" {
  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.public.ids

  # Inbound rules for DMZ tier
  dynamic "ingress" {
    for_each = local.network_tiers.dmz.allowed_inbound
    content {
      rule_no    = 100 + ingress.key * 10
      protocol   = ingress.value.protocol == "-1" ? "-1" : "tcp"
      action     = "allow"
      cidr_block = ingress.value.source
      from_port  = ingress.value.port == 0 ? 0 : ingress.value.port
      to_port    = ingress.value.port == 0 ? 0 : ingress.value.port
    }
  }

  # Block common attack vectors
  ingress {
    rule_no    = 50
    protocol   = "tcp"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 23  # Telnet
    to_port    = 23
  }

  ingress {
    rule_no    = 51
    protocol   = "tcp"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 135  # RPC
    to_port    = 139
  }

  # Outbound rules for DMZ tier
  dynamic "egress" {
    for_each = local.network_tiers.dmz.allowed_outbound
    content {
      rule_no    = 100 + egress.key * 10
      protocol   = egress.value.protocol == "-1" ? "-1" : "tcp"
      action     = "allow"
      cidr_block = egress.value.destination
      from_port  = egress.value.port == 0 ? 0 : egress.value.port
      to_port    = egress.value.port == 0 ? 0 : egress.value.port
    }
  }

  # Ephemeral port range for return traffic
  egress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name      = "stackkit-dmz-nacl"
    Tier      = "DMZ"
    Purpose   = "NetworkSecurity"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_network_acl" "application_tier" {
  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.private.ids

  # Inbound rules for application tier
  dynamic "ingress" {
    for_each = local.network_tiers.application.allowed_inbound
    content {
      rule_no    = 100 + ingress.key * 10
      protocol   = ingress.value.protocol
      action     = "allow"
      cidr_block = ingress.value.source
      from_port  = ingress.value.port
      to_port    = ingress.value.port
    }
  }

  # Deny direct internet access
  ingress {
    rule_no    = 50
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Ephemeral ports for return traffic
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound rules for application tier
  dynamic "egress" {
    for_each = local.network_tiers.application.allowed_outbound
    content {
      rule_no    = 100 + egress.key * 10
      protocol   = egress.value.protocol
      action     = "allow"
      cidr_block = egress.value.destination
      from_port  = egress.value.port == 0 ? 0 : egress.value.port
      to_port    = egress.value.port == 0 ? 65535 : egress.value.port
    }
  }

  tags = {
    Name      = "stackkit-application-nacl"
    Tier      = "Application"
    Purpose   = "NetworkSecurity"
    ManagedBy = "StackKit-Security"
  }
}

# VPC Flow Logs for comprehensive network monitoring
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = {
    Name      = "stackkit-vpc-flow-logs"
    Purpose   = "NetworkMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch log group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/stackkit/security/vpc-flow-logs"
  retention_in_days = 90
  kms_key_id        = var.cloudwatch_kms_key_arn

  tags = {
    Purpose   = "NetworkMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_log_role" {
  name = "StackKit-VPCFlowLogs-Role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Purpose   = "VPCFlowLogs"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "flow-log-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Network intrusion detection using CloudWatch Insights
resource "aws_cloudwatch_query_definition" "network_anomalies" {
  name = "StackKit-NetworkAnomalies"

  log_group_names = [aws_cloudwatch_log_group.vpc_flow_logs.name]

  query_string = <<EOF
fields @timestamp, srcaddr, dstaddr, srcport, dstport, protocol, action
| filter action = "REJECT"
| stats count() by srcaddr, dstaddr, dstport
| sort count desc
| limit 20
EOF

  tags = {
    Purpose   = "ThreatDetection"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch alarms for suspicious network activity
resource "aws_cloudwatch_metric_alarm" "high_rejected_connections" {
  alarm_name          = "StackKit-HighRejectedConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PacketsDroppedCount"
  namespace           = "AWS/VPC/NetworkAcl"
  period             = "300"
  statistic          = "Sum"
  threshold          = "100"
  alarm_description  = "This metric monitors high number of rejected network connections"
  alarm_actions      = [aws_sns_topic.network_security_alerts.arn]

  dimensions = {
    VpcId    = var.vpc_id
    NetworkAcl = aws_network_acl.application_tier.id
  }

  tags = {
    Purpose   = "ThreatDetection"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_cloudwatch_metric_alarm" "unusual_outbound_traffic" {
  alarm_name          = "StackKit-UnusualOutboundTraffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = "1000000000"  # 1GB
  alarm_description  = "This metric monitors unusual outbound network traffic"
  alarm_actions      = [aws_sns_topic.network_security_alerts.arn]

  tags = {
    Purpose   = "ThreatDetection"
    ManagedBy = "StackKit-Security"
  }
}

# SNS topic for network security alerts
resource "aws_sns_topic" "network_security_alerts" {
  name              = "stackkit-network-security-alerts"
  kms_master_key_id = var.sns_kms_key_arn

  tags = {
    Purpose   = "SecurityAlerts"
    ManagedBy = "StackKit-Security"
  }
}

# Lambda function for network threat analysis
resource "aws_lambda_function" "network_threat_analyzer" {
  filename         = data.archive_file.threat_analyzer.output_path
  function_name    = "stackkit-network-threat-analyzer"
  role            = aws_iam_role.threat_analyzer_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.threat_analyzer.output_base64sha256

  environment {
    variables = {
      VPC_FLOW_LOG_GROUP = aws_cloudwatch_log_group.vpc_flow_logs.name
      SNS_TOPIC_ARN      = aws_sns_topic.network_security_alerts.arn
      THREAT_INTEL_API   = var.threat_intel_api_url
    }
  }

  tags = {
    Purpose   = "ThreatAnalysis"
    ManagedBy = "StackKit-Security"
  }
}

# Threat analyzer Lambda source
data "archive_file" "threat_analyzer" {
  type        = "zip"
  output_path = "/tmp/threat-analyzer.zip"
  source {
    content  = file("${path.module}/lambda/threat_analyzer.py")
    filename = "index.py"
  }
}

# IAM role for threat analyzer Lambda
resource "aws_iam_role" "threat_analyzer_role" {
  name = "StackKit-ThreatAnalyzer-Role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Purpose   = "ThreatAnalysis"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_iam_role_policy" "threat_analyzer_policy" {
  name = "threat-analyzer-policy"
  role = aws_iam_role.threat_analyzer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.network_security_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule for automated threat response
resource "aws_cloudwatch_event_rule" "network_threat_response" {
  name        = "stackkit-network-threat-response"
  description = "Automated response to network security threats"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [
        aws_cloudwatch_metric_alarm.high_rejected_connections.alarm_name,
        aws_cloudwatch_metric_alarm.unusual_outbound_traffic.alarm_name
      ]
    }
  })

  tags = {
    Purpose   = "AutomatedResponse"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_cloudwatch_event_target" "threat_analyzer_target" {
  rule      = aws_cloudwatch_event_rule.network_threat_response.name
  target_id = "ThreatAnalyzerTarget"
  arn       = aws_lambda_function.network_threat_analyzer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.network_threat_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.network_threat_response.arn
}

# Network security dashboard
resource "aws_cloudwatch_dashboard" "network_security" {
  dashboard_name = "StackKit-Network-Security"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/VPC/NetworkAcl", "PacketsDroppedCount", "VpcId", var.vpc_id, "NetworkAcl", aws_network_acl.dmz_tier.id],
            ["...", aws_network_acl.application_tier.id]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "Network ACL Dropped Packets"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.vpc_flow_logs.name}'\n| fields @timestamp, srcaddr, dstaddr, srcport, dstport, action\n| filter action = \"REJECT\"\n| stats count() by srcaddr\n| sort count desc\n| limit 10"
          region  = local.region
          title   = "Top Source IPs with Rejected Connections"
        }
      }
    ]
  })

  tags = {
    Purpose   = "NetworkMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# Variables
variable "vpc_id" {
  description = "VPC ID for network security implementation"
  type        = string
}

variable "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for CloudWatch log encryption"
  type        = string
  default     = null
}

variable "sns_kms_key_arn" {
  description = "KMS key ARN for SNS topic encryption"
  type        = string
  default     = null
}

variable "threat_intel_api_url" {
  description = "Threat intelligence API URL for IP reputation checking"
  type        = string
  default     = ""
}

# Outputs
output "network_security_groups" {
  description = "Team-based network security groups"
  value = {
    for team, sg in aws_security_group.team_boundaries : team => {
      id   = sg.id
      name = sg.name
    }
  }
}

output "network_acls" {
  description = "Network ACLs for tier-based security"
  value = {
    dmz_tier         = aws_network_acl.dmz_tier.id
    application_tier = aws_network_acl.application_tier.id
  }
}

output "vpc_flow_logs" {
  description = "VPC Flow Logs configuration"
  value = {
    log_group   = aws_cloudwatch_log_group.vpc_flow_logs.name
    flow_log_id = aws_flow_log.vpc_flow_logs.id
  }
}

output "threat_detection" {
  description = "Threat detection resources"
  value = {
    analyzer_function = aws_lambda_function.network_threat_analyzer.function_name
    sns_topic        = aws_sns_topic.network_security_alerts.arn
    dashboard_url    = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.network_security.dashboard_name}"
  }
}