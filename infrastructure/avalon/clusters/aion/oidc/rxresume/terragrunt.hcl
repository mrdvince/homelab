include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    rxresume = {
      name      = "Reactive Resume"
      meta_icon = "application-icons/rx-resume.svg"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://resume.home.mrdvince.me/api/auth/oauth2/callback/custom"
        },
      ]
    }
  }

  policy_expression = null
}
