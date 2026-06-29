# ADR-0005 — Fedora Asahi Remix as the host distribution

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §5](../HLD.md#5-the-secure-boot-path-as-a-pattern), [LLD §3](../LLD.md#3-the-boot-sequence-components)

---

## Context and Problem Statement

Bare-metal Linux on Apple Silicon depends entirely on hardware enablement: the bootloader stub, the
device trees, the GPU/IOMMU support, and a kernel built for the 16K page size. That enablement is the
work of the **Asahi Linux** project, and it is delivered most completely through a specific
distribution. **Which Linux distribution do we run on the metal?**

## Decision Drivers

- **D1 — Hardware enablement completeness:** boot stub, device trees, drivers, 16K kernel.
- **D2 — Upstream maintenance:** who keeps the Apple support current.
- **D3 — Server/headless fit:** minimal footprint, no desktop baggage.
- **D4 — Package + kernel-pin ergonomics:** can we lock the kernel cleanly.
- **D5 — Ecosystem familiarity:** standard tooling for converge + K3s.

## Considered Options

### Option A — A generic aarch64 server distro (stock Debian/Ubuntu/Fedora)
- ➕ Familiar; huge ecosystem (D5).
- ➖ Upstream images compile generic aarch64 kernels with **no Apple device trees / boot stub** — they
   crash immediately at boot (D1). This is the immutable-CoreOS failure mode too.
- **Verdict: rejected — without Asahi enablement the hardware doesn't boot Linux at all.**

### Option B — Asahi-based Arch (the reference Asahi target)
- ➕ Closest to upstream Asahi development; bleeding-edge enablement (D1, D2).
- ➖ Rolling release + less of a server-image story; more day-2 churn for a fleet (D3).
- **Verdict: rejected for a fleet — excellent for a workstation, more moving parts for edge nodes.**

### Option C — Fedora Asahi Remix (Server)  ✅
- ➕ First-class, jointly-maintained Asahi enablement: m1n1 stub, device trees, `kernel-16k` (D1, D2).
- ➕ A headless **Server** edition with a small footprint (D3).
- ➕ `dnf` kernel excludes give a clean kernel pin (D4); standard RPM tooling (D5).
- ➖ Kernel upgrades are gated on Asahi's coordinated releases (a cadence constraint, not a defect).
- **Verdict: chosen — the most complete, maintained enablement in a server-shaped package.**

## Decision

Run Fedora Asahi Remix (Server, headless) on the metal, pin the `kernel-16k` via `dnf` excludes, and
track the Asahi project for coordinated kernel releases.

## Consequences

**Positive**
- The hardware boots and runs Linux with maintained drivers; the kernel pin is a one-line exclude.

**Negative / Risks accepted**
- Kernel upgrade cadence follows Asahi, not Fedora's general stream ([OPERATIONS rolling upgrades](../OPERATIONS.md#rolling-upgrades)) —
  accepted; the pin enforces it.

## Revisit If

- Asahi enablement lands in a different distribution that better fits fleet/server operations, or
  upstream mainline absorbs the Apple support.
