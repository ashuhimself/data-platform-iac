output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "master_private_ip" {
  description = "Private IP address of the master node"
  value       = aws_instance.k8s_master.private_ip
}

output "master_public_ip" {
  description = "Public IP address of the master node"
  value       = aws_instance.k8s_master.public_ip
}

output "master_instance_id" {
  description = "Instance ID of the master node"
  value       = aws_instance.k8s_master.id
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = aws_instance.k8s_workers[*].private_ip
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "worker_instance_ids" {
  description = "Instance IDs of worker nodes"
  value       = aws_instance.k8s_workers[*].id
}

output "security_group_id" {
  description = "ID of the security group for K8s nodes"
  value       = aws_security_group.k8s_nodes.id
}

output "master_iam_role_arn" {
  description = "ARN of the master node IAM role"
  value       = aws_iam_role.k8s_master_role.arn
}

output "worker_iam_role_arn" {
  description = "ARN of the worker nodes IAM role"
  value       = aws_iam_role.k8s_worker_role.arn
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.k8s_master.public_ip} 'sudo cat /etc/kubernetes/admin.conf'"
}