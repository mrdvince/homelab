include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    adventurelog = {
      name = "AdventureLog"
      allowed_redirect_uris = [
        {
          matching_mode = "regex"
          url           = "^https://adventurelog\\.home\\.mrdvince\\.me/accounts/oidc/.*$"
        },
      ]
    }
  }

  policy_expression = null
}
