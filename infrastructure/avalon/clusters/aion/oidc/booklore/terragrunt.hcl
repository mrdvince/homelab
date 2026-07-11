include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    booklore = {
      name = "BookLore"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://booklore.home.mrdvince.me/oauth2-callback"
        },
      ]
    }
  }

  policy_expression = null
}
