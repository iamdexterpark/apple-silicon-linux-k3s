#!/usr/bin/env bash
# gates/provisioning.sh — deliverable gate for a bare-metal provisioning repo
# (shell bring-up scripts + a Chef/Cinc cookbook). Sourced by validate.sh / preflight.sh
# when a provisioning/ dir is present. Sets `fail=1` on problems.
#
# Why this gate exists: the scaffold ships `manifests` (kustomize) and `terraform` gates only.
# A repo whose artifact is *shell + Chef* (no image, no HCL, no YAML to render) has no first-class
# gate, so we add one here. See _TEMPLATE-FRICTION-LOG.md F1 (the missing provisioning deliverable
# class). The linters are OPTIONAL (want, not need): bash and ruby ship a syntax checker built in,
# which is always run; shellcheck/cookstyle deepen the lint when present.

gate_preflight() {  # called by preflight.sh
  want shellcheck "brew install shellcheck   # deep shell lint (optional; bash -n always runs)"
  want ruby       "brew install ruby         # Chef cookbook syntax check (ruby -c)"
  want cookstyle  "gem install cookstyle     # Chef cookbook style lint (optional)"
}

gate_build() {  # called by validate.sh step 2
  shopt -s nullglob

  # 1. Shell: `bash -n` syntax check on every script (always available), shellcheck if present.
  local sh_files
  sh_files=$(find provisioning -type f -name '*.sh' | sort)
  if [ -z "$sh_files" ]; then
    echo "  ⚠ no shell scripts under provisioning/ (expected the bring-up scripts)"
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if bash -n "$f"; then echo "  ✓ bash -n $f"; else echo "  ✗ bash -n $f" >&2; fail=1; fi
  done <<< "$sh_files"

  if command -v shellcheck >/dev/null 2>&1; then
    # SC1091: don't follow sourced files; SC2086 word-splitting is intentional in a few installer pipelines.
    if echo "$sh_files" | xargs -r shellcheck -e SC1091 >/dev/null; then
      echo "  ✓ shellcheck clean"
    else
      echo "  ✗ shellcheck reported issues" >&2; fail=1
    fi
  else
    echo "  — shellcheck absent; ran bash -n only (install for deeper lint)"
  fi

  # 2. Chef/Cinc cookbook: ruby -c syntax check on recipes/attributes/metadata; cookstyle if present.
  if [ -d provisioning/chef ]; then
    if command -v ruby >/dev/null 2>&1; then
      local rb_ok=1
      while IFS= read -r rb; do
        [ -z "$rb" ] && continue
        if ! ruby -c "$rb" >/dev/null 2>&1; then echo "  ✗ ruby -c $rb" >&2; rb_ok=0; fail=1; fi
      done <<< "$(find provisioning/chef -type f -name '*.rb' | sort)"
      [ "$rb_ok" -eq 1 ] && echo "  ✓ ruby -c clean (chef cookbook)"
    else
      echo "  — ruby absent; skipped cookbook syntax check"
    fi
    if command -v cookstyle >/dev/null 2>&1; then
      if cookstyle provisioning/chef >/dev/null 2>&1; then echo "  ✓ cookstyle clean"; else echo "  ⚠ cookstyle reported style issues (non-fatal)"; fi
    fi

    # 3. Every node JSON must be valid JSON and name a hostname (the converge selects by hostname).
    if command -v python3 >/dev/null 2>&1; then
      for j in provisioning/chef/nodes/*.json; do
        if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['node_base']['hostname']" "$j" 2>/dev/null; then
          echo "  ✓ valid node json: $j"
        else
          echo "  ✗ invalid/incomplete node json: $j" >&2; fail=1
        fi
      done
    fi
  fi
}
