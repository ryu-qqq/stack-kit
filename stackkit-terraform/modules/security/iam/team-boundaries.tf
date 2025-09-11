# Team-Based IAM Resource Boundaries
# Zero Trust IAM policies with team isolation and resource scoping

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources for current environment
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_organizations_organization" "current" {}

# Team boundary configuration
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Team definitions with resource boundaries
  teams = {
    frontend = {
      description = "Frontend development team"
      resources = [
        "arn:aws:s3:::*frontend*",
        "arn:aws:cloudfront::${local.account_id}:distribution/*",
        "arn:aws:lambda:${local.region}:${local.account_id}:function:*frontend*",
        "arn:aws:apigateway:${local.region}::/restapis/*/resources/*/*"
      ]
      environments = ["dev", "staging"]
      max_sessions = 5
      session_duration = 3600
    }
    
    backend = {
      description = "Backend development team"
      resources = [
        "arn:aws:rds:${local.region}:${local.account_id}:db:*backend*",
        "arn:aws:elasticache:${local.region}:${local.account_id}:cluster:*backend*",
        "arn:aws:lambda:${local.region}:${local.account_id}:function:*backend*",
        "arn:aws:ecs:${local.region}:${local.account_id}:service/*/*backend*"
      ]
      environments = ["dev", "staging"]
      max_sessions = 5
      session_duration = 3600
    }
    
    devops = {
      description = "DevOps and infrastructure team"
      resources = ["*"]
      environments = ["dev", "staging", "prod"]
      max_sessions = 3
      session_duration = 1800
      approval_required = true
      break_glass_access = true
    }
    
    security = {
      description = "Security and compliance team"
      resources = [
        "arn:aws:iam::${local.account_id}:*",
        "arn:aws:kms:${local.region}:${local.account_id}:*",
        "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:*",
        "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/*",
        "arn:aws:logs:${local.region}:${local.account_id}:*"
      ]
      environments = ["dev", "staging", "prod"]
      max_sessions = 2
      session_duration = 1800
      mfa_required = true
    }
  }
}

# Team IAM roles with boundary policies
resource "aws_iam_role" "team_role" {
  for_each = local.teams
  
  name = "StackKit-${title(each.key)}Team-Role"
  path = "/teams/"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = merge(
          {
            StringEquals = {
              "aws:PrincipalTag/Team" = each.key
              "aws:RequestedRegion" = local.region
            }
            "ForAllValues:StringEquals" = {
              "aws:PrincipalTag/Environment" = each.value.environments
            }
          },
          each.value.mfa_required == true ? {
            Bool = {
              "aws:MultiFactorAuthPresent" = "true"
            }
            NumericLessThan = {
              "aws:MultiFactorAuthAge" = "3600"
            }
          } : {}
        )
      }
    ]
  })

  permissions_boundary = aws_iam_policy.team_boundary[each.key].arn
  max_session_duration = each.value.session_duration

  tags = {
    Team        = each.key
    Description = each.value.description
    ManagedBy   = "StackKit-Security"
  }
}

# Team permission boundary policies
resource "aws_iam_policy" "team_boundary" {
  for_each = local.teams
  
  name        = "StackKit-${title(each.key)}Team-Boundary"
  path        = "/teams/"
  description = "Permission boundary for ${each.value.description}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "DenyOutsideTeamResources"
        Effect = "Deny"
        NotAction = [
          "sts:*",
          "iam:ListRoles",
          "iam:ListPolicies",
          "iam:GetRole",
          "iam:GetPolicy",
          "ec2:Describe*",
          "s3:ListAllMyBuckets",
          "logs:DescribeLogGroups",
          "cloudformation:ListStacks",
          "cloudformation:DescribeStacks"
        ]
        NotResource = each.value.resources
      },
      {
        Sid    = "DenyEnvironmentBreach"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          "ForAllValues:StringNotEquals" = {
            "aws:RequestedRegion" = [local.region]
          }
          StringNotLike = {
            "aws:userid" = "*:*@${each.key}.stackkit.internal"
          }
        }
      },
      {
        Sid    = "RequireResourceTagging"
        Effect = "Deny"
        Action = [
          "ec2:CreateTags",
          "s3:PutBucketTagging",
          "rds:AddTagsToResource",
          "lambda:TagResource"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/Team" = "true"
          }
          StringNotEquals = {
            "aws:RequestTag/Team" = each.key
          }
        }
      }
    ],
    # Add break glass access for emergency situations
    each.value.break_glass_access == true ? [
      {
        Sid    = "BreakGlassAccess"
        Effect = "Allow"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/BreakGlass" = "true"
            "aws:PrincipalTag/ApprovedBy" = ["security-team", "cto"]
          }
          DateLessThan = {
            "aws:CurrentTime" = "aws:PrincipalTag/BreakGlassExpiry"
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ] : [])
  })

  tags = {
    Team      = each.key
    ManagedBy = "StackKit-Security"
  }
}

# Team-specific IAM policies with least privilege
resource "aws_iam_policy" "team_policy" {
  for_each = local.teams
  
  name        = "StackKit-${title(each.key)}Team-Policy"
  path        = "/teams/"
  description = "Team-specific permissions for ${each.value.description}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "AllowTeamResourceAccess"
        Effect = "Allow"
        Action = [
          "s3:*",
          "lambda:*",
          "ecs:*",
          "rds:*",
          "elasticache:*",
          "cloudformation:*",
          "logs:*",
          "cloudwatch:*"
        ]
        Resource = each.value.resources
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = local.region
          }
        }
      },
      {
        Sid    = "AllowReadOnlyAWSServices"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "iam:ListRoles",
          "iam:GetRole",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "cloudformation:ListStacks",
          "cloudformation:DescribeStacks",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:stackkit/${each.key}/*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Team" = each.key
          }
        }
      }
    ],
    # Additional permissions for devops team
    each.key == "devops" ? [
      {
        Sid    = "DevOpsInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:CreatePolicy",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "kms:CreateKey",
          "kms:CreateAlias",
          "cloudtrail:CreateTrail",
          "cloudtrail:StartLogging"
        ]
        Resource = "*"
        Condition = merge(
          {
            StringEquals = {
              "aws:RequestedRegion" = local.region
            }
          },
          each.value.approval_required == true ? {
            StringLike = {
              "aws:userid" = "*:approved-*@devops.stackkit.internal"
            }
          } : {}
        )
      }
    ] : [],
    # Security team specific permissions
    each.key == "security" ? [
      {
        Sid    = "SecurityTeamFullAccess"
        Effect = "Allow"
        Action = [
          "iam:*",
          "kms:*",
          "secretsmanager:*",
          "cloudtrail:*",
          "config:*",
          "guardduty:*",
          "securityhub:*",
          "inspector:*"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          StringEquals = {
            "aws:RequestedRegion" = local.region
          }
        }
      }
    ] : [])
  })

  tags = {
    Team      = each.key
    ManagedBy = "StackKit-Security"
  }
}

# Attach team policies to roles
resource "aws_iam_role_policy_attachment" "team_policy" {
  for_each = local.teams
  
  role       = aws_iam_role.team_role[each.key].name
  policy_arn = aws_iam_policy.team_policy[each.key].arn
}

# Session management policies
resource "aws_iam_policy" "session_management" {
  for_each = local.teams
  
  name        = "StackKit-${title(each.key)}Team-SessionMgmt"
  path        = "/teams/"
  description = "Session management for ${each.value.description}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceSessionLimits"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          NumericGreaterThan = {
            "aws:RequestTag/SessionCount" = tostring(each.value.max_sessions)
          }
        }
      },
      {
        Sid    = "EnforceSessionTimeout"
        Effect = "Deny" 
        Action = "*"
        Resource = "*"
        Condition = {
          DateGreaterThan = {
            "aws:CurrentTime" = "aws:TokenIssueTime + ${each.value.session_duration}"
          }
        }
      }
    ]
  })

  tags = {
    Team      = each.key
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_iam_role_policy_attachment" "session_management" {
  for_each = local.teams
  
  role       = aws_iam_role.team_role[each.key].name
  policy_arn = aws_iam_policy.session_management[each.key].arn
}

# Cross-team resource sharing (with approval)
resource "aws_iam_policy" "cross_team_sharing" {
  name        = "StackKit-CrossTeam-Sharing"
  path        = "/teams/"
  description = "Controlled cross-team resource sharing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossTeamReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "lambda:GetFunction",
          "ecs:DescribeServices",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/CrossTeamAccess" = "approved"
          }
          StringLike = {
            "aws:RequestedResource": [
              "*shared*",
              "*common*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Purpose   = "CrossTeamSharing"
    ManagedBy = "StackKit-Security"
  }
}

# Outputs for team boundary information
output "team_roles" {
  description = "Team IAM roles with ARNs"
  value = {
    for team, role in aws_iam_role.team_role : team => {
      name = role.name
      arn  = role.arn
    }
  }
}

output "team_boundaries" {
  description = "Team permission boundaries"
  value = {
    for team, policy in aws_iam_policy.team_boundary : team => {
      name = policy.name
      arn  = policy.arn
    }
  }
}

output "team_configuration" {
  description = "Team configuration summary"
  value = {
    for team, config in local.teams : team => {
      environments     = config.environments
      max_sessions    = config.max_sessions
      session_duration = config.session_duration
      mfa_required    = lookup(config, "mfa_required", false)
      approval_required = lookup(config, "approval_required", false)
    }
  }
}