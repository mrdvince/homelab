include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    hermes = {
      name                    = "Hermes"
      meta_icon               = "application-icons/hermes.svg"
      offline_access          = true
      refresh_token_validity  = "days=7"
      refresh_token_threshold = "days=1"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://hermes.home.mrdvince.me/auth/callback"
        },
      ]
    }
  }

  policy_expression = null
}
