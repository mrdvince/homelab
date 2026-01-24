include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    netbox = {
      name = "NetBox"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://netbox.home.mrdvince.me/oauth/complete/oidc/"
        },
      ]
    }
  }
  policy_expression = null

  groups = {
    "netbox-admins" = {}
    "netbox-users"  = {}
  }
}
