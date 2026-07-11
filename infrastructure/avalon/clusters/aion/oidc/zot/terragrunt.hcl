include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    zot = {
      name = "Zot Registry"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://zot.home.mrdvince.me/zot/auth/callback/oidc"
        },
      ]
    }
  }

  policy_expression = null
}
