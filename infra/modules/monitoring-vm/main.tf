locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "monitoring"
  })
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for monitoring VM
resource "aws_security_group" "monitoring_vm" {
  name_prefix = "monitoring-vm"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Loki
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Marquez (OpenLineage)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Marquez Web UI
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # cAdvisor
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "monitoring-vm-sg"
  })
}

# IAM role for monitoring VM
resource "aws_iam_role" "monitoring_vm_role" {
  name = "monitoring-vm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for monitoring VM
resource "aws_iam_role_policy" "monitoring_vm_policy" {
  name = "monitoring-vm-policy"
  role = aws_iam_role.monitoring_vm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeTags",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "monitoring_vm_profile" {
  name = "monitoring-vm-profile"
  role = aws_iam_role.monitoring_vm_role.name
  tags = local.common_tags
}

# Monitoring VM
resource "aws_instance" "monitoring_vm" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name              = var.key_pair_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring_vm.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_vm_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.storage_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/monitoring-init.sh", {
    cluster_endpoints = jsonencode(var.cluster_endpoints)
  }))

  tags = merge(local.common_tags, {
    Name = "monitoring-vm"
    Role = "monitoring"
  })
}

# Additional EBS volume for monitoring data
resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = aws_instance.monitoring_vm.availability_zone
  size              = 1000
  type              = "gp3"
  encrypted         = true

  tags = merge(local.common_tags, {
    Name = "monitoring-data-volume"
  })
}

resource "aws_volume_attachment" "monitoring_data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.monitoring_data.id
  instance_id = aws_instance.monitoring_vm.id
}