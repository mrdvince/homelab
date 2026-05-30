include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../../homelab-modules/olly"
}

dependency "outposts" {
  config_path = "../../../avalon/clusters/aion/outposts"

  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    service_account_tokens = {
      alloy = "mock"
    }
  }
}

inputs = {
  create_logs = true

  host                 = "192.168.50.250"
  ssh_user             = "root"
  ssh_private_key_path = "${get_env("HOME")}/.ssh/elysium"

  instance = "elysium"
  platform = "proxmox"

  loki_url      = "https://loki.home.mrdvince.me/loki/api/v1/push"
  loki_username = "alloy"
  loki_password = dependency.outposts.outputs.service_account_tokens["alloy"]
}
