include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    termix = {
      name = "Termix"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://termix.home.mrdvince.me/users/oidc/callback"
        },
      ]
    }
  }

  policy_expression = null
}
