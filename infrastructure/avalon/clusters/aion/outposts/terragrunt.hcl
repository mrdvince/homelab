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
      external_host = "https://longhorn.home.mrdvince.me"
      mode          = "forward_single"
    }
    traefik = {
      name          = "Traefik"
      external_host = "https://traefik.home.mrdvince.me"
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
    excalidraw = {
      name          = "Excalidraw"
      external_host = "https://excalidraw.home.mrdvince.me"
      mode          = "forward_single"
    }
    pairdrop = {
      name          = "PairDrop"
      external_host = "https://pairdrop.home.mrdvince.me"
      mode          = "forward_single"
    }
    it-tools = {
      name          = "IT Tools"
      external_host = "https://it-tools.home.mrdvince.me"
      mode          = "forward_single"
    }
    omni-tools = {
      name          = "Omni Tools"
      external_host = "https://omni-tools.home.mrdvince.me"
      mode          = "forward_single"
    }
    drawio = {
      name          = "Draw.io"
      external_host = "https://drawio.home.mrdvince.me"
      mode          = "forward_single"
    }
    netbootxyz = {
      name          = "NetBoot.xyz"
      external_host = "https://netboot.home.mrdvince.me"
      mode          = "forward_single"
    }
    code-server = {
      name          = "Code Server"
      external_host = "https://code.home.mrdvince.me"
      mode          = "forward_single"
    }
  }

  outpost_name = "aion-forward-auth-outpost"

  docker_service_connection = {
    name = "aion-docker-connection"
  }

  service_accounts = {
    alloy = {
      name              = "Alloy Metrics Collector"
      token_description = "API token for Alloy to push metrics and logs"
    }
  }
}
