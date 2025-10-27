#!/usr/bin/env bash
set -euo pipefail

echo "This project now provisions Kubernetes via k3s on EC2." >&2
echo "The eksctl-based workflow has been retired; see infra/terraform/k3s-cluster.tf and project docs." >&2
exit 1
