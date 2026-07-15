include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    penpot = {
      name = "Penpot"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://penpot.home.mrdvince.me/api/auth/oidc/callback"
        },
      ]
    }
  }

  policy_expression = null
}
