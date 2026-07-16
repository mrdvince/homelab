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
      meta_icon     = "application-icons/longhorn.svg"
      external_host = "https://longhorn.home.mrdvince.me"
      mode          = "forward_single"
    }
    traefik = {
      name          = "Traefik"
      meta_icon     = "application-icons/traefik-proxy.svg"
      external_host = "https://traefik.home.mrdvince.me"
      mode          = "forward_single"
    }
    prometheus = {
      name          = "Prometheus"
      meta_icon     = "application-icons/prometheus.svg"
      external_host = "https://prometheus.home.mrdvince.me"
      mode          = "forward_single"
    }
    alertmanager = {
      name          = "Alertmanager"
      meta_icon     = "application-icons/alertmanager.svg"
      external_host = "https://alertmanager.home.mrdvince.me"
      mode          = "forward_single"
    }
    loki = {
      name          = "Loki"
      meta_icon     = "application-icons/loki.svg"
      external_host = "https://loki.home.mrdvince.me"
      mode          = "forward_single"
    }
    excalidraw = {
      name          = "Excalidraw"
      meta_icon     = "application-icons/excalidraw.svg"
      external_host = "https://excalidraw.home.mrdvince.me"
      mode          = "forward_single"
    }
    pairdrop = {
      name          = "PairDrop"
      meta_icon     = "application-icons/pairdrop.png"
      external_host = "https://pairdrop.home.mrdvince.me"
      mode          = "forward_single"
    }
    it-tools = {
      name          = "IT Tools"
      meta_icon     = "application-icons/it-tools.svg"
      external_host = "https://it-tools.home.mrdvince.me"
      mode          = "forward_single"
    }
    omni-tools = {
      name          = "Omni Tools"
      meta_icon     = "application-icons/omni-tools.png"
      external_host = "https://omni-tools.home.mrdvince.me"
      mode          = "forward_single"
    }
    drawio = {
      name          = "Draw.io"
      meta_icon     = "application-icons/draw-io.svg"
      external_host = "https://drawio.home.mrdvince.me"
      mode          = "forward_single"
    }
    netbootxyz = {
      name          = "NetBoot.xyz"
      meta_icon     = "application-icons/netbootxyz.svg"
      external_host = "https://netboot.home.mrdvince.me"
      mode          = "forward_single"
    }
    code-server = {
      name          = "Code Server"
      meta_icon     = "application-icons/code-server.png"
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
