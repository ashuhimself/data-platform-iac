#!/bin/bash
set -e

# Variables
CLUSTER_NAME="${cluster_name}"
K8S_VERSION="${kubernetes_version}"

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install kubeadm, kubelet, kubectl
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet

# Configure Docker daemon for systemd cgroup driver
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Enable IP forwarding
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Get private IP
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Initialize Kubernetes cluster
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$PRIVATE_IP \
  --apiserver-cert-extra-sans=$PRIVATE_IP \
  --node-name=master \
  --kubernetes-version=$K8S_VERSION

# Setup kubectl for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Setup kubectl for ec2-user
mkdir -p /home/ec2-user/.kube
cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

# Install Flannel CNI
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Save join command for workers
kubeadm token create --print-join-command > /home/ec2-user/join-command.sh
chmod +x /home/ec2-user/join-command.sh

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Vault CSI driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
kubectl create namespace vault-system
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace vault-system \
  --set syncSecret.enabled=true

# Label master node
kubectl label node master node-role.kubernetes.io/control-plane=true
kubectl label node master ${CLUSTER_NAME}-cluster=master

# Taint master node (remove if you want to schedule pods on master)
kubectl taint nodes master node-role.kubernetes.io/control-plane:NoSchedule

echo "Kubernetes master initialized successfully"
echo "Cluster: $CLUSTER_NAME"
echo "Join command saved to /home/ec2-user/join-command.sh"