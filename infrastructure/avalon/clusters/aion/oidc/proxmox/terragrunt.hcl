include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {
    proxmox = {
      name = "Proxmox"
      allowed_redirect_uris = [
        {
          matching_mode = "strict"
          url           = "https://avalon.home.mrdvince.me"
        },
      ]
    }
  }

  policy_expression = null

  groups = {
    "proxmox-admins" = {}
    "proxmox-users"  = {}
  }
}
