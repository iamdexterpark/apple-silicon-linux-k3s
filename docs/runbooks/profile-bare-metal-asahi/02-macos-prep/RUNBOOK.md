# Runbook 02 — macOS Prep

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | stock macOS on the target Mac mini |
> | **Cloud services used** | none |
> | **Identity model** | local macOS admin (for the upcoming 1TR signing) |
> | **What changes under a different profile** | `profile-x86-pxe` has no macOS phase at all |

**Goal:** the Mac is verified ready for the Asahi installer.
**Time:** ~10 min + FileVault decryption wait · **Risk:** low · **Reversible:** yes

## Prerequisites

- Admin access to macOS; ≥ 80 GB free; wired Ethernet up.

## Steps

### 1. Disable FileVault and wait for full decryption
```bash
sudo fdesetup disable          # then wait — the Asahi installer needs an unencrypted container
fdesetup status                # must read: FileVault is Off
```

### 2. Run the precheck
```bash
bash provisioning/scripts/staging/precheck.sh
```
It gates: arm64, Mac mini model, FileVault off, ≥ 80 GB free, installer URL reachable, wired link up.

## Verification

```bash
provisioning/scripts/staging/precheck.sh    # RESULT: READY — proceed to install-asahi.sh
```

## Rollback

Nothing destructive yet — re-enable FileVault (`sudo fdesetup enable`) to revert.

## Notes / Gotchas

- Keep **~80 GB for macOS** — it holds the `LocalPolicy` boot keys and the 1TR recovery you'll need
  for every future boot-policy action. Deleting it strands the node ([LLD §2](../../../LLD.md#2-disk-partitioning-apfs-containers)).
