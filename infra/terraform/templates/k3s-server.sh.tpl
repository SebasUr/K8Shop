#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl iptables iproute2

TOKEN="${token}"
IMDS_BASE="http://169.254.169.254/latest"
IMDS_TOKEN=""

fetch_metadata() {
  local path="$1"
  local result=""

  if [ -z "$IMDS_TOKEN" ]; then
    IMDS_TOKEN=$(curl -s -X PUT "$IMDS_BASE/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "")
  fi

  if [ -n "$IMDS_TOKEN" ]; then
    result=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "$IMDS_BASE/$path" || echo "")
  else
    result=$(curl -s "$IMDS_BASE/$path" || echo "")
  fi

  echo "$result"
}

NODE_IP=$(fetch_metadata meta-data/local-ipv4)
if [ -z "$NODE_IP" ]; then
  NODE_IP=$(hostname -I | awk '{print $1}')
fi

PUBLIC_IP=$(fetch_metadata meta-data/public-ipv4)
NODE_NAME=$(hostname)

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh
chmod +x /tmp/install-k3s.sh

SAN_ARGS="--tls-san $NODE_IP"
if [[ -n "$PUBLIC_IP" ]]; then
  SAN_ARGS="$SAN_ARGS --tls-san $PUBLIC_IP"
fi

INSTALL_K3S_EXEC="server --node-name $NODE_NAME --node-ip $NODE_IP --advertise-address $NODE_IP $SAN_ARGS --disable traefik --write-kubeconfig-mode 0644" \
K3S_TOKEN="$TOKEN" /tmp/install-k3s.sh

mkdir -p /home/ubuntu
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig
chown ubuntu:ubuntu /home/ubuntu/kubeconfig

TARGET_IP="$NODE_IP"
if [[ -n "$PUBLIC_IP" ]]; then
  TARGET_IP="$PUBLIC_IP"
fi
sed -i "s/127.0.0.1/$TARGET_IP/" /home/ubuntu/kubeconfig
