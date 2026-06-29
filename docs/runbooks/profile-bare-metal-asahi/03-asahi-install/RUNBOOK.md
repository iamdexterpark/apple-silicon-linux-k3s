# Runbook 03 — Asahi Install (the 1TR signing dance)

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | Apple Silicon Mac mini crossing the boot wall |
> | **Cloud services used** | none (installer fetched from the Asahi project) |
> | **Identity model** | macOS admin password (authorizes the boot policy in 1TR) |
> | **What changes under a different profile** | `profile-x86-pxe` replaces this entire manual gate with unattended PXE/netboot |

**Goal:** Fedora Asahi Remix installed; the Linux container's boot policy signed; Linux boots.
**Time:** ~30–45 min (the manual gate) · **Risk:** medium · **Reversible:** yes (delete the Linux partition in 1TR)

> **This is the one manual, hardware-mandated step.** No script can perform the power-button hold or
> the local boot-policy signing — that's the keystone constraint ([ADR-0007](../../../adr/0007-manual-provisioning-accepted.md)).

## Prerequisites

- Runbook 02 passed. Wired USB-A keyboard attached. Console on the IP-KVM.

## Steps

### 1. Launch the guided installer (in macOS)
```bash
sudo bash provisioning/scripts/staging/install-asahi.sh
```
Answer at the keyboard: **Fedora Asahi Remix → Server (headless)**; Linux partition = disk minus
~80 GB; confirm repartition. (The wrapper fetches the current installer from the Asahi homepage
rather than hardcoding a URL.)

### 2. The 1TR boot-policy dance (physical)
- Power off. **Hold the power button** until "Loading startup options" → enter **One True Recovery**.
- Choose the Linux/Asahi volume; when prompted, authorize **Permissive Security** for that container
  by entering the **macOS admin password**. (This signs the `LocalPolicy` with the Secure Enclave's
  Owner Identity Key — local, owner-only, physical.)

### 3. First Linux boot
- Let it boot through `m1n1 → U-Boot → GRUB → kernel-16k`. Complete the Fedora first-boot wizard
  (create the admin user).

## Verification

```bash
uname -m                 # aarch64
uname -r                 # ...asahi... (the 16K kernel)
getconf PAGE_SIZE        # 16384
```

## Rollback

Boot to 1TR → macOS Recovery → delete the Linux APFS volume and reclaim space → reset the Linux
container's boot policy with `bputil`. macOS is untouched.

## Notes / Gotchas

- macOS container stays at **Full Security**; only the Linux container is Permissive. They're
  independent ([LLD §3](../../../LLD.md#3-the-boot-sequence-components)).
- Black screen via KVM = HPD/EDID handshake; attach HDMI directly or enable EDID injection.
