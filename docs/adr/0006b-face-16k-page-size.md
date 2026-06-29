# ADR-0006b — Face the 16K page size head-on (admission criterion, not a workaround)

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §9](../HLD.md#9-the-16k-page-constraint-as-an-architectural-property), [LLD §4](../LLD.md#4-the-16k-page-kernel--workload-gotchas)

---

## Context and Problem Statement

Apple Silicon maps memory in **16 KB pages**, not the 4 KB that most binaries quietly assume. The
host kernel requires it; K3s/containerd/kubelet handle it transparently. The risk is in *workloads* —
allocators and embedded databases with hardcoded 4 KB assumptions crash. **How do we handle the
non-standard page size?**

## Decision Drivers

- **D1 — Correctness:** workloads must not crash on memory mapping.
- **D2 — Honesty of the platform:** don't hide a real constraint behind a layer.
- **D3 — Efficiency:** no extra layer purely to fake 4 KB (that forfeits the bare-metal win, [ADR-0001](0001-bare-metal-linux-over-macos-vm.md)).
- **D4 — Early detection:** catch incompatibility before production, not at 2 a.m.

## Considered Options

### Option A — Run a 4 KB guest kernel in a VM to mask the page size
- ➕ Most software "just works" with no vetting (D1, naively).
- ➖ Reintroduces the VM tax this whole design rejects ([ADR-0001](0001-bare-metal-linux-over-macos-vm.md)) (D3).
- **Verdict: rejected — masking the constraint forfeits the reason to be on the metal.**

### Option B — Hope; deploy and fix crashes reactively
- ➖ Failures surface in production, often as cryptic `SIGSEGV`/`EINVAL` (D4).
- **Verdict: rejected — turns a known property into recurring incidents.**

### Option C — Treat 16K compatibility as a workload admission criterion  ✅
- ➕ The constraint is faced directly and *gated*: vet allocators/DBs on the real page size before
   adoption; rebuild allocators with `--with-lg-page=14`; dump/restore page-bound DBs (D1, D2, D4).
- ➕ No masking layer — the bare-metal efficiency is preserved (D3).
- ➖ Adds a vetting step to image adoption (cheap, one-time per image).
- **Verdict: chosen — page-size compatibility is a deliberate gate, not a surprise.**

## Decision

Make 16K-page compatibility an **admission criterion**: vet every image/allocator/embedded DB on a
16K target before adoption; rebuild or replace what fails. `getconf PAGE_SIZE == 16384` is checked at
node acceptance. Do not introduce a 4 KB layer to hide the page size.

## Consequences

**Positive**
- Workload incompatibilities are caught at adoption, on a 16K runner — not in production.

**Negative / Risks accepted**
- A vetting step per new image ([HLD R3](../HLD.md#13-risks--open-questions)) — mitigated by making it
  part of CI/image review; an image that faults here is the defect, file upstream.

## Revisit If

- Upstream ecosystems make 16K-clean builds universal (then vetting becomes a formality), or the
  workload set is fixed and pre-vetted.
