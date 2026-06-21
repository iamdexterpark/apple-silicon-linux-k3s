# Profile: x86 PXE (commodity unattended provisioning) — extension stub

This is the **extension pattern**, not a completed profile. The repo's primary profile is
[`profile-bare-metal-asahi`](../profile-bare-metal-asahi). If you decide to run the same cluster on
commodity x86_64 hardware — where the boot wall doesn't exist — implement this profile rather than
mutating the primary one.

The interesting thing about this target: **most of the primary profile's hard constraints dissolve.**
PXE/netboot and IPMI exist, so provisioning is unattended; pages are 4 KB, so the page-size admission
criterion is moot; recovery is a remote re-image, not a physical swap. That's exactly why a switch to
this profile is *material* and earns its own ADR — it reopens [ADR-0007](../../adr/0007-manual-provisioning-accepted.md)
(manual provisioning) and [ADR-0006b](../../adr/0006b-face-16k-page-size.md) (16K pages).

## What a new profile must specify

Per [LLD §Environment Profiles](../../LLD.md#11-environment-profiles):

| Axis | bare-metal-asahi (primary) | x86-pxe (this stub) |
|---|---|---|
| **Substrate** | M1 Mac mini, Fedora Asahi Remix, `kernel-16k` | commodity x86_64, any server distro, 4 KB pages |
| **Provisioning** | manual 1TR boot-policy gate, then scripted | **fully unattended** (DHCP → PXE → kickstart/autoinstall) |
| **Out-of-band** | external IP-KVM + switched PDU | native BMC/IPMI/Redfish |
| **Page size** | 16 KB (workload admission criterion) | 4 KB (no constraint) |
| **Recovery** | cold-spare swap (no remote re-image) | **remote re-image** from the provisioning server |
| **Host config** | identical `node_base` converge | identical `node_base` converge (NIC name differs) |
| **K3s bring-up** | identical scripts | identical scripts |

## Runbooks to author for this profile

Reuse `_common/` unchanged (05-host-converge, 07-rolling-upgrade, 09-decommission — drop the
boot-policy-reset step) and the whole `provisioning/` deliverable (the Chef cookbook + K3s scripts are
substrate-independent). Replace the staging chain:

- `01-rack-and-cable` — same, but OOB is the BMC, not an external KVM/PDU.
- `02-pxe-server` — stand up DHCP/TFTP/HTTP + the autoinstall/kickstart profile.
- `03-unattended-install` — netboot the node; it installs and reboots with **no human at the keyboard**.
- `04-node-bootstrap` — same, minus the 16K-kernel assertion.
- `06-k3s-bringup` — identical scripts; only `--node-ip` values change.
- `08-remote-reimage` — recovery by re-PXE, **replacing** the cold-spare-swap runbook.

> A switch to this profile changes the security/recovery posture materially — write the ADR that
> supersedes the manual-provisioning and 16K-page decisions before adopting it. Don't bury a target
> switch in a runbook.
