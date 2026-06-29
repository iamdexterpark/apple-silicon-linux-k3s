# Diagrams

Mermaid sources for the design docs. The files under [`src/`](src/) are the **single source
of truth** for every diagram in this repo. The build tool
([`../../scripts/build_docs.py`](../../scripts/build_docs.py)) injects each
`src/*.mermaid` file into the matching

```
<!-- START_GENERATED:docs/diagrams/src/<name>.mermaid -->
... (auto-filled) ...
<!-- END_GENERATED:docs/diagrams/src/<name>.mermaid -->
```

block across `README.md` and every `*.md` under `docs/` (README, HLD, LLD, ADRs, runbooks).
Edit the `.mermaid` file, run the build, and every copy updates — no hand-syncing.

| Source | What it shows |
|---|---|
| `hero.mermaid` | The whole story in one picture — stock Mac mini → boot wall → bare-metal Linux → converged node → K3s → Ready cluster. (README hero.) |
| `hld_overview.mermaid` | Vendor-AGNOSTIC primitives across the manual/code bands: secure-boot gate, host/orchestration/state/secret/segmentation/redundancy primitives. (HLD lead.) |
| `lld_topology.mermaid` | Vendor-SPECIFIC 3-node shape: M1 Mac minis, Asahi kernel-16k, the three VLANs with placeholder addresses, MetalLB/Longhorn, PiKVM/PDU, cold spare. (LLD lead.) |
| `architecture_at_a_glance.mermaid` | The bring-up dependency chain (script-by-script), colored by automation class: manual → idempotent → declarative. (README + HLD.) |
| `lifecycle.mermaid` | The node/cluster lifecycle state machine: stage → Linux-on-metal → converge → cluster → operate → upgrade/degrade → decommission. |

## Conventions

- One concept per diagram. If it needs a legend, it's two diagrams.
- Color load-bearing nodes consistently (e.g. red = the problem/constraint, green = the
  desired end state). Keep a stable palette across diagrams in the repo.
- Mermaid over ASCII art, always.

## Rendering

GitHub renders Mermaid in fenced ```` ```mermaid ```` blocks natively, so injected copies
display inline. Regenerate after editing a source:

```bash
python3 scripts/build_docs.py
```
