include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    actual = {
      name               = "Actual"
      meta_icon          = "application-icons/actual-budget.svg"
      policy_engine_mode = "all"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://actual.home.mrdvince.me/openid/callback"
        },
      ]
    }
  }

  policy_expression = null

  groups = {}
}
