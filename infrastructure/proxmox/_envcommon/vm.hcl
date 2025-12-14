locals {
  environment_vars   = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  base_source_url    = "git@github.com:mrdvince/hllab-modules.git"
  base_source_branch = "main"
}

terraform {
  source = "${local.base_source_url}//qemu?ref=${local.base_source_branch}"
}

inputs = {
  os_type     = "cloud_init"
  target_node = "avalon"
  network = {
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    model     = "virtio"
    tag       = 30
  }
  serial = {
    id   = 0
    type = "socket"
  }
  efidisk = {
    efitype = "4m"
    storage = "nvme-data"
  }
  vm_base_config_map = {
    cpu       = "x86-64-v3"
    skip_ipv6 = true
  }
  # sshkeys = file("~/.ssh/devkey.pub")
}
