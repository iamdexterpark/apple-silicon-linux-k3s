# ADR-0006 — Chef/Cinc local-mode for idempotent host config

**Status:** Accepted
**Date:** 2026-06-19
**Deciders:** Platform Engineering
**Related:** [HLD §6](../HLD.md#6-host-vs-orchestration-the-automation-boundary), [LLD §6](../LLD.md#6-host-configuration-chefcinc-node_base)

---

## Context and Problem Statement

Past the manual boot gate, the host must be configured **idempotently** — hostname, static network,
default-deny firewall, key-only SSH, the kernel pin, time — with zero snowflakes and drift correction
by re-converge. The candidates are a hand-script, an agent-based config-management server, or an
agentless/local-mode config-management tool. **How do we converge host configuration?**

## Decision Drivers

- **D1 — Idempotency:** re-running converges, never double-applies.
- **D2 — No server dependency:** a 3-node edge fleet shouldn't need a config-management server.
- **D3 — Per-node specialization from one definition:** node-1/2/3 differ only by hostname + address.
- **D4 — Auditability:** the desired state is a reviewable artifact, not tribal shell.
- **D5 — Licensing/cost:** the tool itself should be free to run on a portfolio cluster.

## Considered Options

### Option A — A bespoke shell `setup.sh`
- ➕ Zero dependencies; fastest to write (D2).
- ➖ **You own idempotency** by hand (D1); it's a sequence of actions, not declared state (D4);
   per-node logic becomes branching (D3).
- **Verdict: rejected as the host-config primitive — kept only for the thin staging bootstrap.**

### Option B — Agent + server config management (Chef Infra Server / Puppet primary)
- ➕ Central control, reporting, drift dashboards (D4).
- ➖ A control server is overkill and a new failure domain for 3 edge nodes (D2); more to operate.
- **Verdict: rejected — server overhead doesn't fit a tiny fleet.**

### Option C — Ansible (agentless, push over SSH)
- ➕ Agentless, declarative-ish, popular (D2, D4).
- ➕ A perfectly reasonable alternative — would also satisfy the drivers.
- ➖ Push model needs an operator control node + SSH reachability at converge time; the converge isn't
   *on the node* (a wash, not a loss).
- **Verdict: rejected narrowly — Cinc-solo runs the converge locally on the node with no control node and no per-product license question (D5).**

### Option D — Chef/Cinc local-mode (`chef-solo` / `cinc-client --local-mode`)  ✅
- ➕ Idempotent resources with guards (D1); no Chef server (D2); node JSON selects per-node attributes
   from one cookbook (D3); the cookbook + node JSON are the reviewable artifact (D4).
- ➕ **Cinc** is the fully-open-source build of Chef — no commercial license to run (D5).
- ➖ Ruby DSL is a dependency on the node (small, acceptable).
- **Verdict: chosen — declared, idempotent, server-less host config from one cookbook.**

## Decision

Converge host config with Cinc (open-source Chef) in local mode: one `node_base` cookbook, per-node
attributes under `nodes/<host>.json`, run by `20-converge.sh`. **Secrets (the K3s join token) are
never converged** — they're injected at runtime at agent-join time.

## Consequences

**Positive**
- Re-running the converge corrects drift; the host's desired state is a reviewed, version-controlled
  cookbook; no control server to operate or secure.

**Negative / Risks accepted**
- Ruby + cinc-client are an on-node dependency — installed idempotently by `10-bootstrap-chef.sh`.
- Local-mode has no central reporting — acceptable at this fleet size; the precheck script is the gate.

## Revisit If

- The fleet grows past where local-mode + node JSON scales, or central drift reporting becomes a
  requirement (then reconsider an agentless push or a server).
