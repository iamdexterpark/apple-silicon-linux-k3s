#!/usr/bin/env bash
# checkout.sh — operational acceptance check for an Asahi node. Exit 0 = ready.
# Run on the Linux console to verify node state.
set -uo pipefail
fail=0
ok()  { printf "  [ OK ] %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }

echo "== Asahi node acceptance =="

# OS / arch
[ "$(uname -m)" = "aarch64" ] && ok "aarch64" || bad "not aarch64"
uname -r | grep -q asahi && ok "Asahi kernel: $(uname -r)" || bad "not an Asahi kernel"
[ "$(getconf PAGE_SIZE)" = "16384" ] && ok "16K pages" || bad "page size $(getconf PAGE_SIZE) != 16384"

# Network
IFACE=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')
if [ -n "${IFACE:-}" ] && nmcli -t -f GENERAL.STATE device show "$IFACE" 2>/dev/null | grep -q "100"; then
  ok "ethernet up ($IFACE)"
else bad "ethernet not connected"; fi
curl -fsI https://fedoraproject.org >/dev/null 2>&1 && ok "internet reachable" || bad "no internet"

# Wi-Fi disabled
nmcli radio wifi 2>/dev/null | grep -qi disabled && ok "wifi disabled" || bad "wifi still enabled"

# Time sync
chronyc tracking >/dev/null 2>&1 && ok "chronyd present" || bad "chronyd not running"

# Base packages
for p in git jq dig vim; do command -v "$p" >/dev/null 2>&1 && ok "pkg: $p" || bad "missing: $p"; done

echo
[ "$fail" -eq 0 ] && { echo "RESULT: READY"; exit 0; } || { echo "RESULT: NOT READY"; exit 1; }
