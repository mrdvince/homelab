locals {
  base_source_url    = "git@github.com:mrdvince/homelab-modules.git"
  base_source_ref    = "1627fdc"
}

terraform {
  source = "${local.base_source_url}//argocd?ref=${local.base_source_ref}"
  # source = "../../../../../../../homelab-modules/argocd"
}
