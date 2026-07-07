#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_SRC="${PROJECT_DIR}/terraform/k8s-cluster.pem"
KEY_DST="/tmp/k8s-cluster.pem"
INVENTORY="${PROJECT_DIR}/ansible/inventory/hosts.ini"
ANSIBLE_DIR="${PROJECT_DIR}/ansible"

if [ ! -f "$KEY_SRC" ]; then
  echo "ERROR: SSH key not found at ${KEY_SRC}"
  echo "Run 'terraform apply' first to generate it."
  exit 1
fi

cp "$KEY_SRC" "$KEY_DST"
chmod 600 "$KEY_DST"

sed -i 's|\.\./terraform/k8s-cluster\.pem|/tmp/k8s-cluster.pem|g' "$INVENTORY"

rm -rf /tmp/ansible_facts_cache

export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"

cd "$ANSIBLE_DIR"
ansible-playbook -i inventory/hosts.ini site.yml "$@"
