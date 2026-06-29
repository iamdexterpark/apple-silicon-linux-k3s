# ADR-0002 — Secondhand multi-node over a single new machine

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [COST-MODEL §1](../COST-MODEL.md#1-infrastructure-plane--own-and-run-the-cluster), [HLD §11](../HLD.md#11-redundancy--the-cold-spare-posture)

---

## Context and Problem Statement

A fixed capital budget (≈ the price of one well-specced new mini) can be spent two ways: **one new
machine** (warranty, higher single-thread, one big RAM pool) or **three secondhand machines** plus a
spare (fault tolerance, more aggregate cores/RAM, no warranty). **How do we spend the hardware budget
for an edge cluster?**

## Decision Drivers

- **D1 — Fault tolerance:** survive a single hardware failure without downtime.
- **D2 — Aggregate capacity per dollar:** cores + RAM available to workloads.
- **D3 — Recovery time:** how fast a dead node is back in service.
- **D4 — Support/warranty risk:** the cost of having no RMA path.
- **D5 — Power/noise envelope:** it has to live on a shelf, silently.

## Considered Options

### Option A — One new machine (M4 mini / x86 box)
- ➕ Warranty/AppleCare (D4); highest single-thread; one large RAM pool.
- ➖ **Single point of failure** — the box dies, the service dies (D1).
- ➖ Same budget buys one node's worth of cores/RAM (D2).
- **Verdict: rejected — no amount of single-box reliability is fault tolerance.**

### Option B — Three secondhand M1 minis + a cold spare  ✅
- ➕ N+1 fault tolerance within the same budget (D1); 24 cores / 24 GB aggregate (D2).
- ➕ A dead node is a ~10-min swap with the pre-staged spare (D3).
- ➕ ~7 W/node, silent (D5).
- ➖ **No warranty/RMA** (D4) — accepted, and *converted* into a capital decision (the spare).
- **Verdict: chosen — fault tolerance per dollar wins for edge; the warranty gap is bought back with the spare.**

## Decision

Buy a cluster of secondhand Apple Silicon nodes plus one cold spare, rather than a single new
machine. Reinvest the capital saved on warranty into the spare.

## Consequences

**Positive**
- Genuine N+1 redundancy and more aggregate capacity than the single-box alternative, same budget.
- Mixed-generation scaling: aging nodes get repurposed, not retired.

**Negative / Risks accepted**
- No vendor RMA ([HLD R6](../HLD.md#13-risks--open-questions)) — the cold spare *is* the support
  contract; bench diagnosis happens off the critical path.
- The recovery posture depends on the spare being staged and bootable (a [COST-MODEL §3](../COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying) trap).

## Revisit If

- The workload needs more single-node RAM than secondhand minis offer, or a hard enterprise
  requirement for vendor warranty enters scope.
