locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"
  secret_vars     = yamldecode(sops_decrypt_file("${dirname(find_in_parent_folders("root.hcl"))}/../secrets/secrets.enc.yaml"))
}

terraform {
  source = "${local.base_source_url}//authentik?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/authentik"
}

inputs = {
  authentik_url   = "https://auth.home.mrdvince.me"
  authentik_token = local.secret_vars.authentik

  policy_expression = {
    name       = "default-oidc-policy"
    expression = "return True"
  }
}
