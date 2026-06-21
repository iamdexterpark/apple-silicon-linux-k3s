# Runbooks

The operational path across the full lifecycle. **Every runbook declares its Target Environment** in
a header block — because the procedure changes with the deployment target.

## The deployment-profile model

This repo is written against a **primary deployment profile** concretely, with room to add another
target without rewriting the core. Runbooks are split so each profile is independently followable:

```
runbooks/
├── _common/                       # profile-INDEPENDENT lifecycle ROLES (same on any substrate)
│   ├── 05-host-converge           #   idempotent Chef/Cinc converge of a node
│   ├── 07-rolling-upgrade         #   drain → upgrade → reboot → uncordon, one node at a time
│   └── 09-decommission            #   drain, wipe, reset boot policy, no orphans
├── profile-bare-metal-asahi/      # PRIMARY: Apple Silicon Mac minis, Fedora Asahi Remix
│   ├── 01-rack-and-cable
│   ├── 02-macos-prep
│   ├── 03-asahi-install           #   the 1TR signing dance
│   ├── 04-node-bootstrap
│   ├── 06-k3s-bringup
│   └── 08-cold-spare-and-break-fix
└── profile-x86-pxe/               # EXTENSION stub: commodity x86, unattended PXE (the wall is gone)
    └── README.md
```

- **`_common/`** holds lifecycle **roles** that are identical regardless of substrate — the host
  converge, the rolling upgrade, the clean decommission. They are *roles*, not artifacts; don't
  duplicate them into a profile.
- **`profile-*`** holds the substrate-specific path: how a node is staged, how the OS is installed,
  how the cluster is brought up, and how a node is recovered. The numbered sequence interleaves
  `_common` and profile steps — follow them in numeric order across both folders.
- **Adding a target** (e.g. moving the same cluster onto commodity x86 where PXE works): copy
  [`profile-x86-pxe/`](profile-x86-pxe/README.md) as a starting point and reuse `_common/` and the
  whole `provisioning/` deliverable unchanged. The [ADRs](../adr/README.md) and
  [LLD Environment Profiles](../LLD.md#11-environment-profiles) define what a new profile must specify.

> Everything is sanitized: `node-1/2/3`, `10.0.32.0/27` (NODES), `REPLACE_*`. Adapt before running.

## Order of operations (primary profile: bare-metal-asahi)

| # | Runbook | Folder | What it does |
|---|---|---|---|
| 01 | rack-and-cable | `profile-bare-metal-asahi` | Physical: rack, Ethernet, OOB KVM + PDU. |
| 02 | macos-prep | `profile-bare-metal-asahi` | In macOS: FileVault off, free space, precheck. |
| 03 | asahi-install | `profile-bare-metal-asahi` | Asahi installer + the 1TR boot-policy signing dance. |
| 04 | node-bootstrap | `profile-bare-metal-asahi` | First Linux boot: verify 16K kernel, NIC, kernel pin, time. |
| 05 | host-converge | `_common` | Idempotent Cinc converge: net · firewall · ssh · kernel pin. |
| 06 | k3s-bringup | `profile-bare-metal-asahi` | Server on node-1; agents join; acceptance checkout. |
| 07 | rolling-upgrade | `_common` | Drain → `dnf upgrade` → reboot → uncordon, one node at a time. |
| 08 | cold-spare-and-break-fix | `profile-bare-metal-asahi` | Swap a dead node with the staged spare; etcd restore. |
| 09 | decommission | `_common` | Drain, wipe partitions, reset Secure Enclave boot policy — no orphans. |

## Operating principles

- **Manual only where the hardware forces it.** The 1TR gate (rb 03) is the sole manual step; past
  first boot everything is a script or a converge ([ADR-0007](../adr/0007-manual-provisioning-accepted.md)).
- **Idempotent host config.** The converge (rb 05) is safe to re-run; it corrects drift, no snowflakes.
- **Verify the kernel pin before any upgrade.** A generic kernel bricks the node (rb 07).
- **Recovery is a swap, not a re-image.** A wipe destroys the boot authorization — that's why we hold
  a cold spare (rb 08, [ADR-0002](../adr/0002-secondhand-multi-node-over-single-new.md)).
- **A snapshot nobody has restored is not a backup.** The etcd restore drill is part of rb 08.
- **Decommission leaves nothing behind** — partitions wiped, boot policy reset, off-node backups
  deleted (rb 09).
