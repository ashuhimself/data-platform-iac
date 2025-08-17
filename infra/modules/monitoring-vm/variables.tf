variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where monitoring VM will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the monitoring VM"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for monitoring VM"
  type        = string
  default     = "m5.4xlarge"
}

variable "storage_size" {
  description = "Root volume size for monitoring VM (GB)"
  type        = number
  default     = 500
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the monitoring VM"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "cluster_endpoints" {
  description = "List of Kubernetes cluster API endpoints to monitor"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}