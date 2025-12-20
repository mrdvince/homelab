include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/oidc.hcl"
}

inputs = {
  authentik_application = {}
  policy_expression     = null

  proxy_application = {
    longhorn = {
      name          = "Longhorn"
      external_host = "https://longhorn.aion.home.mrdvince.me"
      mode          = "forward_single"
    }
  }

  outpost_name = "longhorn-outpost"

  docker_service_connection = {
    name = "longhorn-docker-connection"
  }
}
