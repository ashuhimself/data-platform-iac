# Modern Open-Source Data Platform

A complete, production-ready data platform built with Infrastructure as Code principles. This platform runs entirely on AWS EC2 instances (no managed services) and provides a comprehensive suite of data tools for ingestion, processing, analytics, and governance.

## 🏗️ Architecture Overview

The platform consists of multiple Kubernetes micro-clusters, each dedicated to specific services:

- **Airflow Cluster** - Workflow orchestration with dbt integration
- **Airbyte Cluster** - Data integration and ELT pipelines
- **ClickHouse Cluster** - High-performance analytical database  
- **Trino Cluster** - Distributed SQL query engine
- **Apache Superset Cluster** - Business intelligence and visualization
- **Apache Ranger Cluster** - Data governance and access control
- **Central Monitoring VM** - Prometheus, Grafana, Loki, and Marquez (OpenLineage)

### Key Features

✅ **Latest Stable Versions** - All services use the most recent stable releases  
✅ **GitOps Deployment** - Managed via Argo CD app-of-apps pattern  
✅ **Secrets Management** - HashiCorp Vault with Kubernetes CSI integration  
✅ **Comprehensive Monitoring** - Metrics, logs, and data lineage tracking  
✅ **Security First** - Network policies, RBAC, resource quotas  
✅ **Multi-AZ Deployment** - High availability across availability zones  

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform/OpenTofu >= 1.6
- kubectl >= 1.28
- Helm >= 3.12

### Step 1: Infrastructure Deployment

```bash
# Clone the repository
git clone <your-repo-url>
cd DataPlatform

# Configure Terraform variables
cd infra/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS configuration

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

### Step 2: Configure kubectl

```bash
# Configure kubectl for each cluster
aws eks update-kubeconfig --region us-east-1 --name airflow-cluster
aws eks update-kubeconfig --region us-east-1 --name airbyte-cluster
aws eks update-kubeconfig --region us-east-1 --name clickhouse-cluster
aws eks update-kubeconfig --region us-east-1 --name trino-cluster
aws eks update-kubeconfig --region us-east-1 --name superset-cluster
aws eks update-kubeconfig --region us-east-1 --name ranger-cluster
```

### Step 3: Deploy Argo CD

```bash
# Install Argo CD on the management cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply the app-of-apps
kubectl apply -f platform/argocd/app-of-apps.yaml
```

### Step 4: Access Services

```bash
# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UIs (or configure ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl port-forward svc/airflow-webserver -n airflow 8081:8080
kubectl port-forward svc/airbyte-webapp-svc -n airbyte 8082:80
kubectl port-forward svc/superset -n superset 8083:8088
kubectl port-forward svc/grafana -n monitoring 8084:80
```

## 📋 Service Details

### Core Data Services

| Service | Version | Purpose | Access |
|---------|---------|---------|---------|
| **Airflow** | 2.8.1+ | Workflow orchestration, dbt execution | :8080 |
| **Airbyte** | 0.50.33+ | Data integration and ingestion | :80 |
| **ClickHouse** | 23.12+ | Analytical database | :8123/:9000 |
| **Trino** | 435+ | Distributed SQL engine | :8080 |
| **Apache Superset** | 3.1.0+ | BI and visualization | :8088 |
| **Apache Ranger** | 2.4.0+ | Data governance | :6080 |

### Observability Stack

| Service | Version | Purpose | Access |
|---------|---------|---------|---------|
| **Prometheus** | 2.48.1+ | Metrics collection | :9090 |
| **Grafana** | 10.2.3+ | Visualization & dashboards | :3000 |
| **Loki** | 2.9.4+ | Log aggregation | :3100 |
| **Marquez** | 0.43.0+ | Data lineage (OpenLineage) | :5000 |

### Infrastructure Components

| Component | Purpose |
|-----------|---------|
| **HashiCorp Vault** | Secrets and credential management |
| **Argo CD** | GitOps continuous deployment |
| **Nginx Ingress** | Load balancing and TLS termination |

## 🔧 Resource Sizing

### Per-Cluster Configuration

Each micro-cluster follows the **1 master + 2 workers** pattern:

#### Airflow Cluster
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)
- **Workers**: m5.2xlarge (8 vCPU, 32 GB RAM, 100 GB storage) × 2

#### Airbyte Cluster
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)
- **Workers**: m5.2xlarge (8 vCPU, 32 GB RAM, 150 GB storage) × 2

#### ClickHouse Cluster  
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)
- **Workers**: m5.2xlarge (8 vCPU, 32 GB RAM, 200 GB storage) × 2

#### Trino Cluster
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)  
- **Workers**: m5.2xlarge (8 vCPU, 32 GB RAM, 100 GB storage) × 2

#### Superset Cluster
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)
- **Workers**: m5.large (2 vCPU, 8 GB RAM, 50 GB storage) × 2

#### Ranger Cluster
- **Master**: t3.large (2 vCPU, 8 GB RAM, 50 GB storage)
- **Workers**: m5.large (2 vCPU, 8 GB RAM, 50 GB storage) × 2

#### Central Monitoring VM
- **Instance**: m5.4xlarge (16 vCPU, 64 GB RAM, 500 GB storage)

## 🔐 Security & Access Control

### Network Security
- **VPC**: Dedicated VPC with public/private subnets across 3 AZs
- **Security Groups**: Least-privilege access between services
- **Network Policies**: Kubernetes-native traffic control

### Authentication & Authorization
- **Vault Integration**: All secrets managed via HashiCorp Vault
- **RBAC**: Role-based access control for all services
- **TLS Everywhere**: End-to-end encryption for all communications

### Data Governance
- **Apache Ranger**: Fine-grained access policies for ClickHouse and Trino
- **Audit Logging**: Comprehensive audit trails via Loki
- **Resource Quotas**: Kubernetes resource limits per namespace

## 📊 Monitoring & Observability

### Metrics (Prometheus + Grafana)
- Infrastructure metrics (CPU, memory, disk, network)
- Application metrics (query performance, DAG runs, etc.)
- Custom dashboards for each service
- Alerting via AlertManager

### Logging (Loki + Promtail)
- Centralized log collection from all clusters
- Structured logging with proper labels
- Log-based alerting for error patterns
- 14-day retention with tiered storage

### Data Lineage (Marquez/OpenLineage)
- Automatic lineage tracking for dbt transformations
- Trino query lineage capture
- Airflow job dependency mapping
- REST API for lineage queries

## 🔄 Data Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Sources   │ -> │   Airbyte   │ -> │   Airflow   │ -> │ ClickHouse  │ -> │   Trino     │
│   (Various) │    │ (Ingestion) │    │ + dbt (ELT) │    │ (Storage)   │    │ (Query)     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                                       │
┌─────────────┐    ┌─────────────┐                                                    │
│   Ranger    │ <- │  Superset   │ <--------------------------------------------------┘
│(Governance) │    │ (BI/Viz)    │
└─────────────┘    └─────────────┘
```

### Typical Workflow
1. **Data Ingestion**: Airbyte extracts data from various sources
2. **Orchestration**: Airflow orchestrates ELT pipeline jobs
3. **Transformation**: dbt transforms raw data in ClickHouse
4. **Analytics**: Trino provides SQL interface across data sources  
5. **Visualization**: Superset creates dashboards and reports
6. **Governance**: Ranger enforces access policies
7. **Monitoring**: Full observability across all components

## 🛠️ Development & Customization

### Adding New Data Sources
1. Create connection in Airflow
2. Add catalog configuration in Trino
3. Update Ranger policies
4. Configure monitoring dashboards

### Scaling Considerations
- **Horizontal**: Add more worker nodes to existing clusters
- **Vertical**: Increase instance sizes in `infra/sizing.yaml`
- **Cross-Region**: Extend Terraform modules for multi-region

### Backup & Recovery
- **Database Backups**: Automated daily backups to S3
- **Configuration Backups**: GitOps ensures configuration is version-controlled
- **Disaster Recovery**: Multi-AZ deployment provides high availability

## 📁 Repository Structure

```
DataPlatform/
├── infra/                          # Terraform infrastructure code
│   ├── modules/
│   │   ├── k8s-cluster/           # Kubernetes cluster module
│   │   └── monitoring-vm/         # Central monitoring VM module
│   ├── environments/prod/         # Production environment
│   └── sizing.yaml               # Resource sizing configuration
├── k8s/                          # Kubernetes base configurations
│   ├── base/                     # Base security configurations
│   └── overlays/                 # Environment-specific overlays
├── platform/                    # Platform services
│   ├── argocd/                   # GitOps configuration
│   └── vault/                    # Secrets management
├── services/                     # Application configurations
│   ├── airflow/                  # Airflow + dbt configuration
│   ├── clickhouse/               # ClickHouse configuration
│   ├── trino/                    # Trino configuration
│   ├── superset/                 # Superset configuration
│   └── ranger/                   # Ranger configuration
└── observability/                # Monitoring stack
    ├── monitoring/               # Prometheus + Grafana
    ├── logging/                  # Loki + Promtail
    └── lineage/                  # Marquez (OpenLineage)
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify quotas
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
```

#### 2. Pods Not Starting
```bash
# Check node resources
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource quotas
kubectl describe quota -n <namespace>
```

#### 3. Services Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Check network policies
kubectl get networkpolicy -n <namespace>

# Test connectivity
kubectl run debug --image=nicolaka/netshoot -it --rm
```

### Health Checks

```bash
# Infrastructure health
terraform plan -detailed-exitcode

# Application health  
kubectl get pods --all-namespaces
helm list --all-namespaces

# Service connectivity
curl -f http://<service-endpoint>/health
```

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

---

**⚠️ Important Notes:**
- All service versions are set to latest stable releases available at deployment time
- Update version tags in Helm values before deployment for newest releases  
- Monitor resource usage and scale accordingly for production workloads
- Ensure proper backup procedures are in place before production use
- Review and customize security policies based on your organization's requirements