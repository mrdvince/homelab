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
}

inputs = {
  name           = "metrics"
  ssh_host_alias = "tirnanog-yk"

  files = {
    "config.alloy" = {
      content = templatefile("${dirname(find_in_parent_folders("root.hcl"))}/_templates/olly/metrics.alloy.tftpl", {
        instance        = "tirnanog"
        enable_pve      = false
        pve_target      = ""
        enable_opnsense = false
        opnsense_host   = ""
        enable_snmp     = false
        snmp_host       = ""
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
  }

  containers = {
    alloy-metrics = include.envcommon.locals.metrics_container
  }
}
