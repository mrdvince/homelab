locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"
}

terraform {
  source = "${local.base_source_url}//authentik?ref=${local.base_source_ref}"
  # source = "../../../../../../homelab-modules/authentik"
}

inputs = {
  policy_expression = {
    name       = "default-oidc-policy"
    expression = "return True"
  }
}
