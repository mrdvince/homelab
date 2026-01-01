include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    grafana = {
      name = "Grafana"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://grafana.home.mrdvince.me/login/generic_oauth"
        },
      ]
    }
  }

  policy_expression = null

  groups = {
    "grafana-admins"  = {}
    "grafana-editors" = {}
    "grafana-viewers" = {}
  }
}
