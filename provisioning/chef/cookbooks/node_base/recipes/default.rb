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
package "firewalld"

service "firewalld" do
  action [:enable, :start]
end

# Drop target = default-deny inbound on the default zone; we then open only cluster ports.
execute "firewalld-default-deny" do
  command "firewall-cmd --permanent --set-target=DROP --zone=public"
  not_if  "firewall-cmd --permanent --zone=public --get-target | grep -qx DROP"
  notifies :run, "execute[firewalld-reload]", :delayed
end

n["firewall"]["allow_ports"].each do |port|
  execute "firewalld-allow-#{port}" do
    command "firewall-cmd --permanent --zone=public --add-port=#{port}"
    not_if  "firewall-cmd --permanent --zone=public --query-port=#{port}"
    notifies :run, "execute[firewalld-reload]", :delayed
  end
end

execute "firewalld-reload" do
  command "firewall-cmd --reload"
  action :nothing
end

# 4. Key-only SSH ------------------------------------------------------------------------
package "openssh-server"

file "/etc/ssh/sshd_config.d/10-hardening.conf" do
  content <<~SSHD
    # Managed by node_base — key-only, no root password login.
    PasswordAuthentication no
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
package "chrony"

template "/etc/chrony.conf" do
  source "chrony.conf.erb"
  variables(pools: n["chrony"]["pools"])
  mode "0644"
  notifies :restart, "service[chronyd]", :delayed
end

service "chronyd" do
  action [:enable, :start]
end
