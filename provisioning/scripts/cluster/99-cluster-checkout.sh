#!/usr/bin/env bash
# 99-cluster-checkout.sh — post-bring-up acceptance. Run from the operator machine
# with KUBECONFIG pointed at the cluster. Exit 0 = platform healthy.
set -uo pipefail
fail=0
ok()  { printf "  [ OK ] %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }

DNS_VIP="${DNS_VIP:-10.0.208.5}"
TEL_VIP="${TEL_VIP:-10.0.224.1}"

echo "== cluster acceptance =="

# Nodes
ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ')
total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$ready" = "$total" ] && [ "$total" -ge 3 ] && ok "$ready/$total nodes Ready" || bad "$ready/$total nodes Ready"

# Default storageclass
kubectl get storageclass 2>/dev/null | grep -q 'longhorn.*(default)' && ok "longhorn default SC" || bad "longhorn not default"

# No LoadBalancer stuck pending
pending=$(kubectl get svc -A 2>/dev/null | grep LoadBalancer | grep -c '<pending>')
[ "$pending" -eq 0 ] && ok "all LoadBalancer VIPs assigned" || bad "$pending LoadBalancer svc pending (check MetalLB sub-if names)"

# DNS through the VIP
if command -v dig >/dev/null 2>&1; then
  dig @"$DNS_VIP" example.com +short +time=2 +tries=1 >/dev/null 2>&1 && ok "DNS resolves via $DNS_VIP" || bad "DNS VIP $DNS_VIP not answering"
fi

# Core platform pods Running
for ns in longhorn-system metallb-system cert-manager sealed-secrets ingress-nginx dns telemetry; do
  bad_pods=$(kubectl -n "$ns" get pods --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed"' | wc -l | tr -d ' ')
  [ "${bad_pods:-1}" -eq 0 ] && ok "ns/$ns healthy" || bad "ns/$ns has $bad_pods non-Running pods"
done

echo
echo "Manual checks (not automatable from here):"
echo "  - Telemetry trust split: nc -zvu $TEL_VIP 514 should be DENIED from a user plane, OPEN from a node."
echo "  - Backups: confirm <bucket>/etcd/ and <bucket>/pvc/dns/ populated after first run."
echo
[ "$fail" -eq 0 ] && { echo "RESULT: HEALTHY"; exit 0; } || { echo "RESULT: ISSUES — see [FAIL]"; exit 1; }
