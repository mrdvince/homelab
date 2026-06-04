include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/olly.hcl"
}

inputs = {
  create_metrics      = true
  create_pve_exporter = true

  ssh_host_alias = "elysium-yk"

  instance = "elysium"

  pve_exporter_token_id     = include.root.locals.secret_vars.pve.pve_exporter_token_id
  pve_exporter_token_secret = include.root.locals.secret_vars.pve.pve_exporter_token_secret
  pve_exporter_target       = "elysium.home.mrdvince.me"
  pve_exporter_image        = "registry.home.mrdvince.me/prompve/prometheus-pve-exporter:3.9.0"
}
