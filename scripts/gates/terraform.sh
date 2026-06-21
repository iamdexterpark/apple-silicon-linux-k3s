#!/usr/bin/env bash
# gates/terraform.sh — deliverable gate for an OpenTofu/Terraform repo.
# Sourced by validate.sh when a terraform/ dir is present. Sets `fail=1` on problems.
# Engine-agnostic: prefers `tofu`, falls back to `terraform` (the design should stay engine-neutral).

# Resolve the IaC engine once.
TF_BIN="$(command -v tofu || command -v terraform || true)"

gate_preflight() {  # called by preflight.sh
  if [ -n "$TF_BIN" ]; then
    echo "  ✓ $(basename "$TF_BIN") (IaC engine)"
  else
    echo "  ✗ no IaC engine — install: brew install opentofu   (or: brew install terraform)" >&2
    missing=1
  fi
}

gate_build() {  # called by validate.sh step 2
  if [ -z "$TF_BIN" ]; then echo "  ✗ no tofu/terraform on PATH" >&2; fail=1; return; fi
  ( cd terraform \
      && "$TF_BIN" fmt -check -recursive \
      && "$TF_BIN" init -backend=false -input=false >/dev/null \
      && "$TF_BIN" validate ) \
    && echo "  ✓ $(basename "$TF_BIN") fmt -check + validate" \
    || { echo "  ✗ $(basename "$TF_BIN") fmt/validate failed" >&2; fail=1; }
}
