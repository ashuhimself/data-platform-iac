# ArgoCD Setup Guide

This guide covers the setup and configuration of ArgoCD for the Data Platform using the App of Apps pattern.

## Prerequisites

- Kubernetes cluster running (minimum version 1.29.0)
- kubectl configured and connected to your cluster
- Helm 3.x installed
- Git repository access

## Installation

### 1. Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD using Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with custom values (optional)
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer \
  --set server.extraArgs="{--insecure}"
```

### 2. Access ArgoCD UI

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI (if not using LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
# Username: admin
# Password: (from command above)
```

## Configuration

### 1. Update Repository URL

Before deploying, update the repository URL in the configuration files:

```bash
# Edit app-of-apps.yaml
vim platform/argocd/app-of-apps.yaml

# Replace 'https://github.com/your-org/dataplatform' with your actual repository URL
```

### 2. Deploy App of Apps Pattern

```bash
# Apply the App of Apps configuration
kubectl apply -f platform/argocd/app-of-apps.yaml
```

This will create:
- **dataplatform-apps**: Main application that manages all other applications
- **dataplatform**: Project with proper RBAC and resource permissions

### 3. Configure Git Repository

Add your Git repository to ArgoCD:

```bash
# Using ArgoCD CLI
argocd repo add https://github.com/your-org/dataplatform \
  --username your-username \
  --password your-token
```

Or through the UI:
1. Go to Settings → Repositories
2. Click "Connect Repo using HTTPS"
3. Enter repository details

## Applications Managed by ArgoCD

The following applications are configured in the `applications/` directory:

- **Airflow**: Data orchestration platform
- **Airbyte**: Data integration platform
- **ClickHouse**: Analytical database
- **Trino**: Distributed SQL query engine
- **Superset**: Business intelligence tool
- **Ranger**: Data security and governance
- **Vault**: Secrets management
- **Monitoring**: Prometheus and Grafana stack

## Project Configuration

The `dataplatform` project includes:

### Allowed Source Repositories
- Main data platform repository
- Official Helm charts for all services
- HashiCorp Helm charts
- Prometheus community charts

### Destination Namespaces
- `airflow`, `airbyte`, `clickhouse`, `trino`
- `superset`, `ranger`, `vault`
- `monitoring`, `observability`

### RBAC Roles
- **dataplatform-admin**: Full access to all applications
- **dataplatform-dev**: Read and sync access only

## Sync Policies

Applications are configured with:
- **Automated sync**: Enabled with prune and self-heal
- **Sync options**: Create namespaces, proper pruning

## Troubleshooting

### Application Not Syncing
```bash
# Check application status
kubectl get applications -n argocd

# Describe specific application
kubectl describe application <app-name> -n argocd

# Force sync through CLI
argocd app sync <app-name>
```

### Repository Access Issues
```bash
# Check repository connection
argocd repo list

# Test repository access
argocd repo get https://github.com/your-org/dataplatform
```

### Permission Issues
```bash
# Check project permissions
kubectl get appproject dataplatform -n argocd -o yaml

# Verify RBAC configuration
kubectl auth can-i create applications --as=system:serviceaccount:argocd:argocd-application-controller
```

## Security Considerations

1. **Repository Access**: Use deploy keys or service accounts instead of personal tokens
2. **RBAC**: Configure proper roles based on team structure
3. **Network Policies**: Apply network policies for ArgoCD namespace
4. **TLS**: Enable TLS for production deployments
5. **Secrets**: Use external secret management (Vault integration configured)

## Monitoring

ArgoCD metrics are automatically exposed and can be scraped by Prometheus. Key metrics include:
- Application sync status
- Sync frequency and duration
- Resource health status

## Backup and Recovery

```bash
# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Restore from backup
kubectl apply -f argocd-apps-backup.yaml
kubectl apply -f argocd-projects-backup.yaml
```

## Next Steps

1. Configure SSO/OIDC integration
2. Set up notification webhooks
3. Configure image updater for automated deployments
4. Implement GitOps workflows for application updates