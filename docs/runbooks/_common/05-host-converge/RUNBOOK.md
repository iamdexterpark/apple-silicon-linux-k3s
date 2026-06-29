# Runbook 05 — Host Converge (idempotent)

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `_common` — profile-independent (same cookbook on any substrate) |
> | **Substrate** | any bootstrapped Linux node (bare-metal Asahi or x86) |
> | **Cloud services used** | none |
> | **Identity model** | local sudo; **no secrets converged** (join token is injected later) |
> | **What changes under a different profile** | only the NIC name attribute (`end0` on Asahi); the cookbook is identical |

**Goal:** the node matches the declared `node_base` baseline — hostname, static NODES connection,
default-deny firewall, key-only SSH, kernel pin, time. Re-running corrects drift.
**Time:** ~5 min · **Risk:** low · **Reversible:** yes (edit attributes, re-converge)

## Prerequisites

- Node bootstrapped (profile rb 04). A node JSON exists for this hostname under
  `provisioning/chef/nodes/`.

## Steps

### 1. Install the config client (idempotent)
```bash
sudo bash provisioning/scripts/cluster/10-bootstrap-chef.sh   # installs cinc-client if absent
```

### 2. Converge this node
```bash
sudo bash provisioning/scripts/cluster/20-converge.sh         # picks nodes/<hostname>.json by hostname
```

## Verification

```bash
sudo bash provisioning/scripts/cluster/00-precheck.sh
# RESULT: READY — hostname set, kernel pinned, single default route via NODES,
#                 sshd/chronyd active, time syncing (+ cluster health if K3s present)
```

## Rollback

The converge is declarative — to change a setting, edit `nodes/<host>.json` or the cookbook and
re-run `20-converge.sh`. To undo a firewall port, drop it from the attribute list and re-converge.

## Notes / Gotchas

- **Secrets are never converged.** The K3s join token is injected at agent-join time
  ([ADR-0006](../../../adr/0006-chef-cinc-solo-host-config.md)).
- The converge enforces a **single default route via NODES** — a tagged sub-interface leaking a
  default route is a common misconfig the precheck catches.
