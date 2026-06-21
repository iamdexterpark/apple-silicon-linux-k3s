# ADR-0003 — K3s over full upstream Kubernetes

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §7](../HLD.md#7-cluster-shape--the-etcd-ha-trade-off), [LLD §8](../LLD.md#8-k3s-install-parameters--version-pin)

---

## Context and Problem Statement

The orchestration primitive can be a full upstream Kubernetes distribution (kubeadm + separate etcd +
the full control-plane component set) or a lightweight, single-binary distribution. On 8–16 GB nodes
that also run workloads, the control plane's resource appetite is not free. **Which Kubernetes
distribution runs on the metal?**

## Decision Drivers

- **D1 — Control-plane footprint:** RAM/CPU the control plane takes from workloads.
- **D2 — Operational simplicity:** install, upgrade, day-2 surface area on a tiny fleet.
- **D3 — Batteries with replaceable batteries:** sane defaults, but swappable (CNI, LB, storage).
- **D4 — aarch64 + 16K-page support:** must run on the Apple Silicon kernel.
- **D5 — Production fidelity:** real multi-node scheduling, not a toy.

## Considered Options

### Option A — Full upstream Kubernetes (kubeadm)
- ➕ Canonical; maximum component control; matches big-cluster mental models (D5).
- ➖ Heavy control plane spends scarce node RAM on itself, not workloads (D1).
- ➖ More moving parts to install/upgrade/debug on a 3-node edge fleet (D2).
- **Verdict: rejected — the footprint and ops surface don't fit small nodes.**

### Option B — A lightweight single-binary distribution (K3s)  ✅
- ➕ Single Go binary, low memory; leaves the hardware to the work (D1).
- ➕ Batteries-included but each replaceable — disable the bundled ingress/servicelb and bring
   MetalLB/Longhorn deliberately (D3).
- ➕ aarch64 + 16K pages supported since v1.25.10, no special build flags (D4).
- ➕ Embedded etcd via `--cluster-init`; real multi-node scheduling (D5).
- ➖ Some upstream-vs-K3s differences to remember (defaults, paths).
- **Verdict: chosen — same Kubernetes API, a fraction of the footprint, fits the hardware.**

## Decision

Run K3s, pinned to a known-good version, installed from the upstream script (not the distro package).
Disable the bundled `traefik` and `servicelb`; bring ingress and L2 load-balancing deliberately.

## Consequences

**Positive**
- Nearly all node RAM stays available to workloads; install/upgrade is one binary.

**Negative / Risks accepted**
- K3s-specific defaults/paths differ from upstream — documented in the LLD; mitigated by pinning the
  version and committing the exact patch to `k3s-version.txt`.

## Revisit If

- The cluster grows to where a full control plane's component granularity is needed, or a managed
  control plane becomes the target ([profile-x86-pxe / managed switch](../LLD.md#11-environment-profiles)).
