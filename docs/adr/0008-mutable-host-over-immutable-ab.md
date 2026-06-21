# ADR-0008 — Mutable pinned host over an immutable A/B OS

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §6](../HLD.md#6-host-vs-orchestration-the-automation-boundary), [ADR-0007](0007-manual-provisioning-accepted.md)

---

## Context and Problem Statement

Modern GitOps practice favors an **immutable host OS** (Talos, Fedora CoreOS) with A/B partition
swaps and remote re-provisioning. It's the right default on commodity hardware. The question is
whether it's achievable *here*, given the boot gate and the Asahi enablement story. **Do we run an
immutable A/B host, or a minimal mutable host pinned at the kernel?**

## Decision Drivers

- **D1 — Feasibility on Apple Silicon:** does the mechanism even work on this boot chain.
- **D2 — Drift control:** keep nodes identical, correct drift cheaply.
- **D3 — Upgrade safety:** an upgrade must never produce an unbootable node.
- **D4 — Remote re-provisioning:** the headline immutable benefit.
- **D5 — Operational simplicity for a tiny fleet.**

## Considered Options

### Option A — Immutable A/B host (Talos / CoreOS style)
- ➕ Atomic upgrades, rollback to the previous slot, declarative host (D2, D3 in theory).
- ➖ **No standard firmware for A/B slot switching** — Apple Silicon has no UEFI boot-slot mechanism;
   you go through the m1n1 layer, which doesn't expose the hooks (D1).
- ➖ Generic immutable images **lack the Asahi boot stub + device trees** and crash at boot (D1).
- ➖ The headline benefit — **remote wipe-and-reprovision** — is exactly what the boot gate forbids; a
   wipe destroys the boot authorization ([ADR-0007](0007-manual-provisioning-accepted.md)) (D4).
- **Verdict: rejected — its core mechanics are unavailable on this hardware.**

### Option B — Minimal mutable host, kernel-pinned, drift-corrected by converge  ✅
- ➕ Works with the Asahi enablement as-shipped (D1).
- ➕ Drift corrected by re-running the idempotent converge ([ADR-0006](0006-chef-cinc-solo-host-config.md)) (D2).
- ➕ **Kernel pin** (`exclude=kernel …`) makes the one catastrophic upgrade impossible (D3).
- ➕ Simple: one converge, no slot management (D5).
- ➖ No atomic A/B rollback (D4) — accepted; the host is thin and cattle, the cold spare is the
   safety net.
- **Verdict: chosen — the only feasible model here, made safe by the kernel pin + thin-host posture.**

## Decision

Run a minimal, mutable Fedora Asahi Remix host. Keep it identical across nodes via the idempotent
converge, pin the kernel to block unbootable upgrades, and treat the host as disposable cattle backed
by the cold spare. No immutable A/B OS.

## Consequences

**Positive**
- A working, maintainable host today; upgrade safety from the pin; drift control from the converge.

**Negative / Risks accepted**
- No atomic host rollback ([HLD R2](../HLD.md#13-risks--open-questions)) — mitigated by minimal host
  state, the kernel pin, and the cold spare; a bricked node is a swap, not a debugging session.

## Revisit If

- An Asahi-aware immutable image with working A/B on Apple Silicon appears, or the substrate switches
  to x86 where immutable A/B is mature.
