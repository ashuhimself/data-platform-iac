locals {
  common_tags = merge(var.tags, {
    Environment   = var.environment
    Cluster       = var.cluster_name
    ManagedBy     = "terraform"
    Service       = "kubernetes"
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

# Security Group for Kubernetes nodes
resource "aws_security_group" "k8s_nodes" {
  name_prefix = "${var.cluster_name}-k8s-nodes"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # kube-scheduler
  ingress {
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # kube-controller-manager
  ingress {
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All traffic between nodes
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    self      = true
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-k8s-nodes-sg"
  })
}

# IAM role for master node
resource "aws_iam_role" "k8s_master_role" {
  name = "${var.cluster_name}-k8s-master-role"

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

# IAM role for worker nodes
resource "aws_iam_role" "k8s_worker_role" {
  name = "${var.cluster_name}-k8s-worker-role"

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

# IAM policies for Kubernetes
resource "aws_iam_role_policy" "k8s_master_policy" {
  name = "${var.cluster_name}-k8s-master-policy"
  role = aws_iam_role.k8s_master_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "route53:*",
          "autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "k8s_worker_policy" {
  name = "${var.cluster_name}-k8s-worker-policy" 
  role = aws_iam_role.k8s_worker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profiles
resource "aws_iam_instance_profile" "k8s_master_profile" {
  name = "${var.cluster_name}-k8s-master-profile"
  role = aws_iam_role.k8s_master_role.name
  tags = local.common_tags
}

resource "aws_iam_instance_profile" "k8s_worker_profile" {
  name = "${var.cluster_name}-k8s-worker-profile"
  role = aws_iam_role.k8s_worker_role.name
  tags = local.common_tags
}

# Master node
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.master_instance_type
  key_name              = var.key_pair_name
  subnet_id             = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_master_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.master_storage_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/master-init.sh", {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
  }))

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-k8s-master"
    Role = "master"
  })
}

# Worker nodes
resource "aws_instance" "k8s_workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.worker_instance_type
  key_name              = var.key_pair_name
  subnet_id             = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_worker_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.worker_storage_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/worker-init.sh", {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    master_ip         = aws_instance.k8s_master.private_ip
  }))

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-k8s-worker-${count.index + 1}"
    Role = "worker"
  })

  depends_on = [aws_instance.k8s_master]
}

# Additional EBS volumes for worker nodes
resource "aws_ebs_volume" "worker_storage" {
  count             = var.worker_count
  availability_zone = aws_instance.k8s_workers[count.index].availability_zone
  size              = var.additional_worker_storage
  type              = "gp3"
  encrypted         = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-worker-${count.index + 1}-storage"
  })
}

resource "aws_volume_attachment" "worker_storage_attachment" {
  count       = var.worker_count
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.worker_storage[count.index].id
  instance_id = aws_instance.k8s_workers[count.index].id
}