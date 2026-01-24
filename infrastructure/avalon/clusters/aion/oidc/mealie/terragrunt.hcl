include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    mealie = {
      name = "Mealie"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://mealie.home.mrdvince.me/login"
        },
        {
          matching_mode = "strict"
          url           = "https://mealie.home.mrdvince.me/login?direct=1"
        },
      ]
    }
  }
  policy_expression = null
}
