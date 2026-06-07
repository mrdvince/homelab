include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/olly.hcl"
}

inputs = {
  create_metrics           = true
  create_pve_exporter      = true
  create_opnsense_exporter = true

  ssh_host_alias = "elysium-yk"

  instance = "elysium"

  pve_exporter_token_id     = include.root.locals.secret_vars.pve.pve_exporter_token_id
  pve_exporter_token_secret = include.root.locals.secret_vars.pve.pve_exporter_token_secret
  pve_exporter_target       = "elysium.home.mrdvince.me"
  pve_exporter_image        = "registry.home.mrdvince.me/prompve/prometheus-pve-exporter:3.9.0"

  opnsense_address    = "vale.home.mrdvince.me"
  opnsense_api_key    = include.root.locals.secret_vars.opnsense.exporter_api_key
  opnsense_api_secret = include.root.locals.secret_vars.opnsense.exporter_api_secret
}
