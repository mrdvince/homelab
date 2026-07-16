include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    karakeep = {
      name      = "Karakeep"
      meta_icon = "application-icons/karakeep-dark.svg"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://karakeep.home.mrdvince.me/api/auth/callback/custom"
        },
      ]
    }
  }

  policy_expression = null
}
