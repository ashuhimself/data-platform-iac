#!/bin/bash
set -e

# Variables
CLUSTER_NAME="${cluster_name}"
K8S_VERSION="${kubernetes_version}"
MASTER_IP="${master_ip}"

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

# Mount additional EBS volume for container storage
if [ -b /dev/nvme1n1 ] || [ -b /dev/xvdf ]; then
    DEVICE=$(lsblk -f | grep -E "(nvme1n1|xvdf)" | awk '{print $1}' | head -1)
    if [ ! -z "$DEVICE" ]; then
        mkfs.ext4 /dev/$DEVICE
        mkdir -p /var/lib/containers
        mount /dev/$DEVICE /var/lib/containers
        echo "/dev/$DEVICE /var/lib/containers ext4 defaults 0 2" >> /etc/fstab
    fi
fi

# Wait for master to be ready
echo "Waiting for master node to be ready..."
while ! nc -z $MASTER_IP 6443; do
  sleep 10
done

# Get join command from master (retry mechanism)
for i in {1..10}; do
  if ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/id_rsa ec2-user@$MASTER_IP "cat /home/ec2-user/join-command.sh" > /tmp/join-command.sh 2>/dev/null; then
    break
  fi
  echo "Attempt $i: Failed to get join command, retrying in 30 seconds..."
  sleep 30
done

# Join the cluster
if [ -f /tmp/join-command.sh ]; then
    chmod +x /tmp/join-command.sh
    /tmp/join-command.sh
    
    # Label this worker node
    HOSTNAME=$(hostname)
    # Note: kubectl commands will be run from master node via SSH later
    echo "Worker node $HOSTNAME joined cluster $CLUSTER_NAME successfully"
else
    echo "Failed to get join command from master"
    exit 1
fi

echo "Worker node configuration completed"