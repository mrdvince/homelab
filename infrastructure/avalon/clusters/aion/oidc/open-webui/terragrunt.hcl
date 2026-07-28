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
      name      = "LibreChat"
      meta_icon = "https://raw.githubusercontent.com/danny-avila/LibreChat/9e74cc0e57b395926122bd4062c1fcedc48ed465/client/public/assets/logo.svg"
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
