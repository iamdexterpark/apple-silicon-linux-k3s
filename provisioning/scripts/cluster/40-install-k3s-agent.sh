#!/usr/bin/env bash
# 40-install-k3s-agent.sh — join a worker (node-2 / node-3) to the cluster. Run with sudo.
# Token comes from the environment (read from the password manager); never hardcoded.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
: "${K3S_TOKEN:?set K3S_TOKEN (from the password manager)}"

K3S_VERSION="${K3S_VERSION:-v1.34.x+k3s1}"
SERVER_URL="${SERVER_URL:-https://10.0.32.2:6443}"   # node-1 NODES IP
NODE_IP="${NODE_IP:?set NODE_IP, e.g. 10.0.32.3}"
NODE_NAME="${NODE_NAME:?set NODE_NAME, e.g. node-2}"

echo "Joining $NODE_NAME ($NODE_IP) to $SERVER_URL ..."
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_URL="$SERVER_URL" \
  K3S_TOKEN="$K3S_TOKEN" \
  INSTALL_K3S_EXEC="agent --node-ip=${NODE_IP} --node-name=${NODE_NAME}" \
  sh -

echo "Joined. Verify from the operator machine: kubectl get nodes -o wide"
