include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    linkwarden = {
      name      = "Linkwarden"
      meta_icon = "application-icons/linkwarden.svg"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://linkwarden.home.mrdvince.me/api/v1/auth/callback/authentik"
        },
      ]
    }
  }

  policy_expression = null
}
