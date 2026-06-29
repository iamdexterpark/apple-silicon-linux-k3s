#!/usr/bin/env bash
# gates/manifests.sh — deliverable gate for a Kustomize/K8s manifests repo.
# Sourced by validate.sh when a manifests/ dir is present. Sets `fail=1` on problems.
# Owns its own toolchain needs (see gate_preflight) and lint rules (gate_build).

gate_preflight() {  # called by preflight.sh
  need kustomize "brew install kustomize"
  want kubectl   "brew install kubectl   # needed to apply, not to build"
}

gate_build() {  # called by validate.sh step 2
  shopt -s nullglob
  for k in manifests/platform manifests/base manifests/overlays/*/; do
    [ -f "$k/kustomization.yaml" ] || continue
    if kustomize build "$k" >/dev/null; then echo "  ✓ kustomize build $k"; else echo "  ✗ kustomize build $k" >&2; fail=1; fi
  done
  # Production overlays must pin images by @sha256 (a base rename can silently drop the overlay digest).
  for o in manifests/overlays/*/; do
    [ -f "$o/kustomization.yaml" ] || continue
    if kustomize build "$o" 2>/dev/null | grep -q 'image:.*@sha256:'; then
      echo "  ✓ digest-pinned: $o"
    else
      echo "  ⚠ no @sha256 digest in rendered image for $o (placeholder ok pre-fill; real overlays MUST pin)"
    fi
  done
}
