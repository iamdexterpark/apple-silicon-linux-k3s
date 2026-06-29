#!/usr/bin/env bash
# 30-install-k3s-server.sh — install the K3s control plane on node-1. Idempotent-ish
# (re-running re-applies the pinned version + flags). Run with sudo on node-1.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

K3S_VERSION="${K3S_VERSION:-v1.34.x+k3s1}"   # confirm exact patch; commit to k3s-version.txt
NODE_IP="${NODE_IP:-10.0.32.2}"              # NODES VLAN primary IP
NODE_NAME="${NODE_NAME:-node-1}"

# LESSON (PF-K1, diagnosed live): K3s MERGES /etc/rancher/k3s/config.yaml with the systemd
# ExecStart flags — it does not let one override the other. If you ALSO ship a config.yaml that
# sets node-ip, you get `node-ip: <ip>,<ip>` -> kubelet rejects ("must contain either a single IP
# or a dual-stack pair") -> kubelet dies -> k3s crashloops (etcd raft term climbs; the API server
# flaps so `kubectl` intermittently succeeds, masking the loop). Pick ONE source. This script's
# source of truth is INSTALL_K3S_EXEC below; do NOT also write node-ip/tls-san into a config.yaml.
# Tell that you hit it: `systemctl is-active k3s` == `activating` + journal
# "Shutdown request received: kubelet exited".
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
