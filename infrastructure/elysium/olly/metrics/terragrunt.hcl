include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/olly.hcl"
  expose = true
}

locals {
  olly_common = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/olly.hcl")

  opnsense_host  = "vale.home.mrdvince.me"
  pve_target     = "elysium.home.mrdvince.me"
  pve_token_id   = include.root.locals.secret_vars.pve.pve_exporter_token_id
  pve_token_part = split("!", local.pve_token_id)
}

inputs = {
  name           = "metrics"
  ssh_host_alias = "elysium-yk"

  files = {
    "config.alloy" = {
      content = templatefile("${dirname(find_in_parent_folders("root.hcl"))}/_templates/olly/metrics.alloy.tftpl", {
        instance        = "elysium"
        enable_pve      = true
        pve_target      = local.pve_target
        enable_opnsense = true
        opnsense_host   = local.opnsense_host
        enable_snmp     = true
        snmp_host       = local.opnsense_host
      })
    }
  }

  secret_files = {
    env = {
      content = <<-EOF
        PROMETHEUS_REMOTE_WRITE_URL=${include.envcommon.locals.prometheus_remote_write_url}
        PROMETHEUS_USERNAME=${include.envcommon.locals.alloy_username}
        AUTHENTIK_ALLOY_APP_PASSWORD=${local.olly_common.dependency.outposts.outputs.service_account_tokens["alloy"]}
      EOF
    }

    "pve.yml" = {
      mode    = "0640"
      group   = "101"
      content = <<-EOF
        default:
          user: ${local.pve_token_part[0]}
          token_name: ${local.pve_token_part[1]}
          token_value: ${include.root.locals.secret_vars.pve.pve_exporter_token_secret}
          verify_ssl: false
      EOF
    }

    "opnsense.env" = {
      content = <<-EOF
        OPNSENSE_EXPORTER_OPS_API_KEY=${include.root.locals.secret_vars.opnsense.exporter_api_key}
        OPNSENSE_EXPORTER_OPS_API_SECRET=${include.root.locals.secret_vars.opnsense.exporter_api_secret}
      EOF
    }

    "snmp.yml" = {
      content = <<-EOF
        auths:
          opnsense_v3:
            version: 3
            security_level: authPriv
            username: ${include.envcommon.locals.alloy_username}
            password: ${include.root.locals.secret_vars.opnsense.snmp_password}
            auth_protocol: SHA
            priv_protocol: AES
            priv_password: ${include.root.locals.secret_vars.opnsense.snmp_enc_key}
      EOF
    }
  }

  containers = {
    pve-exporter = {
      image         = "registry.home.mrdvince.me/prompve/prometheus-pve-exporter:3.9.0"
      platform      = "linux/amd64"
      read_only     = false
      ports         = ["127.0.0.1:9221:9221"]
      resolve_hosts = [local.pve_target]
      volumes = [
        "/etc/resolv.conf:/etc/resolv.conf:ro",
        "/etc/olly/metrics/pve.yml:/etc/prometheus/pve.yml:ro",
      ]
    }

    opnsense-exporter = {
      image         = "registry.home.mrdvince.me/athennamind/opnsense-exporter:0.0.16"
      platform      = "linux/amd64"
      read_only     = false
      ports         = ["127.0.0.1:9222:8080"]
      env_files     = ["opnsense.env"]
      resolve_hosts = [local.opnsense_host]
      volumes       = ["/etc/resolv.conf:/etc/resolv.conf:ro"]
      command = [
        "--log.level=info",
        "--log.format=logfmt",
        "--exporter.instance-label=opnsense",
        "--opnsense.protocol=https",
        "--opnsense.address=${local.opnsense_host}",
        "--opnsense.insecure",
      ]
    }

    alloy-metrics = merge(include.envcommon.locals.metrics_container, {
      volumes = concat(
        slice(include.envcommon.locals.metrics_container_volumes, 0, 2),
        ["/etc/olly/metrics/snmp.yml:/etc/alloy/snmp.yml:ro"],
        slice(
          include.envcommon.locals.metrics_container_volumes,
          2,
          length(include.envcommon.locals.metrics_container_volumes),
        ),
      )
    })
  }
}
