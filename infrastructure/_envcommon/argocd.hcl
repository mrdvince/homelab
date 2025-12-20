locals {
  base_source_url    = "git@github.com:mrdvince/homelab-modules.git"
  base_source_branch = "main"
}

terraform {
  source = "${local.base_source_url}//argocd?ref=${local.base_source_branch}"
  # source = "../../../../../../../homelab-modules/argocd"
}
