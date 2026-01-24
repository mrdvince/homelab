include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    paperless = {
      name = "Paperless-ngx"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://paperless.home.mrdvince.me/accounts/oidc/authentik/login/callback/"
        },
      ]
    }
  }

  policy_expression = null
}
