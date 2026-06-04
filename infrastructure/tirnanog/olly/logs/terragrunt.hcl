include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/olly.hcl"
}

inputs = {
  create_logs = true

  ssh_host_alias = "tirnanog-yk"

  instance = "tirnanog"
}
