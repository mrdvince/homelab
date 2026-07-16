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
      name                         = "NetBox"
      meta_icon                    = "application-icons/netbox.svg"
      extra_property_mapping_names = ["NetBox roles"]
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
    "superusers" = {}
    "staff"      = {}
  }
}
