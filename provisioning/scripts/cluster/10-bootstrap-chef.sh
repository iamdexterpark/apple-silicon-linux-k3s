#!/usr/bin/env bash
# 10-bootstrap-chef.sh — install cinc-client (open-source Chef) if absent. Idempotent.
# Run with sudo on the node. Config management is local-converge; no Chef server.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

if command -v cinc-client >/dev/null 2>&1; then
  echo "cinc-client already present: $(cinc-client --version | head -1)"
  exit 0
fi

echo "Installing cinc-client (open-source Chef distribution)..."
# Official Cinc omnibus installer; pin the channel for reproducibility.
curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc -c stable

cinc-client --version | head -1
echo "Done. Next: 20-converge.sh"
