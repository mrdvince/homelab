locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"
  alloy_username  = "alloy"
}

terraform {
  source = "${local.base_source_url}//olly?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/olly"
}

dependency "outposts" {
  config_path = "${dirname(find_in_parent_folders("root.hcl"))}/avalon/clusters/aion/outposts"

  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    service_account_tokens = {
      alloy = "mock"
    }
  }
}

inputs = {
  platform = "proxmox"

  loki_url      = "https://loki.home.mrdvince.me/loki/api/v1/push"
  loki_username = local.alloy_username
  loki_password = dependency.outposts.outputs.service_account_tokens["alloy"]

  prometheus_remote_write_url = "https://prometheus.home.mrdvince.me/api/v1/write"
  prometheus_username         = local.alloy_username
  prometheus_password         = dependency.outposts.outputs.service_account_tokens["alloy"]

  snmp_username = local.alloy_username
}
