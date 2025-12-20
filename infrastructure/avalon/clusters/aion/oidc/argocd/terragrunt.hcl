include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    argocd = {
      name = "ArgoCD"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://argocd.aion.home.mrdvince.me/api/dex/callback"
        },
        {
          matching_mode = "strict"
          url           = "http://localhost:8085/auth/callback"
        },
      ]
    }
  }

  groups = {
    "aion-argocd-admins"  = {}
    "aion-argocd-viewers" = {}
  }
}
