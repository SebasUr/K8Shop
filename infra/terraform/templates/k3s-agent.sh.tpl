#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl iptables iproute2

TOKEN="${token}"
SERVER_IP="${server_private_ip}"
SERVER_URL="https://$SERVER_IP:6443"
HEALTHCHECK_URL="https://$SERVER_IP:6443/healthz"
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

until curl -k --silent --fail "$HEALTHCHECK_URL"; do
  echo "Waiting for k3s server at $HEALTHCHECK_URL"
  sleep 5
done

export K3S_TOKEN="$TOKEN"
INSTALL_K3S_EXEC="agent --server $SERVER_URL --node-ip $NODE_IP --advertise-address $NODE_IP"

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh
chmod +x /tmp/install-k3s.sh
INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" /tmp/install-k3s.sh
