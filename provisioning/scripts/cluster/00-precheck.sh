#!/usr/bin/env bash
# 00-precheck.sh — cluster-tier gate. Run on a node. Exit 0 = ready for the next phase.
# Validates host-config convergence AND (if K3s is installed) cluster health.
set -uo pipefail
fail=0
ok()  { printf "  [ OK ] %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }
note(){ printf "  [info] %s\n" "$1"; }

echo "== cluster-tier precheck =="

# --- Host config (from cluster runbook 01) ---
hostnamectl 2>/dev/null | grep -q "Static hostname" && ok "hostname set" || bad "hostname unset"
grep -q '^exclude=kernel' /etc/dnf/dnf.conf 2>/dev/null && ok "kernel pinned" || bad "kernel not pinned"

# Default route MUST be via the NODES gateway only (never the tagged sub-interfaces)
defifs=$(ip route 2>/dev/null | awk '/^default/{print $5}' | sort -u)
if [ "$(echo "$defifs" | wc -l)" -eq 1 ]; then ok "single default route ($defifs)"
else bad "multiple/zero default routes: [$defifs] — tagged interface leaking a route?"; fi

# Tagged interfaces present
ip -br link 2>/dev/null | grep -qE '\.208' && ok "SERVICES sub-if present" || note "no .208 sub-if (ok on spare)"
ip -br link 2>/dev/null | grep -qE '\.224' && ok "TELEMETRY sub-if present" || note "no .224 sub-if (ok on spare)"

# Services
systemctl is-active --quiet sshd    && ok "sshd active"    || bad "sshd down"
systemctl is-active --quiet chronyd && ok "chronyd active" || bad "chronyd down"
chronyc tracking >/dev/null 2>&1    && ok "time syncing"   || bad "chrony not tracking"

# --- K3s (if present) ---
if command -v k3s >/dev/null 2>&1; then
  if sudo k3s kubectl get nodes >/dev/null 2>&1; then
    ready=$(sudo k3s kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ')
    total=$(sudo k3s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    ok "k3s API up — ${ready}/${total} nodes Ready"
    [ "$ready" = "$total" ] && [ "$total" -ge 1 ] || bad "not all nodes Ready"
    sudo k3s etcd-snapshot ls >/dev/null 2>&1 && ok "etcd snapshots present" || note "no etcd snapshot yet"
  else
    bad "k3s installed but API not responding"
  fi
else
  note "k3s not installed yet (expected before cluster runbook 02)"
fi

echo
[ "$fail" -eq 0 ] && { echo "RESULT: READY"; exit 0; } || { echo "RESULT: NOT READY"; exit 1; }
