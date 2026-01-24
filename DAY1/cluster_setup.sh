#!/bin/bash
set -e

echo "========== Kubernetes Common Setup Started =========="

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo su -)"
  exit 1
fi

#------------------------------------------------------
# Disable Swap
#------------------------------------------------------
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#------------------------------------------------------
# Kernel Modules & Sysctl Settings
#------------------------------------------------------
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

#------------------------------------------------------
# Install containerd Runtime
#------------------------------------------------------
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y containerd.io

containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

#------------------------------------------------------
# Install Kubernetes Components
#------------------------------------------------------
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | \
tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

#------------------------------------------------------
# Install conntrack (IMPORTANT for kubeadm)
#------------------------------------------------------
apt update -y
apt install -y conntrack
which conntrack
conntrack -V

#------------------------------------------------------
# Enable & Start kubelet
#------------------------------------------------------
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

echo "========== Kubernetes Common Setup Completed =========="

