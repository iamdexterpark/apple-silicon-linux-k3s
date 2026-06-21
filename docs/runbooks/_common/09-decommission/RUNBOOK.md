# Runbook 09 — Decommission (retire cleanly, no orphans)

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `_common` — profile-independent (the boot-policy reset is Apple-specific) |
> | **Substrate** | a node (or whole cluster) being retired / resold / recycled |
> | **Cloud services used** | object store (delete the node's off-node backups) |
> | **Identity model** | operator kubeconfig, node sudo, macOS admin (for `bputil`) |
> | **What changes under a different profile** | `profile-x86-pxe` skips the Secure Enclave boot-policy reset |

**Goal:** remove the node from the cluster, wipe its storage, **reset the Secure Enclave boot
policy**, and delete its off-node backups — leaving nothing behind.
**Time:** ~15 min/node · **Risk:** high (destructive) · **Reversible:** no

## Prerequisites

- Confirm the node is truly being retired. This is destructive by design.

## Steps

### 1. Drain & deregister
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node>
ssh <node> 'sudo /usr/local/bin/k3s-uninstall.sh || sudo /usr/local/bin/k3s-agent-uninstall.sh'
```

### 2. Wipe Linux storage & reset the boot policy (in macOS 1TR)
- Boot to **1TR → macOS Recovery**.
- Delete the Linux APFS volume; reclaim space into macOS.
- Reset the Linux container's boot policy:
```bash
bputil -d -v <linux-volume-group-uuid>   # remove the Permissive Security LocalPolicy
```
(Now the node is back to a stock, Full-Security macOS box — safe to resell/recycle.)

### 3. Delete off-node backups
```bash
# remove this node's snapshots/PVC backups so they stop billing and don't orphan:
# object-store rm -r object-store://REPLACE_BUCKET/etcd/<node>/   (and /pvc/<node>/)
```

### 4. Archive
- Tag the repo `decommission/<date>` if retiring the whole cluster.

## Verification

```bash
kubectl get nodes                  # the node is gone
# macOS boots normally at Full Security; object-store listing shows no orphaned backup prefix
```

## Rollback

None — decommission is terminal. To re-add the node later, start from profile rb 02.

## Notes / Gotchas

- **Orphan checklist:** node deregistered? Linux partitions wiped? boot policy reset? off-node
  backups deleted? Any "no" is an orphan — config, capacity, or **bill** ([COST-MODEL §3](../../../COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying)).
- Resetting the boot policy is what makes the machine cleanly resellable — don't skip it.
