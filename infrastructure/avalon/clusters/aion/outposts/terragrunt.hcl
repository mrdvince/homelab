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
    traefik = {
      name          = "Traefik"
      external_host = "https://traefik.aion.home.mrdvince.me"
      mode          = "forward_single"
    }
    prometheus = {
      name          = "Prometheus"
      external_host = "https://prometheus.home.mrdvince.me"
      mode          = "forward_single"
    }
    alertmanager = {
      name          = "Alertmanager"
      external_host = "https://alertmanager.home.mrdvince.me"
      mode          = "forward_single"
    }
    loki = {
      name          = "Loki"
      external_host = "https://loki.home.mrdvince.me"
      mode          = "forward_single"
    }
  }

  outpost_name = "aion-forward-auth-outpost"

  docker_service_connection = {
    name = "aion-docker-connection"
  }
}
