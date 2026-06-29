#!/usr/bin/env bash
# 20-converge.sh — run a local chef-solo (cinc) converge for THIS node. Idempotent.
# Picks the node JSON by hostname so the same command works on every node.
# Run with sudo on the node, after 10-bootstrap-chef.sh.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEF_DIR="${CHEF_DIR:-$HERE/../../chef}"

short="$(hostnamectl --static 2>/dev/null | cut -d. -f1)"
node_json="$CHEF_DIR/nodes/${short}.json"
[ -f "$node_json" ] || { echo "no node file for '$short' at $node_json"; exit 1; }

echo "Converging $short via $node_json ..."
cinc-client --local-mode \
  --config "$CHEF_DIR/solo.rb" \
  --json-attributes "$node_json" \
  --chef-license accept-silent

echo "Converge complete. Run 00-precheck.sh to gate."
