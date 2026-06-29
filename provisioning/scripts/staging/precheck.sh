#!/usr/bin/env bash
# precheck.sh — validate that an Apple Silicon Mac is ready for the Asahi installer.
# Run from a macOS Terminal on the TARGET Mac. Exit 0 = ready.
set -uo pipefail

ASAHI_HOME="https://asahilinux.org/fedora/"      # source of truth for the live installer URL
MIN_FREE_GB=80
fail=0
ok()   { printf "  [ OK ] %s\n" "$1"; }
bad()  { printf "  [FAIL] %s\n" "$1"; fail=1; }

echo "== Apple Silicon Asahi precheck =="

# 1. Architecture / model
if [ "$(uname -m)" = "arm64" ]; then ok "arm64 (Apple Silicon)"; else bad "not arm64 — Asahi targets Apple Silicon only"; fi
model=$(sysctl -n hw.model 2>/dev/null || echo unknown)
case "$model" in Macmini*) ok "model: $model";; *) printf "  [warn] model: %s (tested on Mac mini)\n" "$model";; esac

# 2. FileVault must be OFF
if fdesetup status 2>/dev/null | grep -qi "FileVault is Off"; then ok "FileVault off"; else bad "FileVault is ON — disable and wait for full decryption"; fi

# 3. Free space on the APFS container
free_gb=$(df -g / 2>/dev/null | awk 'NR==2{print $4}')
if [ "${free_gb:-0}" -ge "$MIN_FREE_GB" ]; then ok "free space: ${free_gb} GB (>= ${MIN_FREE_GB})"; else bad "free space ${free_gb:-?} GB < ${MIN_FREE_GB} GB"; fi

# 4. Internet + installer URL reachable
if curl -fsI "$ASAHI_HOME" >/dev/null 2>&1; then ok "Asahi homepage reachable"; else bad "cannot reach $ASAHI_HOME (check internet)"; fi

# 5. Wired link up
if ifconfig 2>/dev/null | grep -A3 -E "^en[0-9]" | grep -q "status: active"; then ok "an Ethernet interface is active"; else printf "  [warn] no active wired Ethernet detected — wired is strongly recommended\n"; fi

echo
if [ "$fail" -eq 0 ]; then echo "RESULT: READY — proceed to install-asahi.sh"; exit 0
else echo "RESULT: NOT READY — resolve [FAIL] items and re-run"; exit 1; fi
