# =======================================
# Storage Module - StackKit Standard
# =======================================
# EFS, S3, DynamoDB, and Secrets Manager resources for Atlantis GitOps

# =====================================
# EFS FILE SYSTEM
# =====================================

resource "aws_efs_file_system" "atlantis" {
  count = var.enable_efs ? 1 : 0

  creation_token   = "${local.name_prefix}-efs"
  encrypted        = true
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode

  lifecycle_policy {
    transition_to_ia = var.efs_lifecycle_policy
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-efs"
    Type = "storage"
  })
}

# =====================================
# EFS MOUNT TARGETS
# =====================================

resource "aws_efs_mount_target" "atlantis" {
  count = var.enable_efs ? length(local.private_subnet_ids) : 0

  file_system_id  = aws_efs_file_system.atlantis[0].id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [local.efs_security_group_id]

  depends_on = [aws_efs_file_system.atlantis]
}

# =====================================
# EFS ACCESS POINT
# =====================================

resource "aws_efs_access_point" "atlantis" {
  count = var.enable_efs ? 1 : 0

  file_system_id = aws_efs_file_system.atlantis[0].id

  root_directory {
    path = "/atlantis-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 100
      permissions = "0755"
    }
  }

  posix_user {
    gid = 1000
    uid = 100
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-efs-access-point"
    Type = "storage"
  })
}

# =====================================
# SECRETS MANAGER
# =====================================

resource "aws_secretsmanager_secret" "atlantis_secrets" {
  name                    = "${local.name_prefix}-atlantis-secrets"
  description             = "Secrets for Atlantis GitOps application"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-atlantis-secrets"
    Type = "security"
  })
}

resource "aws_secretsmanager_secret_version" "atlantis_secrets" {
  secret_id = aws_secretsmanager_secret.atlantis_secrets.id

  # Initial empty secret - should be populated externally
  secret_string = jsonencode({
    github_token   = ""
    webhook_secret = ""
    github_user    = var.atlantis_github_user
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =====================================
# TERRAFORM STATE S3 BUCKET (Optional)
# =====================================

resource "aws_s3_bucket" "terraform_state" {
  count = var.create_terraform_state_bucket ? 1 : 0

  bucket = "${local.name_prefix}-terraform-state"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-terraform-state"
    Type = "storage"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.create_terraform_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket.terraform_state]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.create_terraform_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }

  depends_on = [aws_s3_bucket.terraform_state]
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.create_terraform_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.terraform_state]
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count = var.create_terraform_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

# =====================================
# TERRAFORM LOCK DYNAMODB TABLE (Optional)
# =====================================

resource "aws_dynamodb_table" "terraform_lock" {
  count = var.create_terraform_lock_table ? 1 : 0

  name         = "${local.name_prefix}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-terraform-lock"
    Type = "storage"
  })
}