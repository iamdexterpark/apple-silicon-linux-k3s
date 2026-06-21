# Runbook 07 — Rolling Upgrade (one node at a time)

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `_common` — profile-independent |
> | **Substrate** | a running K3s cluster |
> | **Cloud services used** | none |
> | **Identity model** | operator kubeconfig + node sudo |
> | **What changes under a different profile** | the kernel-pin caveat is Asahi-specific; on x86 the kernel upgrades freely |

**Goal:** patch the OS / K3s with zero workload downtime, one node at a time.
**Time:** ~10–15 min/node · **Risk:** medium · **Reversible:** yes (uncordon; K3s version pin)

> **Verify the kernel pin first.** On Asahi, a generic kernel bricks the node — the pin must survive
> every upgrade ([COST-MODEL §3](../../../COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying)).

## Prerequisites

- Healthy cluster (`99-cluster-checkout.sh` green). Maintenance window agreed.

## Steps

### 1. Confirm the kernel pin (Asahi)
```bash
ssh <node> 'grep "^exclude=kernel" /etc/dnf/dnf.conf'   # must be present BEFORE any dnf upgrade
```

### 2. Drain → upgrade → reboot → uncordon
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
ssh <node> 'sudo dnf upgrade --refresh && sudo systemctl reboot'
# wait for the node to come back Ready:
kubectl get nodes -w
kubectl uncordon <node>
```
Repeat for the next node only after the previous one is `Ready`.

### 3. K3s version bump (optional, separate change)
- Edit `INSTALL_K3S_VERSION`; re-run the installer on the **server first**, then the workers.

## Verification

```bash
kubectl get nodes -o wide                 # all Ready, target version
ssh <node> 'uname -r; getconf PAGE_SIZE'  # still an Asahi 16K kernel
bash provisioning/scripts/cluster/99-cluster-checkout.sh
```

## Rollback

- A node that won't come back Ready: `kubectl cordon` it, investigate, or swap the cold spare (rb 08).
- K3s: re-pin the prior `INSTALL_K3S_VERSION` and re-run the installer.

## Notes / Gotchas

- **Kernel upgrades wait on Asahi's coordinated release.** Don't force a kernel update outside it.
- Never upgrade two nodes at once — you'd risk losing quorum/capacity simultaneously.
