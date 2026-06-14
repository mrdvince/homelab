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
  name           = "logs"
  ssh_host_alias = "tirnanog-yk"

  files = {
    "config.alloy" = {
      content = templatefile("${dirname(find_in_parent_folders("root.hcl"))}/_templates/olly/logs.alloy.tftpl", {
        instance               = "tirnanog"
        enable_opnsense_syslog = false
      })
    }
  }

  secret_files = {
    env = {
      content = <<-EOF
        LOKI_URL=${include.envcommon.locals.loki_url}
        LOKI_USERNAME=${include.envcommon.locals.alloy_username}
        AUTHENTIK_ALLOY_APP_PASSWORD=${local.olly_common.dependency.outposts.outputs.service_account_tokens["alloy"]}
      EOF
    }
  }

  containers = {
    alloy-logs = include.envcommon.locals.logs_container
  }
}
