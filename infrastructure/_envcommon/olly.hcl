locals {
  base_source_url = "git@gitlab.home.mrdvince.me:homelab/terraform-modules.git"
  base_source_ref = "main"

  alloy_image    = "registry.home.mrdvince.me/olly/alloy:1.16.2"
  alloy_username = "alloy"

  loki_url                    = "https://loki.home.mrdvince.me/loki/api/v1/push"
  prometheus_remote_write_url = "https://prometheus.home.mrdvince.me/api/v1/write"

  logs_container = {
    image = local.alloy_image

    ports     = ["127.0.0.1:12345:12345"]
    env_files = ["env"]
    tmpfs     = ["/tmp:rw,nosuid,nodev,noexec,size=64m"]
    volumes = [
      "/etc/olly/logs/config.alloy:/etc/alloy/logs.alloy:ro",
      "/etc/olly/logs/env:/etc/alloy/logs.env:ro",
      "/var/lib/olly/logs/data:/var/lib/alloy/data",
      "/var/log:/var/log:ro",
      "/var/run/docker.sock:/var/run/docker.sock:ro",
      "/run/log/journal:/run/log/journal:ro",
      "/var/log/journal:/var/log/journal:ro",
      "/etc/machine-id:/etc/machine-id:ro",
    ]
    command = [
      "run",
      "--server.http.listen-addr=0.0.0.0:12345",
      "--storage.path=/var/lib/alloy/data",
      "/etc/alloy/logs.alloy",
    ]
  }

  metrics_container_volumes = [
    "/etc/olly/metrics/config.alloy:/etc/alloy/metrics.alloy:ro",
    "/etc/olly/metrics/env:/etc/alloy/metrics.env:ro",
    "/var/lib/olly/metrics/data:/var/lib/alloy/data",
    "/:/host/rootfs:ro,rslave",
    "/proc:/host/proc:ro",
    "/sys:/host/sys:ro",
    "/run/udev/data:/host/run/udev/data:ro",
  ]

  metrics_container = {
    image        = local.alloy_image
    network_mode = "host"
    pid_mode     = "host"
    env_files    = ["env"]
    tmpfs        = ["/tmp:rw,nosuid,nodev,noexec,size=64m"]
    volumes      = local.metrics_container_volumes
    command = [
      "run",
      "--server.http.listen-addr=0.0.0.0:12346",
      "--storage.path=/var/lib/alloy/data",
      "/etc/alloy/metrics.alloy",
    ]
  }
}

dependency "outposts" {
  config_path = "${dirname(find_in_parent_folders("root.hcl"))}/avalon/clusters/aion/outposts"

  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    service_account_tokens = {
      alloy = "mock"
    }
  }
}

terraform {
  source = "${local.base_source_url}//olly?ref=${local.base_source_ref}"
  # source = "${dirname(find_in_parent_folders("root.hcl"))}/../../homelab-modules/olly"
}
