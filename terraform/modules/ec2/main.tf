# EC2 Instance Module
resource "aws_instance" "main" {
  count = var.instance_count

  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids      = var.security_group_ids
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  associate_public_ip_address = var.associate_public_ip

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = var.enable_encryption
    delete_on_termination = true
  }

  dynamic "ebs_block_device" {
    for_each = var.additional_ebs_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = ebs_block_device.value.volume_type
      volume_size           = ebs_block_device.value.volume_size
      encrypted             = var.enable_encryption
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.instance_name}-${count.index + 1}"
  })

  volume_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.instance_name}-volume-${count.index + 1}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group
resource "aws_security_group" "main" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-${var.instance_name}-"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = ingress.value.cidr_blocks
      security_groups = ingress.value.security_groups
      description     = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - EC2 SG needs outbound access
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.instance_name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP
resource "aws_eip" "main" {
  count = var.create_eip ? var.instance_count : 0

  instance = aws_instance.main[count.index].id
  domain   = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.instance_name}-eip-${count.index + 1}"
  })

  depends_on = [aws_instance.main]
}