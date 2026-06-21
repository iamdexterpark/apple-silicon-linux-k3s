# Provisioning deliverable — bare-metal bring-up

The real artifact of this repo. Not container manifests, not HCL — **the scripts and the Chef/Cinc
cookbook that take an Apple Silicon Mac mini from a stock macOS install to a Ready K3s node.** The
boundary is deliberate (see [ADR-0007](../docs/adr/0007-manual-provisioning-accepted.md)): the one
phase Apple's boot security forces to be manual is a tight, gated runbook; **everything above the
first Linux boot is code** — idempotent host config and a pinned, scripted K3s bring-up.

```
provisioning/
├── scripts/
│   ├── staging/        # bare-metal, manual-adjacent: precheck → install-asahi → bootstrap
│   │   ├── precheck.sh        # run in macOS: arm64? FileVault off? ≥80 GB free? installer reachable?
│   │   ├── install-asahi.sh   # guided wrapper around the official Asahi installer
│   │   └── bootstrap.sh       # first Linux boot: verify 16K kernel, NIC, kernel pin, time
│   ├── cluster/        # idempotent → the cluster substrate
│   │   ├── 00-precheck.sh             # host-config + cluster-health gate
│   │   ├── 10-bootstrap-chef.sh       # install cinc-client (open-source Chef)
│   │   ├── 20-converge.sh             # local-mode converge THIS node (picks node JSON by hostname)
│   │   ├── 30-install-k3s-server.sh   # control-plane on node-1 (--cluster-init, embedded etcd)
│   │   ├── 40-install-k3s-agent.sh    # join a worker; token from the environment, never hardcoded
│   │   └── 99-cluster-checkout.sh     # post-bring-up acceptance (run from the operator machine)
│   └── operations/     # day-2
│       └── checkout.sh        # node acceptance check (arch, kernel, page size, net, time)
│
└── chef/               # host-config primitive: declared once, no snowflakes
    ├── solo.rb                # Cinc/Chef local-mode config (no Chef server)
    ├── cookbooks/node_base/   # hostname · static NM connection · default-deny firewalld ·
    │                          #   key-only SSH · 16K-kernel pin · time sync
    └── nodes/                 # per-node attributes (node-1/2/3) — selects run-list + address
```

## How it runs

1. **Staging (manual, per node):** `scripts/staging/precheck.sh` → `install-asahi.sh` → the 1TR
   signing dance → `bootstrap.sh` on first Linux boot.
2. **Host converge (idempotent, per node):** `scripts/cluster/10-bootstrap-chef.sh` then
   `20-converge.sh`. The cookbook is desired-state, so re-running corrects drift and changes nothing
   already correct.
3. **K3s bring-up:** `30-install-k3s-server.sh` on `node-1`; `40-install-k3s-agent.sh` on the
   workers (export `K3S_TOKEN`, `NODE_IP`, `NODE_NAME`). `99-cluster-checkout.sh` gates acceptance.

## Conventions

- **Secrets are never converged.** The K3s join token is read from the environment at agent-join
  time and sealed into a password manager — it never lands in a node JSON, a recipe, or git
  ([ADR-0006](../docs/adr/0006-chef-cinc-solo-host-config.md)).
- **Addresses are placeholders.** `10.0.32.0/27` (NODES), `node-1/2/3` — adapt before running.
- **Idempotent by construction.** Every cookbook resource is a declaration with a guard; every
  cluster script is safe to re-run.

Validate locally with [`../scripts/validate.sh`](../scripts/README.md) (the `provisioning` gate runs
`bash -n` + `shellcheck` on the scripts and `ruby -c` + `cookstyle` on the cookbook).
