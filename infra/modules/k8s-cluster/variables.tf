variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"  
  type        = list(string)
}

variable "master_instance_type" {
  description = "EC2 instance type for master node"
  type        = string
  default     = "t3.large"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "master_storage_size" {
  description = "Root volume size for master node (GB)"
  type        = number
  default     = 50
}

variable "worker_storage_size" {
  description = "Root volume size for worker nodes (GB)"
  type        = number
  default     = 100
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.29.0"
}

variable "additional_worker_storage" {
  description = "Additional EBS volume size for worker nodes (GB)"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}