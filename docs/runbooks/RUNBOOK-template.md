# Runbook {{NN}} — {{Title}}

> **Target Environment** (mandatory — a runbook that doesn't declare its env is a trap)
> | | |
> |---|---|
> | **Deployment profile** | {{`_common` (profile-independent) \| `profile-bare-metal-asahi` \| `profile-x86-pxe`}} |
> | **Substrate** | {{e.g. Apple Silicon Mac mini + Fedora Asahi Remix \| commodity x86_64}} |
> | **Cloud services used** | {{e.g. object store (etcd snapshots) \| none}} |
> | **Identity model** | {{e.g. local sudo \| K3s join token (runtime) \| macOS admin (1TR)}} |
> | **What changes under a different profile** | {{the 1–2 steps that differ, + pointer to that profile's runbook}} |

**Goal:** one sentence — what state this runbook leaves you in.
**Time:** ~{{N}} min · **Risk:** low/med/high · **Reversible:** yes/no (see Rollback)

## Prerequisites

- …

## Steps

### 1. {{step}}
```bash
# copy-pasteable, sanitized; placeholders explicit (REPLACE_*)
```

## Verification

How you *know* it worked — the explicit check, expected output, success criterion.

```bash
```

## Rollback

How to undo, cleanly.

```bash
```

## Notes / Gotchas

- …
