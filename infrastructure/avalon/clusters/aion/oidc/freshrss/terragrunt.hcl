include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    freshrss = {
      name = "FreshRSS"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://rss.home.mrdvince.me/i/oidc/"
        },
        {
          matching_mode = "strict"
          url           = "https://rss.home.mrdvince.me:443/i/oidc/"
        },
      ]
    }
  }

  policy_expression = null
}
