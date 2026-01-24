include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    scanopy = {
      name = "Scanopy"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://scanopy.home.mrdvince.me/api/auth/oidc/authentik/callback"
        },
      ]
    }
  }
  policy_expression = null
}
