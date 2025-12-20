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
    traefik = {
      name          = "Traefik"
      external_host = "https://traefik.aion.home.mrdvince.me"
      mode          = "forward_single"
    }
  }

  outpost_name = "traefik-outpost"

  docker_service_connection = {
    name = "traefik-docker-connection"
  }
}
