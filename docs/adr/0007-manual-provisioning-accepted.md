# ADR-0007 — Accept manual provisioning at the boot gate (don't fight the bootloader)

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §5](../HLD.md#5-the-secure-boot-path-as-a-pattern), [LLD §3](../LLD.md#3-the-boot-sequence-components)

---

## Context and Problem Statement

Apple Silicon's secure-boot chain has no PXE, no firmware boot menu, and no lights-out management.
Authorizing a third-party OS requires a physically-present, owner-authenticated action from One True
Recovery (1TR) — once per machine. This is the [keystone constraint](../HLD.md#2-the-workload--the-keystone-constraint).
**Do we try to automate the boot gate, or accept it and engineer around it?**

## Decision Drivers

- **D1 — Reality:** the gate is a hardware-enforced security property, not a software gap.
- **D2 — Effort allocation:** don't spend engineering on an unwinnable fight.
- **D3 — Remote operability:** we still need to power-cycle and console nodes remotely.
- **D4 — Recovery model:** the recovery story must respect the gate.
- **D5 — Scale honesty:** be clear about where this stops scaling.

## Considered Options

### Option A — Try to script the 1TR boot-policy authorization
- ➖ Impossible by design — the Secure Enclave requires physical presence + the owner key; no script
   can perform the power-button hold or the local signing (D1).
- **Verdict: rejected — categorically unautomatable; chasing it burns effort (D2).**

### Option B — Avoid the gate by staying on macOS (VM cluster)
- ➖ Sidesteps the gate but forfeits bare metal — already rejected ([ADR-0001](0001-bare-metal-linux-over-macos-vm.md)).
- **Verdict: rejected — wrong trade.**

### Option C — Accept the manual gate; minimize and engineer around it  ✅
- ➕ Shrink the manual phase to a tight, gated runbook (precheck → install → 1TR → bootstrap) (D2).
- ➕ Restore remote operability **out of band**: an external IP-KVM + a switched PDU give remote
   console + power past the no-IPMI wall (D3).
- ➕ Make recovery a **cold-spare swap**, not a remote re-image — because a wipe destroys the boot
   authorization and re-triggers the gate (D4).
- ➖ Provisioning is per-node and physical; it doesn't scale to a large fleet (D5) — accepted, scope
   is small edge.
- **Verdict: chosen — accept the toll, minimize it, and design recovery to never depend on remote re-provisioning.**

## Decision

Accept manual provisioning as a bounded, one-shot, per-node cost. Minimize it with a tight runbook,
restore remote power/console out of band, and make node recovery a physical swap of a pre-staged cold
spare rather than a remote reinstall.

## Consequences

**Positive**
- No effort wasted fighting the bootloader; the manual phase is a known, bounded toll.

**Negative / Risks accepted**
- Doesn't scale past a small fleet ([HLD R7](../HLD.md#13-risks--open-questions)); no remote
  re-provisioning ([HLD R4](../HLD.md#13-risks--open-questions)) — mitigated by OOB KVM/PDU + the cold spare.

## Revisit If

- We move to a substrate where unattended provisioning is possible (the
  [`profile-x86-pxe`](../runbooks/profile-x86-pxe/README.md) extension) — at which point this entire
  trade-off dissolves and earns a new ADR.
