#!/usr/bin/env bash
# preflight.sh — verify the toolchain needed to validate this repo's deliverable.
# Required-tool checks via need(); optional via want(). Deliverable-specific needs come from
# the matching scripts/gates/<type>.sh (gate_preflight). Exits non-zero if anything required missing.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
missing=0

need() { # need <bin> <install-hint>  (required: fail if absent)
  if command -v "$1" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1 not found — install: $2" >&2; missing=1; fi
}
want() { # want <bin> <install-hint>  (optional: warn, never fail)
  if command -v "$1" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  — $1 not found (optional) — install when needed: $2"; fi
}

# Always needed.
need python3 "brew install python3"

# Deliverable-specific needs, owned by the gate.
GATE=""
if   [ -d manifests ];    then GATE="scripts/gates/manifests.sh"
elif [ -d terraform ];    then GATE="scripts/gates/terraform.sh"
elif [ -d provisioning ]; then GATE="scripts/gates/provisioning.sh"   # bare-metal: shell + Chef
fi
if [ -n "$GATE" ] && [ -f "$GATE" ]; then . "$GATE"; declare -f gate_preflight >/dev/null && gate_preflight; fi

[ "$missing" -eq 0 ] && echo "✓ preflight clean" || exit 1
