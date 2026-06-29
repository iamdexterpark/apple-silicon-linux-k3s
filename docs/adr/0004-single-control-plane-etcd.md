# ADR-0004 — Single control plane over a 3-node etcd HA topology

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §7](../HLD.md#7-cluster-shape--the-etcd-ha-trade-off), [LLD §9](../LLD.md#9-state-snapshots--restore--concrete-commands)

---

## Context and Problem Statement

K3s supports an HA control plane: an odd number of server nodes running embedded etcd as a voting
quorum. The reflex on a 3-node cluster is to make all three voting servers. But those three nodes are
also the workers — the control plane competes with the workloads for the same scarce RAM. **What
control-plane topology do we run on a 3-node cluster?**

## Decision Drivers

- **D1 — Workload headroom:** control-plane overhead stolen from workloads.
- **D2 — Availability of the API:** can we schedule/change during a node loss.
- **D3 — Operational complexity:** quorum management, split-brain, etcd ops.
- **D4 — Recovery story:** how we get back after a control-plane loss.
- **D5 — Workload continuity:** do running pods survive a control-plane outage.

## Considered Options

### Option A — 3-node embedded-etcd HA (all servers)
- ➕ API survives a single control-plane node loss; no manual restore (D2).
- ➖ Three etcd members on three nodes — quorum overhead competes with workloads (D1).
- ➖ etcd quorum/split-brain management on tiny nodes is real day-2 surface (D3).
- **Verdict: rejected — pays a permanent resource + complexity tax to avoid a rare, recoverable event.**

### Option B — Single control-plane + worker, two pure workers  ✅
- ➕ Minimal control-plane overhead; maximum workload headroom (D1).
- ➕ Trivial topology; no quorum to manage (D3).
- ➕ **Running pods keep running on the workers during a control-plane outage** — the kubelet doesn't
   need the API server to sustain existing pods (D5).
- ➖ **API is down until restore** during a control-plane loss (D2) — accepted.
- ➖ Recovery is a *procedure* (restore etcd snapshot onto the spare), not a hot failover (D4).
- **Verdict: chosen — the API outage is bounded and recoverable; workloads never stop; the resource win is permanent.**

## Decision

Run a single control-plane-plus-worker node (`node-1`, embedded etcd via `--cluster-init`) and two
pure workers. Treat control-plane loss as a documented restore-from-snapshot onto the cold spare, not
a hot-failover event.

## Consequences

**Positive**
- Workloads survive any single-node loss; the control plane takes minimal resources.

**Negative / Risks accepted**
- Control-plane loss = API/scheduling outage until restore ([HLD R1](../HLD.md#13-risks--open-questions)) —
  mitigated by off-node etcd snapshots + a tested restore drill ([LLD §9](../LLD.md#9-state-snapshots--restore--concrete-commands)).
- The restore depends on a fresh snapshot — a [COST-MODEL §3](../COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying) trap.

## Revisit If

- The cluster grows enough that an API outage's blast radius (scheduling, ingress changes) outweighs
  the HA overhead, or node RAM grows enough that 3 voting members is free.
