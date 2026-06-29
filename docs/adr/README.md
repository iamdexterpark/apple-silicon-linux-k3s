# Architecture Decision Records

These ADRs capture the **load-bearing decisions** behind this repo. The point of an ADR is
not to document the chosen answer — the deliverable already does that — but to record the
**alternatives that were genuinely on the table** and *why they lost*, so the design can be
audited and revisited as conditions change.

Format: lightly-adapted [MADR](https://adr.github.io/madr/). Each record is self-contained:
context → decision drivers → options considered → decision → consequences → revisit-if.
Start from [`0000-template.md`](0000-template.md).

| ADR | Status | Decision | Rejected alternatives |
|---|---|---|---|
| [0001](0001-bare-metal-linux-over-macos-vm.md) | Accepted | Bare-metal Linux on the metal over a VM-on-macOS cluster | Linux VM on macOS (memory + hypervisor tax) |
| [0002](0002-secondhand-multi-node-over-single-new.md) | Accepted | Three secondhand nodes + cold spare over one new machine | single new M4/x86 box (no fault tolerance) |
| [0003](0003-k3s-over-full-kubernetes.md) | Accepted | K3s over full upstream Kubernetes | kubeadm full control plane (footprint) |
| [0004](0004-single-control-plane-etcd.md) | Accepted | Single control plane over a 3-node etcd HA quorum | 3-node embedded-etcd HA (resource + complexity tax) |
| [0005](0005-fedora-asahi-remix-distro.md) | Accepted | Fedora Asahi Remix (Server) as the host distro | generic aarch64 distro (won't boot); Asahi Arch (fleet fit) |
| [0006](0006-chef-cinc-solo-host-config.md) | Accepted | Chef/Cinc local-mode for idempotent host config | bespoke shell; Chef/Puppet server; Ansible (narrowly) |
| [0006b](0006b-face-16k-page-size.md) | Accepted | Face the 16K page size as a workload admission criterion | 4K guest kernel in a VM; reactive break-fix |
| [0007](0007-manual-provisioning-accepted.md) | Accepted | Accept the manual boot gate; engineer around it | scripting 1TR (impossible); stay on macOS |
| [0008](0008-mutable-host-over-immutable-ab.md) | Accepted | Minimal mutable kernel-pinned host over immutable A/B | immutable A/B OS (mechanics unavailable on Apple Silicon) |

> All identifiers, providers, and hostnames referenced in these records are placeholders,
> consistent with the rest of this sanitized repo.
