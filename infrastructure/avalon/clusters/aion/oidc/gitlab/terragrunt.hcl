include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    gitlab = {
      name = "GitLab"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://gitlab.home.mrdvince.me/users/auth/openid_connect/callback"
        },
      ]
    }
  }

  policy_expression = null

  groups = {
    "gitlab-admins" = {}
    "gitlab-users"  = {}
  }
}
