#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_SRC="${PROJECT_DIR}/terraform/k8s-cluster.pem"
KEY_DST="/tmp/k8s-cluster.pem"

if [ ! -f "$KEY_SRC" ]; then
  echo "ERROR: SSH key not found at ${KEY_SRC}"
  echo "Run 'terraform apply' first to generate it."
  exit 1
fi

cp "$KEY_SRC" "$KEY_DST"
chmod 600 "$KEY_DST"

BASTION_IP=$(cd "${PROJECT_DIR}/terraform" && terraform output -raw bastion_public_ip)
MASTER_IP=$(cd "${PROJECT_DIR}/terraform" && terraform output -json master_private_ips | python3 -c "import sys,json;print(json.load(sys.stdin)[0])")

echo "Connecting to master ${MASTER_IP} via bastion ${BASTION_IP}..."
ssh -i "$KEY_DST" \
  -o StrictHostKeyChecking=no \
  -o ProxyCommand="ssh -i ${KEY_DST} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${BASTION_IP}" \
  ubuntu@"${MASTER_IP}" "$@"
