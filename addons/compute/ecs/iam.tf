# IAM roles and policies for ECS service

# ECS Task Execution Role
resource "aws_iam_role" "execution_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-execution-role"
    Service     = var.service_name
    Environment = var.environment
  })
}

# Attach the managed ECS execution role policy
resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom execution role policy for secrets and parameters
resource "aws_iam_role_policy" "execution_role_custom" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${var.service_name}-execution-custom"
  role  = aws_iam_role.execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Secrets Manager permissions
      length([for k, v in var.secrets : v if can(regex("^arn:aws:secretsmanager:", v))]) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            for k, v in var.secrets : v if can(regex("^arn:aws:secretsmanager:", v))
          ]
        }
      ] : [],
      # Systems Manager Parameter Store permissions
      length([for k, v in var.secrets : v if can(regex("^arn:aws:ssm:", v))]) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameters",
            "ssm:GetParameter"
          ]
          Resource = [
            for k, v in var.secrets : v if can(regex("^arn:aws:ssm:", v))
          ]
        }
      ] : []
    )
  })
}

# ECS Task Role
resource "aws_iam_role" "task_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-task-role"
    Service     = var.service_name
    Environment = var.environment
  })
}

# Execute command permissions for debugging
resource "aws_iam_role_policy" "task_role_execute_command" {
  count = var.enable_execute_command ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${var.service_name}-execute-command"
  role  = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom task role policies
resource "aws_iam_role_policy" "task_role_custom" {
  for_each = var.task_role_policies
  name     = "${var.project_name}-${var.environment}-${var.service_name}-${each.key}"
  role     = aws_iam_role.task_role.id
  policy   = jsonencode(each.value)
}

# Attach managed policies to task role
resource "aws_iam_role_policy_attachment" "task_role_managed_policies" {
  for_each   = toset(var.task_role_managed_policies)
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

# S3 access policy for common use cases
resource "aws_iam_role_policy" "task_role_s3" {
  count = length(var.s3_bucket_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${var.service_name}-s3"
  role  = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

# CloudWatch metrics and logs permissions
resource "aws_iam_role_policy" "task_role_cloudwatch" {
  count = var.enable_cloudwatch_metrics ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${var.service_name}-cloudwatch"
  role  = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}