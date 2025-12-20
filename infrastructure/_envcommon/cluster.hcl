locals {
  base_source_url    = "git@github.com:mrdvince/homelab-modules.git"
  base_source_branch = "main"
}

terraform {
  source = "${local.base_source_url}//talos-cluster?ref=${local.base_source_branch}"
  # source = "../../../../../../../homelab-modules/talos-cluster"
}

inputs = {
  allow_scheduling_on_controlplanes = true
  disable_kube_proxy                = true
  cni                               = "none"
}
