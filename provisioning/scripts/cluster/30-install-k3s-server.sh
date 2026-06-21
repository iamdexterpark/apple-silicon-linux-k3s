#!/usr/bin/env bash
# 30-install-k3s-server.sh — install the K3s control plane on node-1. Idempotent-ish
# (re-running re-applies the pinned version + flags). Run with sudo on node-1.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

K3S_VERSION="${K3S_VERSION:-v1.34.x+k3s1}"   # confirm exact patch; commit to k3s-version.txt
NODE_IP="${NODE_IP:-10.0.32.2}"              # NODES VLAN primary IP
NODE_NAME="${NODE_NAME:-node-1}"

echo "Installing K3s server $K3S_VERSION on $NODE_NAME ($NODE_IP)..."
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  INSTALL_K3S_EXEC="server \
    --cluster-init \
    --disable=traefik \
    --disable=servicelb \
    --node-ip=${NODE_IP} \
    --node-name=${NODE_NAME} \
    --tls-san=${NODE_IP} \
    --etcd-snapshot-retention=30" \
  sh -

echo "Waiting for the API..."
for i in $(seq 1 30); do
  if k3s kubectl get nodes >/dev/null 2>&1; then break; fi; sleep 2
done
k3s kubectl get nodes

echo
echo "Join token (seal into the password manager + data bag; do NOT commit to git):"
cat /var/lib/rancher/k3s/server/node-token
