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
      name = "Open WebUI"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://open-webui.home.mrdvince.me/oauth/oidc/callback"
        },
      ]
    }
  }

  policy_expression = null
}
