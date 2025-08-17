terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "data-platform"
      ManagedBy   = "terraform"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-data-platform-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-data-platform-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.environment}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.environment}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.environment}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.environment}-data-platform-key"
  public_key = var.public_key
}

# Service Clusters
module "airflow_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name         = "airflow"
  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  private_subnet_ids  = aws_subnet.private[*].id
  public_subnet_ids   = aws_subnet.public[*].id
  master_instance_type = "t3.large"
  worker_instance_type = "m5.2xlarge"
  worker_count        = 2
  master_storage_size = 50
  worker_storage_size = 100
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr]
  kubernetes_version  = var.kubernetes_version

  tags = {
    Service = "airflow"
  }
}

module "clickhouse_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name         = "clickhouse"
  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  private_subnet_ids  = aws_subnet.private[*].id
  public_subnet_ids   = aws_subnet.public[*].id
  master_instance_type = "t3.large"
  worker_instance_type = "m5.2xlarge"
  worker_count        = 2
  master_storage_size = 50
  worker_storage_size = 200
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr]
  kubernetes_version  = var.kubernetes_version

  tags = {
    Service = "clickhouse"
  }
}

module "trino_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name         = "trino"
  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  private_subnet_ids  = aws_subnet.private[*].id
  public_subnet_ids   = aws_subnet.public[*].id
  master_instance_type = "t3.large"
  worker_instance_type = "m5.2xlarge"
  worker_count        = 2
  master_storage_size = 50
  worker_storage_size = 100
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr]
  kubernetes_version  = var.kubernetes_version

  tags = {
    Service = "trino"
  }
}

module "superset_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name         = "superset"
  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  private_subnet_ids  = aws_subnet.private[*].id
  public_subnet_ids   = aws_subnet.public[*].id
  master_instance_type = "t3.large"
  worker_instance_type = "m5.large"
  worker_count        = 2
  master_storage_size = 50
  worker_storage_size = 50
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr]
  kubernetes_version  = var.kubernetes_version

  tags = {
    Service = "superset"
  }
}

module "ranger_cluster" {
  source = "../../modules/k8s-cluster"

  cluster_name         = "ranger"
  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  private_subnet_ids  = aws_subnet.private[*].id
  public_subnet_ids   = aws_subnet.public[*].id
  master_instance_type = "t3.large"
  worker_instance_type = "m5.large"
  worker_count        = 2
  master_storage_size = 50
  worker_storage_size = 50
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr]
  kubernetes_version  = var.kubernetes_version

  tags = {
    Service = "ranger"
  }
}

# Central Monitoring VM
module "monitoring_vm" {
  source = "../../modules/monitoring-vm"

  environment         = var.environment
  vpc_id              = aws_vpc.main.id
  subnet_id           = aws_subnet.public[0].id
  instance_type       = "m5.4xlarge"
  storage_size        = 500
  key_pair_name       = aws_key_pair.main.key_name
  allowed_cidr_blocks = [var.vpc_cidr, "0.0.0.0/0"]  # Allow external access to monitoring

  cluster_endpoints = [
    "https://${module.airflow_cluster.master_private_ip}:6443",
    "https://${module.clickhouse_cluster.master_private_ip}:6443",
    "https://${module.trino_cluster.master_private_ip}:6443",
    "https://${module.superset_cluster.master_private_ip}:6443",
    "https://${module.ranger_cluster.master_private_ip}:6443"
  ]

  tags = {
    Service = "monitoring"
  }
}