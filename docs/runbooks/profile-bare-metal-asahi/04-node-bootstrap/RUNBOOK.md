# Runbook 04 — Node Bootstrap (first Linux boot)

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | freshly-installed Fedora Asahi Remix on the metal |
> | **Cloud services used** | none |
> | **Identity model** | local Linux sudo |
> | **What changes under a different profile** | the NIC name and the absence of the 16K-kernel check differ on `profile-x86-pxe` |

**Goal:** a thin, sane baseline on the fresh node — 16K kernel verified, NIC up, kernel pinned, time
synced — ready for the idempotent converge (rb 05).
**Time:** ~5 min · **Risk:** low · **Reversible:** yes (re-run; idempotent)

## Prerequisites

- Runbook 03 done; Linux booting; internet reachable.

## Steps

### 1. Run the bootstrap (on the Linux console, with sudo)
```bash
sudo bash provisioning/scripts/staging/bootstrap.sh
```
It verifies the Asahi 16K kernel, detects the Ethernet interface, installs base packages, disables
Wi-Fi and masks `wpa_supplicant`, **adds the kernel pin** to `/etc/dnf/dnf.conf`, and enables chrony.

## Verification

```bash
bash provisioning/scripts/operations/checkout.sh   # RESULT: READY (arch, kernel, 16K, net, wifi off, time, pkgs)
grep '^exclude=kernel' /etc/dnf/dnf.conf           # kernel pin present
```

## Rollback

The script is idempotent and additive; to revert the Wi-Fi mask: `sudo systemctl unmask
wpa_supplicant`. Nothing here is destructive.

## Notes / Gotchas

- The **kernel pin is the single most important line** — without it a routine `dnf upgrade` can
  install a generic aarch64 kernel and brick boot ([COST-MODEL §3](../../../COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying)).
