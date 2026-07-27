include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    open-webui = {
      name = "LibreChat"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://librechat.home.mrdvince.me/oauth/openid/callback"
        },
      ]
    }
  }

  policy_expression = null
}
