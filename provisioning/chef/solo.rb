# solo.rb — Cinc/Chef local-mode (chef-solo) configuration.
# Drives an idempotent host converge with NO Chef server: the node JSON under nodes/
# selects the run-list and attributes; the cookbook under cookbooks/ does the work.
#
# Invoked by ../scripts/cluster/20-converge.sh as:
#   cinc-client --local-mode --config solo.rb --json-attributes nodes/<hostname>.json
here              = File.dirname(__FILE__)
cookbook_path     ["#{here}/cookbooks"]
node_path         "#{here}/nodes"
file_cache_path   "/var/cache/cinc"
log_level         :info
chef_license      "accept-silent"
