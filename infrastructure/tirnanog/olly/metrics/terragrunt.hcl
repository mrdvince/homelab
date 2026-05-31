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
  create_metrics = true

  host                 = "192.168.50.235"
  ssh_user             = "root"
  ssh_private_key_path = "${get_env("HOME")}/.ssh/avalon"

  instance = "tirnanog"
  platform = "proxmox"

  prometheus_remote_write_url = "https://prometheus.home.mrdvince.me/api/v1/write"
  prometheus_username         = "alloy"
  prometheus_password         = dependency.outposts.outputs.service_account_tokens["alloy"]
}
