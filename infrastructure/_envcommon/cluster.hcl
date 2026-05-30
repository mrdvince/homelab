locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"
}

terraform {
  source = "${local.base_source_url}//talos-cluster?ref=${local.base_source_ref}"
  # source = "../../../../../../homelab-modules/talos-cluster"
}

inputs = {
  allow_scheduling_on_controlplanes = true
  disable_kube_proxy                = true
  cni                               = "none"
}
