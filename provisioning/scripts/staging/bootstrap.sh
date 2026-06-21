#!/usr/bin/env bash
# bootstrap.sh — idempotent base config for a freshly-installed Asahi node.
# Run with sudo on the Linux console after the Fedora first-boot wizard. Safe to re-run.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

log() { printf "\n== %s ==\n" "$1"; }

log "verify Asahi 16K kernel"
uname -r | grep -q asahi || { echo "NOT running an Asahi kernel ($(uname -r))"; exit 1; }
[ "$(getconf PAGE_SIZE)" = "16384" ] && echo "16K pages confirmed" || echo "WARN: page size $(getconf PAGE_SIZE) (expected 16384)"

log "detect ethernet interface"
IFACE=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')
[ -n "${IFACE:-}" ] || { echo "no ethernet device found"; exit 1; }
echo "ethernet: $IFACE"
nmcli device show "$IFACE" | grep -E "GENERAL.STATE|IP4.ADDRESS" || true

log "check internet reachability"
curl -fsI https://fedoraproject.org >/dev/null 2>&1 && echo "internet OK" || { echo "no internet"; exit 1; }

log "install base packages (idempotent)"
dnf -y install git vim jq bind-utils chrony containerd 2>/dev/null || dnf -y install git vim jq bind-utils chrony

log "disable Wi-Fi on headless node"
nmcli radio wifi off || true
systemctl mask wpa_supplicant.service 2>/dev/null || true

log "pin the Asahi 16K kernel"
if ! grep -q "kernel-16k" /etc/dnf/dnf.conf 2>/dev/null; then
  # exclude generic kernels so an upgrade can't replace the only one that boots
  echo "exclude=kernel kernel-core kernel-modules" >> /etc/dnf/dnf.conf
  echo "added kernel exclude to dnf.conf"
fi

log "enable + check time sync"
systemctl enable --now chronyd
sleep 2
chronyc tracking 2>/dev/null | head -3 || true

log "done"
echo "Run checkout.sh to confirm acceptance."
