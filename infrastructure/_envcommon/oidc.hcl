locals {
  site_config     = yamldecode(file("${dirname(find_in_parent_folders("root.hcl"))}/images/config.yaml"))
  base_source_url = local.site_config.gitlab.modulesRepository
  base_source_ref = "main"
}

terraform {
  source = "${local.base_source_url}//authentik?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/authentik"
}

inputs = {
  authentik_url   = "https://auth.home.mrdvince.me"
  authentik_token = get_env("AUTHENTIK_TOKEN")

  policy_expression = {
    name       = "default-oidc-policy"
    expression = "return True"
  }
}
