output "monitoring_vm_private_ip" {
  description = "Private IP address of the monitoring VM"
  value       = aws_instance.monitoring_vm.private_ip
}

output "monitoring_vm_public_ip" {
  description = "Public IP address of the monitoring VM"
  value       = aws_instance.monitoring_vm.public_ip
}

output "monitoring_vm_instance_id" {
  description = "Instance ID of the monitoring VM"
  value       = aws_instance.monitoring_vm.id
}

output "security_group_id" {
  description = "ID of the monitoring VM security group"
  value       = aws_security_group.monitoring_vm.id
}

output "iam_role_arn" {
  description = "ARN of the monitoring VM IAM role"
  value       = aws_iam_role.monitoring_vm_role.arn
}

output "prometheus_url" {
  description = "Prometheus web interface URL"
  value       = "http://${aws_instance.monitoring_vm.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana web interface URL"
  value       = "http://${aws_instance.monitoring_vm.public_ip}:3000"
}

output "loki_url" {
  description = "Loki query URL"
  value       = "http://${aws_instance.monitoring_vm.public_ip}:3100"
}

output "marquez_ui_url" {
  description = "Marquez web interface URL"
  value       = "http://${aws_instance.monitoring_vm.public_ip}:3001"
}

output "marquez_api_url" {
  description = "Marquez API URL"
  value       = "http://${aws_instance.monitoring_vm.public_ip}:5000"
}