# Runbook 06 — K3s Bring-Up

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | converged Fedora Asahi Remix nodes on one L2 segment |
> | **Cloud services used** | object store for off-node etcd snapshots |
> | **Identity model** | K3s join token (runtime secret, never committed) |
> | **What changes under a different profile** | nothing in the scripts; only `--node-ip` values + the NIC name |

**Goal:** a Ready 3-node K3s cluster — control plane on `node-1`, workers joined, acceptance green.
**Time:** ~15 min · **Risk:** medium · **Reversible:** yes (`k3s-uninstall.sh`)

## Prerequisites

- Every node converged (rb 05) and `00-precheck.sh` green. Pin confirmed.

## Steps

### 1. Control plane — `node-1`
```bash
sudo bash provisioning/scripts/cluster/30-install-k3s-server.sh
# prints the join token from /var/lib/rancher/k3s/server/node-token
```
**Seal the token into your password manager.** Never commit it; never put it in a node JSON.

### 2. Workers — `node-2`, `node-3`
```bash
K3S_TOKEN=REPLACE_FROM_SECRET_STORE NODE_IP=10.0.32.3 NODE_NAME=node-2 \
  sudo -E bash provisioning/scripts/cluster/40-install-k3s-agent.sh
# repeat with NODE_IP=10.0.32.4 NODE_NAME=node-3
```

### 3. Off-node etcd snapshot replication
- Confirm `--etcd-snapshot-retention=30` is set (it is, in the server script) and wire the cron that
  syncs `/var/lib/rancher/k3s/server/db/snapshots/` to `object-store://REPLACE_BUCKET/etcd/`.

## Verification

```bash
# from the operator machine with KUBECONFIG set:
bash provisioning/scripts/cluster/99-cluster-checkout.sh   # RESULT: HEALTHY
# nodes Ready, default storageclass replicated, no LoadBalancer <pending>, DNS via VIP, core pods Running
```

## Rollback

```bash
# on a worker:        /usr/local/bin/k3s-agent-uninstall.sh
# on the control node:/usr/local/bin/k3s-uninstall.sh   (destroys etcd — restore from snapshot)
```

## Notes / Gotchas

- `traefik` and `servicelb` are disabled on purpose — ingress + L2 LB (MetalLB) are deliberate.
- Upgrades: bump `INSTALL_K3S_VERSION`, **server first**, then workers one at a time (rb 07).
