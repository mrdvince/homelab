locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  node_vars        = read_terragrunt_config(find_in_parent_folders("node.hcl"))
  base_source_url  = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref  = "main"

  use_sops            = get_env("HOMELAB_SECRET_SOURCE", "infisical") == "sops"
  secret_vars         = local.use_sops ? yamldecode(sops_decrypt_file("${dirname(find_in_parent_folders("root.hcl"))}/../secrets/secrets.enc.yaml")) : null
  pm_api_token_id     = local.use_sops ? local.secret_vars.pm_api_token_id : get_env("PM_API_TOKEN_ID")
  pm_api_token_secret = local.use_sops ? local.secret_vars.pm_api_token_secret : get_env("PM_API_TOKEN_SECRET")
}

terraform {
  source = "${local.base_source_url}//vm?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/vm"
}

inputs = {
  node_name = "avalon"

  proxmox_endpoint  = local.node_vars.locals.pm_api_url
  proxmox_api_token = "${local.pm_api_token_id}=${local.pm_api_token_secret}"
  proxmox_insecure  = false

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
