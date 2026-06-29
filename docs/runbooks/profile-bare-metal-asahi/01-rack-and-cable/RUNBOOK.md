# Runbook 01 — Rack & Cable

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `profile-bare-metal-asahi` (primary) |
> | **Substrate** | Apple Silicon Mac mini, on a shelf/rack at the edge |
> | **Cloud services used** | none |
> | **Identity model** | n/a (physical) |
> | **What changes under a different profile** | on `profile-x86-pxe` the OOB path is native BMC/IPMI, not an external KVM/PDU |

**Goal:** every node physically installed, on the NODES segment, with remote power + console.
**Time:** ~20 min/node · **Risk:** low · **Reversible:** yes (unplug)

## Prerequisites

- Mac mini(s) + the cold spare, a Gigabit switch, shielded Cat6, a wired USB-A keyboard, an HDMI cable.
- An external IP-KVM (PiKVM) and a switched PDU for out-of-band console + power (the no-IPMI wall).

## Steps

### 1. Rack and power
- Seat each node; connect to the **switched PDU** (so you can hard power-cycle remotely).

### 2. Network
- One shielded Cat6 per node to an access port on the **NODES** VLAN (`10.0.32.0/27`).
- Keep the trunk config for SERVICES/TELEMETRY sub-interfaces ready (applied at converge time).

### 3. Out-of-band console
- Connect each node's **HDMI + wired USB-A keyboard** through the IP-KVM. Bluetooth keyboards do
  **not** work in the 1TR recovery screen — wired is mandatory.

## Verification

```bash
# from the switch / operator: each node port shows link up on the NODES VLAN
# from the IP-KVM: each node's console is reachable and the PDU can cycle its outlet
```

## Rollback

Power down via the PDU and unplug. No state has been written to any node yet.

## Notes / Gotchas

- Label PDU outlets to node positions now — you'll thank yourself during a 2 a.m. swap.
- Verify the KVM does EDID injection; some Mac minis blank the display on a cold KVM handshake.
