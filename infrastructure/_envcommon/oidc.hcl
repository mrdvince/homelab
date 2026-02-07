locals {
  base_source_url    = "git@github.com:mrdvince/homelab-modules.git"
  base_source_ref    = "1627fdc"
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
