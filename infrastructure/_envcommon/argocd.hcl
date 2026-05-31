locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"
}

terraform {
  source = "${local.base_source_url}//argocd?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/argocd"
}
