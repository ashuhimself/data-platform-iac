#!/bin/bash
set -e

# Variables
CLUSTER_ENDPOINTS='${cluster_endpoints}'

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Mount additional EBS volume for monitoring data
if [ -b /dev/nvme1n1 ] || [ -b /dev/xvdf ]; then
    DEVICE=$(lsblk -f | grep -E "(nvme1n1|xvdf)" | awk '{print $1}' | head -1)
    if [ ! -z "$DEVICE" ]; then
        mkfs.ext4 /dev/$DEVICE
        mkdir -p /opt/monitoring/data
        mount /dev/$DEVICE /opt/monitoring/data
        echo "/dev/$DEVICE /opt/monitoring/data ext4 defaults 0 2" >> /etc/fstab
        chown -R ec2-user:ec2-user /opt/monitoring
    fi
fi

# Create monitoring directories
mkdir -p /opt/monitoring/{prometheus,grafana,loki,marquez}
mkdir -p /opt/monitoring/data/{prometheus,grafana,loki,marquez}
chown -R ec2-user:ec2-user /opt/monitoring

# Create Prometheus configuration
cat <<EOF > /opt/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "first_rules.yml"
  - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']

  # Kubernetes clusters monitoring
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
    - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https

  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
    - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: \$1:\$2
      target_label: __address__
    - action: labelmap
      regex: __meta_kubernetes_pod_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      action: replace
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_pod_name]
      action: replace
      target_label: kubernetes_pod_name
EOF

# Create Grafana provisioning
mkdir -p /opt/monitoring/grafana/provisioning/{datasources,dashboards}

cat <<EOF > /opt/monitoring/grafana/provisioning/datasources/datasources.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF

cat <<EOF > /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create Loki configuration
cat <<EOF > /opt/monitoring/loki/loki.yml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093
EOF

# Create Docker Compose file for monitoring stack
cat <<EOF > /opt/monitoring/docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./data/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/loki.yml:/etc/loki/local-config.yaml
      - ./data/loki:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

  marquez:
    image: marquezproject/marquez:latest
    container_name: marquez
    ports:
      - "5000:5000"
    volumes:
      - ./data/marquez:/opt/marquez
    environment:
      - MARQUEZ_CONFIG=/opt/marquez/marquez.yml
    restart: unless-stopped

  marquez-web:
    image: marquezproject/marquez-web:latest
    container_name: marquez-web
    ports:
      - "3001:3000"
    environment:
      - MARQUEZ_HOST=marquez
      - MARQUEZ_PORT=5000
    depends_on:
      - marquez
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    restart: unless-stopped
EOF

# Create Marquez configuration
mkdir -p /opt/monitoring/data/marquez
cat <<EOF > /opt/monitoring/data/marquez/marquez.yml
server:
  applicationConnectors:
    - type: http
      port: 5000
  adminConnectors:
    - type: http
      port: 5001

database:
  driverClass: org.h2.Driver
  url: jdbc:h2:file:./marquez
  user: sa
  password: ""

logging:
  level: INFO
  loggers:
    marquez: DEBUG
  appenders:
    - type: console
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/monitoring

# Start monitoring stack
cd /opt/monitoring
docker-compose up -d

echo "Monitoring stack deployed successfully"
echo "Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000 (admin/admin)"
echo "Loki: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3100"
echo "Marquez: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3001"