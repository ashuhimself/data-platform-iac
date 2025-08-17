output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# Airflow Cluster Outputs
output "airflow_cluster" {
  description = "Airflow cluster information"
  value = {
    cluster_name     = module.airflow_cluster.cluster_name
    master_ip        = module.airflow_cluster.master_private_ip
    worker_ips       = module.airflow_cluster.worker_private_ips
    kubeconfig_cmd   = module.airflow_cluster.kubeconfig_command
  }
}

# ClickHouse Cluster Outputs
output "clickhouse_cluster" {
  description = "ClickHouse cluster information"
  value = {
    cluster_name     = module.clickhouse_cluster.cluster_name
    master_ip        = module.clickhouse_cluster.master_private_ip
    worker_ips       = module.clickhouse_cluster.worker_private_ips
    kubeconfig_cmd   = module.clickhouse_cluster.kubeconfig_command
  }
}

# Trino Cluster Outputs
output "trino_cluster" {
  description = "Trino cluster information"
  value = {
    cluster_name     = module.trino_cluster.cluster_name
    master_ip        = module.trino_cluster.master_private_ip
    worker_ips       = module.trino_cluster.worker_private_ips
    kubeconfig_cmd   = module.trino_cluster.kubeconfig_command
  }
}

# Superset Cluster Outputs
output "superset_cluster" {
  description = "Superset cluster information"
  value = {
    cluster_name     = module.superset_cluster.cluster_name
    master_ip        = module.superset_cluster.master_private_ip
    worker_ips       = module.superset_cluster.worker_private_ips
    kubeconfig_cmd   = module.superset_cluster.kubeconfig_command
  }
}

# Ranger Cluster Outputs
output "ranger_cluster" {
  description = "Ranger cluster information"
  value = {
    cluster_name     = module.ranger_cluster.cluster_name
    master_ip        = module.ranger_cluster.master_private_ip
    worker_ips       = module.ranger_cluster.worker_private_ips
    kubeconfig_cmd   = module.ranger_cluster.kubeconfig_command
  }
}

# Monitoring VM Outputs
output "monitoring_vm" {
  description = "Monitoring VM information"
  value = {
    private_ip     = module.monitoring_vm.monitoring_vm_private_ip
    public_ip      = module.monitoring_vm.monitoring_vm_public_ip
    prometheus_url = module.monitoring_vm.prometheus_url
    grafana_url    = module.monitoring_vm.grafana_url
    loki_url       = module.monitoring_vm.loki_url
    marquez_ui_url = module.monitoring_vm.marquez_ui_url
  }
}

# Summary for easy access
output "cluster_access_commands" {
  description = "Commands to access each cluster"
  value = {
    airflow    = module.airflow_cluster.kubeconfig_command
    clickhouse = module.clickhouse_cluster.kubeconfig_command
    trino      = module.trino_cluster.kubeconfig_command
    superset   = module.superset_cluster.kubeconfig_command
    ranger     = module.ranger_cluster.kubeconfig_command
  }
}

output "monitoring_urls" {
  description = "Monitoring service URLs"
  value = {
    prometheus = module.monitoring_vm.prometheus_url
    grafana    = module.monitoring_vm.grafana_url
    loki       = module.monitoring_vm.loki_url
    marquez    = module.monitoring_vm.marquez_ui_url
  }
}