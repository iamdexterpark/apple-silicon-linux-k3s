# Runbook 08 — Cold-Spare Swap & Break-Fix

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | a running cluster with one dead/failing node + a pre-staged spare |
> | **Cloud services used** | object store (etcd snapshot, on control-plane recovery) |
> | **Identity model** | the failed node's static identity, reassigned to the spare |
> | **What changes under a different profile** | `profile-x86-pxe` recovers by *remote re-image*, not a physical swap |

**Goal:** restore cluster capacity by swapping a failed node with the staged cold spare; if it was
the control plane, restore etcd.
**Time:** ~10–20 min · **Risk:** medium · **Reversible:** yes

> Recovery is a **swap, not a re-image** — a wipe destroys the boot authorization and re-triggers the
> manual 1TR gate. That's why the spare exists ([ADR-0002](../../../adr/0002-secondhand-multi-node-over-single-new.md)).

## Prerequisites

- The cold spare is **already staged** (rb 02–05 done, on the shelf, converge-able). An un-staged
  spare turns a 10-minute swap into a 45-minute on-site stand-up.
- Latest etcd snapshot replicated off-node (for control-plane loss).

## Steps

### 1. Triage & power
```bash
kubectl get nodes -o wide                 # which node, which role
# try a hard power-cycle first via the switched PDU — many "failures" are a hung host
```

### 2a. Worker loss → swap
```bash
kubectl drain <dead-node> --ignore-daemonsets --delete-emptydir-data || true
kubectl delete node <dead-node>
# cable the spare, assign the dead node's static identity (node JSON), converge, then join:
sudo bash provisioning/scripts/cluster/20-converge.sh
K3S_TOKEN=REPLACE_FROM_SECRET_STORE NODE_IP=<dead-node-ip> NODE_NAME=<dead-node-name> \
  sudo -E bash provisioning/scripts/cluster/40-install-k3s-agent.sh
```

### 2b. Control-plane (`node-1`) loss → swap + etcd restore
```bash
# stage the spare as node-1's identity, converge, then restore etcd from the latest snapshot:
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.34.x+k3s1 \
  INSTALL_K3S_EXEC="server --cluster-init --cluster-reset \
    --cluster-reset-restore-path=/path/to/snapshot.db" sh -
# start normally, then rejoin the workers.
```

## Verification

```bash
bash provisioning/scripts/cluster/99-cluster-checkout.sh   # RESULT: HEALTHY, full node count restored
```

## Rollback

If the swap misbehaves, the failed node's workloads are already rescheduled onto survivors — the
cluster is degraded-but-serving. Re-attempt the join, or stage a second spare.

## Notes / Gotchas

- Pull the failed node for **bench diagnosis off the critical path** — there's no vendor RMA; the
  spare *is* the support contract ([OPERATIONS support model](../../../OPERATIONS.md#support-model--break-fix)).
- **Test the restore before you need it** — a snapshot nobody has restored is not a backup.
