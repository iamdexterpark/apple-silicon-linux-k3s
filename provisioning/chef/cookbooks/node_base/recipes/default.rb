# recipes/default.rb — converge a node to the cluster baseline. Idempotent by construction:
# every resource is a desired-state declaration, so re-running corrects drift and changes nothing
# that already matches. This is the host-config primitive — mutable host, declared once, no snowflakes.

n = node["node_base"]

raise "node_base.hostname is required (set it in nodes/<host>.json)" if n["hostname"].nil?
raise "node_base.net.address is required (set it in nodes/<host>.json)" if n["net"]["address"].nil?

# 1. Hostname ------------------------------------------------------------------------------
hostname n["hostname"]

# 2. NODES static connection (NetworkManager) ----------------------------------------------
# A single primary connection per node. We drive nmcli idempotently rather than templating
# keyfiles, so the running connection and the declared one never diverge.
iface   = n["net"]["iface"]
address = n["net"]["address"]
gateway = n["net"]["gateway"]
dns     = Array(n["net"]["dns"]).join(" ")

execute "nm-static-#{iface}" do
  command <<~CMD
    nmcli connection modify "Wired connection 1" \
      ipv4.method manual \
      ipv4.addresses #{address} \
      ipv4.gateway #{gateway} \
      ipv4.dns "#{dns}" \
      ipv6.method disabled \
      connection.autoconnect yes && \
    nmcli connection up "Wired connection 1"
  CMD
  # only re-apply if the declared address is not already the active one
  not_if "nmcli -t -f IP4.ADDRESS device show #{iface} | grep -q '#{address.split('/').first}'"
end

# Headless node: no wireless. Turn the radio off and mask the supplicant so a NM restart
# can't bring Wi-Fi back up.
execute "wifi-off" do
  command "nmcli radio wifi off"
  only_if "nmcli radio wifi | grep -qi enabled"
end

service "wpa_supplicant" do
  action [:disable, :stop]
end

# 3. Default-deny firewalld --------------------------------------------------------------
# dnf_package (NOT bare `package`): Fedora 40+/Asahi is dnf5 with no yum-compat libraries,
# and a bare `package` resolves to yum_package on platform=fedora -> "cannot find yum libraries".
dnf_package "firewalld"

service "firewalld" do
  action [:enable, :start]
end

# LESSON (live bring-up): never hardcode `--zone=public`. Fedora SERVER's default zone is
# `FedoraServer` and the primary NIC lives there; ports opened in `public` land in a zone with
# no interface, so k3s 6443 stays DROPped, agents never join, and the cluster SILENTLY never
# forms while the firewall *looks* configured. Resolve the live default zone at converge time.
ruby_block "resolve-default-zone" do
  block do
    zone = shell_out!("firewall-cmd --get-default-zone").stdout.strip
    node.run_state["fw_zone"] = zone
  end
end

# Drop target = default-deny inbound on the ACTIVE default zone; we then open only cluster ports.
execute "firewalld-default-deny" do
  command lazy { "firewall-cmd --permanent --set-target=DROP --zone=#{node.run_state['fw_zone']}" }
  # Guard takes a plain block (not lazy{string} — Chef rejects that); run the check at converge.
  not_if  { shell_out("firewall-cmd --permanent --zone=#{node.run_state['fw_zone']} --get-target").stdout.strip == "DROP" }
  notifies :run, "execute[firewalld-reload]", :delayed
end

n["firewall"]["allow_ports"].each do |port|
  execute "firewalld-allow-#{port}" do
    command lazy { "firewall-cmd --permanent --zone=#{node.run_state['fw_zone']} --add-port=#{port}" }
    not_if  { shell_out("firewall-cmd --permanent --zone=#{node.run_state['fw_zone']} --query-port=#{port}").exitstatus.zero? }
    notifies :run, "execute[firewalld-reload]", :delayed
  end
end

# POST-DECAP companion (this is the half that opening 8472/udp does NOT cover):
# k3s/flannel decapsulates VXLAN and forwards inner pod traffic on cni0/flannel.1. If those
# interfaces sit in "no zone" they fall through to the default DROP zone, so ALL cross-node
# pod-to-pod + ClusterIP traffic is dropped — while nodes still show Ready (kubelet->api rides
# the underlay), masking it. Trust the CNI interfaces + the pod/service CIDRs explicitly.
n["firewall"]["trusted_interfaces"].each do |ifc|
  execute "firewalld-trust-iface-#{ifc}" do
    command "firewall-cmd --permanent --zone=trusted --add-interface=#{ifc}"
    not_if  "firewall-cmd --permanent --zone=trusted --query-interface=#{ifc}"
    notifies :run, "execute[firewalld-reload]", :delayed
  end
end

n["firewall"]["trusted_sources"].each do |cidr|
  execute "firewalld-trust-source-#{cidr.tr('/.', '__')}" do
    command "firewall-cmd --permanent --zone=trusted --add-source=#{cidr}"
    not_if  "firewall-cmd --permanent --zone=trusted --query-source=#{cidr}"
    notifies :run, "execute[firewalld-reload]", :delayed
  end
end

execute "firewalld-reload" do
  command "firewall-cmd --reload"
  action :nothing
end

# 4. Key-only SSH ------------------------------------------------------------------------
# Lockout guard: only disable password auth once a key is proven present. On a fresh node the
# real first contact is password-only; harden before installing a key and you lock yourself out.
dnf_package "openssh-server"

# Install operator authorized_keys BEFORE disabling passwords (set node_base.ssh.authorized_keys).
ops_keys = Array(n["ssh"]["authorized_keys"]).reject { |k| k.to_s.strip.empty? }
unless ops_keys.empty?
  directory "/root/.ssh" do
    mode "0700"
    owner "root"
    group "root"
  end
  file "/root/.ssh/authorized_keys" do
    content "#{ops_keys.join("\n")}\n"
    mode "0600"
    owner "root"
    group "root"
  end
end
disable_pw = n["ssh"]["disable_password"] && !ops_keys.empty?

file "/etc/ssh/sshd_config.d/10-hardening.conf" do
  # PasswordAuthentication flips to `no` ONLY when an operator key is installed (lockout guard).
  content <<~SSHD
    # Managed by node_base — key-only once a key is present, no root password login.
    PasswordAuthentication #{disable_pw ? "no" : "yes"}
    PermitRootLogin prohibit-password
    KbdInteractiveAuthentication no
  SSHD
  mode "0644"
  notifies :restart, "service[sshd]", :delayed
end

service "sshd" do
  action [:enable, :start]
end

# 5. Kernel pin — never let an upgrade install a generic, unbootable aarch64 kernel ------
excludes = n["kernel"]["excludes"].join(" ")
ruby_block "pin-asahi-kernel" do
  block do
    require "fileutils"
    conf  = "/etc/dnf/dnf.conf"
    lines = ::File.exist?(conf) ? ::File.readlines(conf) : ["[main]\n"]
    lines.reject! { |l| l =~ /^\s*exclude=/ }
    lines << "exclude=#{excludes}\n"
    ::File.write(conf, lines.join)
  end
  not_if { ::File.exist?("/etc/dnf/dnf.conf") && ::File.read("/etc/dnf/dnf.conf") =~ /^exclude=#{Regexp.escape(excludes)}\s*$/ }
end

# 6. Time sync ---------------------------------------------------------------------------
dnf_package "chrony"

template "/etc/chrony.conf" do
  source "chrony.conf.erb"
  variables(pools: n["chrony"]["pools"])
  mode "0644"
  notifies :restart, "service[chronyd]", :delayed
end

service "chronyd" do
  action [:enable, :start]
end
