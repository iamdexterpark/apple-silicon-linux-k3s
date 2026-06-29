# ADR-0001 — Bare-metal Linux over a VM-on-macOS cluster

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §2](../HLD.md#2-the-workload--the-keystone-constraint), [HLD §6](../HLD.md#6-host-vs-orchestration-the-automation-boundary)

---

## Context and Problem Statement

The goal is a production-shaped Kubernetes cluster on Apple Silicon Mac minis. There are two ways to
get Linux Kubernetes onto a Mac: run it **inside a Linux VM hosted by macOS**, or **replace macOS
with bare-metal Linux**. The keystone constraint (the secure-boot wall, [HLD §2](../HLD.md#2-the-workload--the-keystone-constraint))
makes the metal path harder to provision — so the question is whether the metal is worth the wall.
**Where should Linux run: on the metal, or in a VM on macOS?**

## Decision Drivers

- **D1 — Resource efficiency:** maximize RAM/CPU available to workloads on small (8–16 GB) nodes.
- **D2 — Failure domain honesty:** one physical node = one Kubernetes failure domain.
- **D3 — I/O & scheduling fidelity:** no hidden virtualization tax under the kubelet.
- **D4 — Provisioning cost:** how hard is it to stand a node up and recover it.
- **D5 — Facing the hardware constraints:** 16K pages, Apple drivers — handled, not hidden.

## Considered Options

### Option A — Linux VM on macOS, K8s inside the guest
- ➕ Trivial to provision (macOS boots normally; no boot-policy wall); easy snapshots.
- ➖ Pays the macOS memory tax (4–8 GB/node gone) **and** the hypervisor tax (D1, D3).
- ➖ The host Mac is a single failure domain hiding *under* the cluster — "the Mac rebooted and took
  three nodes" (D2).
- ➖ The 16K-page reality is papered over by a guest kernel rather than faced (D5).
- **Verdict: rejected — buys easy provisioning by forfeiting the entire reason to use this hardware.**

### Option B — Bare-metal Linux (Fedora Asahi Remix) on the metal  ✅
- ➕ No host-OS layer: <250 MB host footprint, nearly all RAM is workload budget (D1).
- ➕ One node = one failure domain, which is what Kubernetes assumes (D2).
- ➕ No virtualization tax on I/O or scheduling (D3).
- ➕ Faces the 16K page size and Apple hardware directly (D5).
- ➖ Provisioning is harder — the boot wall forces a manual gate, and the host can't A/B-rollback (D4).
- **Verdict: chosen — the manual gate is a bounded, one-shot cost ([ADR-0007](0007-manual-provisioning-accepted.md)); the efficiency and failure-domain wins are permanent.**

## Decision

Replace macOS with bare-metal Fedora Asahi Remix. Pay the one-time manual provisioning cost to win
the recurring efficiency, failure-domain, and fidelity benefits.

## Consequences

**Positive**
- The cluster is the *only* tenant of each node's resources; the failure model is honest.

**Negative / Risks accepted**
- Provisioning cannot be unattended ([HLD R7](../HLD.md#13-risks--open-questions)) — mitigated by a
  tight gated runbook ([ADR-0007](0007-manual-provisioning-accepted.md)).
- The host is mutable, no A/B rollback ([HLD R2](../HLD.md#13-risks--open-questions)) — mitigated per
  [ADR-0008](0008-mutable-host-over-immutable-ab.md).

## Revisit If

- A future Mac gains standard unattended provisioning, or a VM host appears with near-zero memory and
  I/O tax that also exposes one-failure-domain semantics cleanly.
