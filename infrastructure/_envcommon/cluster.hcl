locals {
  site_config     = yamldecode(file("${dirname(find_in_parent_folders("root.hcl"))}/images/config.yaml"))
  base_source_url = local.site_config.gitlab.modulesRepository
  base_source_ref = "main"
}

terraform {
  source = "${local.base_source_url}//talos-cluster?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/talos-cluster"
}

inputs = {
  allow_scheduling_on_controlplanes = true
  disable_kube_proxy                = true
  cni                               = "none"
}
