#!/usr/bin/env bash
# validate.sh — local mirror of the CI gate. Exits non-zero on any failure.
# Deliverable-specific logic lives in scripts/gates/<type>.sh (sourced below).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

# --- detect the deliverable + load its gate -------------------------------------------------
GATE=""
if   [ -d manifests ];    then GATE="scripts/gates/manifests.sh"
elif [ -d terraform ];    then GATE="scripts/gates/terraform.sh"
elif [ -d provisioning ]; then GATE="scripts/gates/provisioning.sh"   # bare-metal: shell + Chef
fi
if [ -n "$GATE" ] && [ -f "$GATE" ]; then . "$GATE"; fi

echo "==> 0/3  Preflight (toolchain)"
bash scripts/preflight.sh || { echo "✗ preflight failed — install missing tools above." >&2; exit 1; }

echo "==> 1/3  Doc-sync check (diagrams injected)"
# Robust on a fresh/untracked repo: run the injector, then assert a second pass has no work.
python3 scripts/build_docs.py >/dev/null
if python3 scripts/build_docs.py | grep -qiE 'updated|injected|changed'; then
  echo "✗ Docs out of sync — build_docs.py still had work on a second pass. Commit the result." >&2
  fail=1
else
  echo "✓ Docs in sync (idempotent second pass clean)"
fi

echo "==> 2/3  Deliverable lint/build"
if [ -n "$GATE" ] && declare -f gate_build >/dev/null; then
  gate_build
else
  echo "  (no recognized deliverable dir / gate — nothing to build)"
fi

echo "==> 3/3  Secret-leak scan (value-bearing files only)"
if git grep -nIE \
   '(BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|password\s*[:=]\s*["'\'']?[^"'\'' ]{6,})' \
   -- . ':!*.md' ':!docs/**' 2>/dev/null; then
  echo "✗ Possible secret material in tracked files." >&2
  fail=1
else
  echo "✓ No obvious secret material"
fi

[ "$fail" -eq 0 ] && echo "✅ validate passed" || { echo "❌ validate failed"; exit 1; }
