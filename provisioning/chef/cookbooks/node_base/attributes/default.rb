# attributes/default.rb — safe defaults. Per-node values come from nodes/<hostname>.json,
# which override these. NEVER put secrets here; the K3s join token is injected at runtime
# via the environment (see scripts/cluster/40-install-k3s-agent.sh), never converged.

# --- identity ---
default["node_base"]["hostname"]     = nil   # REQUIRED in node JSON, e.g. "node-1"

# --- NODES network (the single trunked segment carrying API/etcd/kubelet/pod traffic) ---
default["node_base"]["net"]["iface"]   = "end0"          # Asahi onboard NIC; verify with `nmcli device status`
default["node_base"]["net"]["address"] = nil             # REQUIRED, e.g. "10.0.32.2/27" (RFC-style placeholder)
default["node_base"]["net"]["gateway"] = "10.0.32.1"     # NODES router SVI (placeholder)
default["node_base"]["net"]["dns"]     = ["1.1.1.1", "9.9.9.9"]

# --- firewalld: default-deny inbound, allow only what the cluster needs on the NODES zone ---
# Ports kept agnostic in the HLD; concrete K3s ports live here (LLD-grade).
default["node_base"]["firewall"]["allow_ports"] = [
  "22/tcp",     # SSH (key-only)
  "6443/tcp",   # K3s API server
  "2379/tcp",   # etcd client
  "2380/tcp",   # etcd peer
  "10250/tcp",  # kubelet
  "8472/udp",   # Flannel VXLAN
  "51820/udp",  # Flannel WireGuard (if enabled)
]

# CNI trust (POST-DECAP): opening 8472/udp is necessary but NOT sufficient. Flannel decapsulates
# and forwards inner pod traffic on these interfaces; if they're in "no zone" they hit the default
# DROP zone and ALL cross-node pod/ClusterIP traffic is dropped (nodes still show Ready, masking it).
# Put the CNI interfaces + pod/service CIDRs in firewalld's built-in `trusted` zone.
default["node_base"]["firewall"]["trusted_interfaces"] = %w(cni0 flannel.1)
default["node_base"]["firewall"]["trusted_sources"]    = ["10.42.0.0/16", "10.43.0.0/16"]  # K3s default pod / service CIDRs

# --- SSH lockout guard: keep passwords ON until an operator key is proven installed ---
# Set authorized_keys in nodes/<host>.json (placeholder pubkeys). disable_password only takes
# effect when at least one key is present, so a fresh password-only node can't be locked out.
default["node_base"]["ssh"]["authorized_keys"] = []
default["node_base"]["ssh"]["disable_password"] = true

# --- kernel pin: exclude generic aarch64 kernels so an upgrade can't replace the only one that boots ---
default["node_base"]["kernel"]["excludes"] = %w(kernel kernel-core kernel-modules)

# --- time ---
default["node_base"]["chrony"]["pools"] = ["pool.ntp.org"]
