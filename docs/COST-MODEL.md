# Apple Silicon → Linux → K3s — Cost Model

> **Business accumen first.** The economic argument in full; the README carries only the summary.
> Two cost planes matter, and conflating them hides the real levers — so keep them separate:
>
> 1. **Infrastructure plane** — what it costs to *own and run the cluster*: hardware CapEx
>    (amortized), the N+1 spare, and power. This is where the secondhand-Apple-Silicon thesis is won.
> 2. **Operational / runtime plane** — what it costs to *operate the platform*: provisioning toil
>    (gated by the manual boot wall), node re-image/replacement, and steady-state cluster ops. This
>    repo has **no AI-runtime / model-inference plane** — there is no token meter, no LLM, no
>    per-turn cost — so the AI-agent boilerplate is removed and this plane is the IaC/ops analogue
>    (see the friction log).
>
> Every figure carries a `Source` (vendor/list pricing URL or a stated assumption). Unsourced
> numbers are a draft, not a deliverable. **All dollar figures are order-of-magnitude estimates for a
> single reference cluster; secondhand prices vary by market and condition. Treat them as a sizing
> model, not a quote.**

---

## 1. Infrastructure Plane — Own-and-Run the Cluster

The thesis: for the price of **one** new single box, you buy **three** secondhand nodes — genuine
fault tolerance inside the same capital budget — at a tiny power and noise footprint.

### 1.1 Hardware (CapEx) — the core comparison

| Dimension | 1× new M4 mini / x86 box | **3× secondhand M1 minis (this design)** |
|---|---|---|
| CapEx | ~$800–1,000 | **~$900 total** (~$300/node) |
| Aggregate compute | ~10 cores | **24 cores** (12P + 12E) |
| Aggregate RAM | 16 GB | **24 GB** (3× 8 GB) |
| Fault tolerance | none — box dies, service dies | **N+1** — node dies, cluster survives |
| Idle power | ~7 W (M4) / 30–50 W (x86) | **~7 W/node** (~21 W total) |
| Peak power | ~35 W (M4) / 150 W+ (x86) | **~30 W/node** (~90 W total) |
| Noise | silent (M4) / audible (x86) | **silent (<12 dB)** |
| Warranty | yes (new) | **none** (secondhand) — mitigated by the spare |

> *Source / assumptions:* secondhand M1 mini street price ~$250–350 (used-marketplace bands, varies
> by RAM/condition); new M4 mini base list ~$599+ and a comparable-RAM/SSD config climbs toward
> $900–1,000 ([apple.com/mac-mini](https://www.apple.com/mac-mini/)); M-series idle/peak draw is
> single-digit/low-tens of watts per Apple's own efficiency figures; an x86 mini-PC/SFF build draws
> materially more at idle. All bands, not quotes.

### 1.2 The N+1 cold spare (the warranty substitute)

Secondhand hardware has **no AppleCare, no RMA**. In an enterprise that's usually a dealbreaker; at
small-scale edge we convert it into a capital decision: **keep a 4th identical node on the shelf.**

| Item | Cost | Note |
|---|---|---|
| Cold spare (1× M1 mini) | ~$300 (one-time CapEx) | pre-staged; swap-in on failure |
| Effective fleet | 3 live + 1 spare = **~$1,200** | still ≈ the price of one well-specced new box |

The capital saved by buying secondhand is **reinvested into redundancy** rather than paid to a
warranty. A dead node is a 5-minute swap, not a multi-day repair cycle ([ADR-0002](adr/0002-secondhand-multi-node-over-single-new.md)).

### 1.3 Power (OpEx)

| Scenario | Avg draw | Monthly kWh | Monthly $ @ $0.15/kWh |
|---|---|---|---|
| 3× M1 @ ~10 W avg | ~30 W | ~21.6 kWh | **~$3.2** |
| 1× x86 box @ ~60 W avg | ~60 W | ~43.2 kWh | ~$6.5 |

> *Source / assumption:* draw figures from §1.1; $0.15/kWh is a generic blended rate — substitute
> your tariff. Power is a rounding error against CapEx; the point is the **silent, low-heat envelope**
> that lets the cluster live on a shelf, not in a datacenter.

### 1.4 Infra-plane rollup (amortized)

| Class | Monthly est. | Basis |
|---|---|---|
| Hardware (3 live, 5-yr straight-line) | ~$15 | $900 / 60 mo |
| Cold spare (amortized) | ~$5 | $300 / 60 mo |
| Power | ~$3 | §1.3 |
| **Infra subtotal** | **~$23/mo** | the entire platform floor for a fault-tolerant 3-node cluster |

The aggressive lifecycle bonus: because Kubernetes abstracts the hardware, the fleet can span
generations (M1→M4) at once. Aging nodes aren't retired — they're **repurposed** (an 8 GB M1 drops to
a utility/control role, freeing a newer node for heavier workloads), stretching the amortization
further.

---

## 2. Operational / Runtime Plane — Operate the Platform

> This plane is where the manual boot wall makes itself felt. The infra floor (§1) is trivially
> cheap; the *operating* cost is dominated by **human toil at provisioning time** and **the cost of a
> node loss** — not by infrastructure. (Network/IaC analogue of the template's AI-runtime plane.)

### 2.1 Provisioning toil (the manual-gate tax)

The unit of work is "bring one node from a stock box to a Ready cluster member."

| Phase | Automation class | Time/node (assumed) | Why |
|---|---|---|---|
| Staging (precheck → Asahi install → 1TR sign → bootstrap) | **manual** | ~30–45 min | the boot wall: physical presence, owner-authenticated, one-shot |
| Host converge (Cinc local-mode) | idempotent | ~3–5 min | re-runnable, no human past kickoff |
| K3s bring-up (server or agent join) | scripted | ~3–5 min | pinned installer |
| Acceptance (checkout) | scripted | ~2 min | gate |

**Toil model:** `nodes × manual-min/node × loaded $/hr`. Assumption: 3 nodes + 1 spare = 4 stagings,
~40 min each, $75/hr loaded.
- One-time fleet stand-up: `4 × 40 min × $75/hr` ≈ **$200** of engineer time, *once*.
- The non-obvious lever: **the manual cost is per-node and one-shot, not recurring.** It does not
  scale with change volume (host changes are a re-converge; cluster changes are declarative). The
  manual wall is a fixed entry toll, not a meter.

### 2.2 Node re-image / replacement cost (the asymmetric event)

Because remote re-provisioning is **forbidden by the boot chain** (no PXE, no remote wipe), a node
loss is a *physical* event. This is the line item the architecture is built around.

| Factor | Without a cold spare | **With the N+1 spare (this design)** |
|---|---|---|
| Recovery action | source + buy + stage a new node | cable the shelf spare, assign identity, converge, join |
| MTTR | days (procurement + manual staging) | **~5–15 min** (swap) + etcd restore if it was the control plane |
| Capacity during recovery | degraded/at-risk | full (spare restores N) |
| Cost driver | downtime + rush procurement | the spare's sunk CapEx (§1.2) |

**Replacement model:** `node-failure-rate × MTTR × $/downtime-min`. The spare collapses MTTR from
days to minutes, so the expected downtime cost is dominated by *whether you hold a spare*, not by the
failure rate — which is exactly why the spare is the design's load-bearing OpEx decision.

### 2.3 Steady-state cluster ops (the small, real line items)

No per-token meter, but real operating costs hide in the plumbing:

- **Off-node snapshot storage.** etcd snapshots + PVC backups to an object store: cents/mo at this
  scale — a rounding error, but it must exist (the snapshot is the recovery truth).
- **Rolling upgrades.** `drain → dnf upgrade → reboot → uncordon`, one node at a time; wall-clock,
  not dollars. **Kernel upgrades wait on the Asahi project's coordinated release** (the pin blocks
  generic kernels) — a *cadence* constraint, not a cost.
- **Operator attention.** Best-effort/business-hours for a small edge fleet; the data plane keeps
  serving through a control-plane blip.

### 2.4 Operational-plane rollup

| Line item | Cost | Lever |
|---|---|---|
| Fleet stand-up (one-time) | ~$200 toil | tight gated runbook; manual phase minimized |
| Per-change ops | ~$0 marginal | idempotent converge + declarative cluster state |
| Node replacement | spare CapEx (sunk) + ~10 min | N+1 cold spare collapses MTTR |
| Snapshot storage + CI | ~$1–5/mo | rounding error |
| **Operational net** | **dominated by the one-time manual toll + the spare** | the wall is a fixed toll, not a meter |

---

## 3. ⚠️ Operational Cost Traps (read before deploying)

The bare-metal analogue of the template's AI-runtime traps. Each is a control the design addresses,
not a disclaimer.

- **The boot wall is a *per-node, physical* toll — budget presence, not just money.** You cannot
  remote-provision node #4 at 2 a.m. **Stage the cold spare *before* you need it**; an un-staged
  spare turns a 10-minute swap into a 45-minute on-site stand-up during an incident.
- **A wipe destroys the boot authorization.** Cleaning a node (or a careless `bputil` reset) drops
  the local boot-policy keys and re-triggers the manual 1TR gate. **Never wipe a node you can't
  physically reach.** (The decommission runbook does this *deliberately*, at end-of-life.)
- **An auto-upgrade can install an unbootable kernel.** A generic aarch64 `kernel` package lacks the
  Apple device trees and bricks boot. **The converge pins the kernel** (`exclude=kernel …`); verify
  the pin survived before any `dnf upgrade`. (This is the heartbeat-footgun analogue: a routine
  background action with a catastrophic edge.)
- **Single control plane = a snapshot you must actually test.** Losing `node-1` means restoring etcd
  onto the spare. **A snapshot nobody has restored is not a backup** — schedule the restore drill.
- **16K-page workloads fail silently late.** An image that assumes 4 KB pages may pass CI on an x86
  runner and crash only on the node. **Vet page-size compatibility at admission**, not in production.
- **Orphaned object-store snapshots keep billing.** On decommission, a forgotten backup prefix or
  bucket bleeds. **Decommission verifies zero orphans** (see [OPERATIONS Day-N](OPERATIONS.md#day-n--decommission-retire-cleanly)).

**Guardrails to wire in:**
- Pre-stage + periodically re-validate the **cold spare** (it's only insurance if it boots).
- **Kernel-pin assertion** in the host-config precheck before every upgrade window.
- **Scheduled etcd snapshot + a calendared restore drill.**
- **Page-size admission check** in CI/image vetting.
- Decommission **orphan checklist** for off-node backups.

---

## 4. Total Cost of Ownership (rollup)

| Plane | Cost | Driver | Lever |
|---|---|---|---|
| Infrastructure | ~$23/mo amortized (+ ~$1,200 sunk CapEx incl. spare) | hardware + spare + power | secondhand multi-node beats single-new on fault tolerance per dollar |
| Operational | ~$200 one-time toil + sunk spare | manual boot wall + node replacement | tight gated runbook; N+1 spare; everything-else-is-code |
| **TCO** | a fault-tolerant 3-node edge K8s for **≈ the price of one new box**, **~$23/mo** to run | | |

*ROI / break-even:* against a single new box, the design delivers **N+1 fault tolerance and 24 cores
/ 24 GB for roughly the same capital** as one machine with **none of those**, then runs at ~$23/mo.
The premium you pay — a one-time ~$200 manual stand-up and the discipline of a cold spare — buys an
availability posture a single box simply cannot offer. It pays for itself the first time a node dies
and the cluster doesn't.
