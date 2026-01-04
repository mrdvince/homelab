locals {
  environment_vars   = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  base_source_url    = "git@github.com:mrdvince/homelab-modules.git"
  base_source_branch = "main"
}

terraform {
  source = "${local.base_source_url}//vm?ref=${local.base_source_branch}"
  # source = "../../../../../homelab-modules/vm"
}

inputs = {
  node_name = "avalon"

  network = {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
    vlan_id  = 30
  }

  efi_disk = {
    storage           = "nvme-data"
    type              = "4m"
    pre_enrolled_keys = false
  }

  cpu_type = "x86-64-v2-AES"
}
