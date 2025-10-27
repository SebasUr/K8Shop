#!/usr/bin/env bash
set -euo pipefail

# This script provisions the EKS cluster defined in infra/terraform/eks.tf
# using eksctl instead of Terraform. It expects that the VPC and subnet
# infrastructure already exist (for example provisioned by Terraform).
#
# Required environment variables:
#   EKS_VPC_ID               VPC where the cluster will live (e.g. vpc-0123456789)
#   EKS_PRIVATE_SUBNET_IDS   Comma-separated list of private subnet IDs (subnet-abc,subnet-def,...)
# Optional environment variables:
#   AWS_REGION / EKS_REGION  AWS region (defaults to us-east-1)
#   EKS_CLUSTER_NAME         Cluster name (default bookstore-eks)
#   EKS_K8S_VERSION          Kubernetes version (default 1.30)
#   EKS_NODE_INSTANCE_TYPE   Node instance type (default t3.large)
#   EKS_NODE_DESIRED         Desired node count (default 3)
#   EKS_NODE_MIN             Minimum node count (default 3)
#   EKS_NODE_MAX             Maximum node count (default 9)
#   EKS_NODE_DISK_SIZE       Node volume size in GiB (default 20)
#   EKS_PUBLIC_SUBNET_IDS    Optional comma-separated list of public subnets for outbound access.
#
# Usage example:
#   export EKS_VPC_ID=$(terraform output -raw vpc_id)
#   export EKS_PRIVATE_SUBNET_IDS=$(terraform output -json private_subnets | jq -r 'join(",")')
#   ./scripts/create-eks-with-eksctl.sh

require_bin() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: required binary '$bin' not found in PATH" >&2
    exit 1
  fi
}

require_bin eksctl
require_bin jq

EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-bookstore-eks}
EKS_REGION=${EKS_REGION:-${AWS_REGION:-us-east-1}}
EKS_K8S_VERSION=${EKS_K8S_VERSION:-"1.30"}
EKS_NODE_INSTANCE_TYPE=${EKS_NODE_INSTANCE_TYPE:-t3.large}
EKS_NODE_DESIRED=${EKS_NODE_DESIRED:-3}
EKS_NODE_MIN=${EKS_NODE_MIN:-3}
EKS_NODE_MAX=${EKS_NODE_MAX:-9}
EKS_NODE_DISK_SIZE=${EKS_NODE_DISK_SIZE:-20}

if [[ -z "${EKS_VPC_ID:-}" ]]; then
  echo "EKS_VPC_ID environment variable is required" >&2
  exit 1
fi

if [[ -z "${EKS_PRIVATE_SUBNET_IDS:-}" ]]; then
  echo "EKS_PRIVATE_SUBNET_IDS environment variable is required (comma-separated subnet IDs)" >&2
  exit 1
fi

IFS=',' read -r -a private_subnets <<< "${EKS_PRIVATE_SUBNET_IDS}"
IFS=',' read -r -a public_subnets <<< "${EKS_PUBLIC_SUBNET_IDS:-}" || true

config_file=$(mktemp -t eksctl-config-XXXX.yaml)
cleanup() {
  rm -f "$config_file"
}
trap cleanup EXIT

cat >"$config_file" <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${EKS_CLUSTER_NAME}
  region: ${EKS_REGION}
  version: "${EKS_K8S_VERSION}"

vpc:
  id: ${EKS_VPC_ID}
  subnets:
    private:
EOF

for idx in "${!private_subnets[@]}"; do
  subnet_id="${private_subnets[$idx]}"
  printf "      private-%d:\n        id: %s\n" "$idx" "$subnet_id" >>"$config_file"
done

if [[ ${#public_subnets[@]} -gt 0 && -n "${public_subnets[0]}" ]]; then
  cat >>"$config_file" <<EOF
    public:
EOF
  for idx in "${!public_subnets[@]}"; do
    subnet_id="${public_subnets[$idx]}"
    printf "      public-%d:\n        id: %s\n" "$idx" "$subnet_id" >>"$config_file"
  done
fi

cat >>"$config_file" <<EOF

managedNodeGroups:
  - name: general
    instanceType: ${EKS_NODE_INSTANCE_TYPE}
    desiredCapacity: ${EKS_NODE_DESIRED}
    minSize: ${EKS_NODE_MIN}
    maxSize: ${EKS_NODE_MAX}
    privateNetworking: true
    volumeSize: ${EKS_NODE_DISK_SIZE}
    iam:
      withAddonPolicies:
        autoScaler: true
        cloudWatch: true
        ebs: true
        efs: true
        fsx: false
    tags:
      Project: bookstore
      ManagedBy: eksctl

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
EOF

echo "Creating EKS cluster '${EKS_CLUSTER_NAME}' in ${EKS_REGION} using eksctl..."
eksctl create cluster -f "$config_file"

echo "Cluster creation request submitted. Run 'eksctl get cluster --name ${EKS_CLUSTER_NAME}' to monitor status."
