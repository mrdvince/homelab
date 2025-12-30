include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/cluster.hcl"
}

dependency "cp" {
  config_path = "../cp"
}

dependency "workers" {
  config_path = "../workers"
}

inputs = {
  cluster_name     = "aion"
  cluster_endpoint = "https://10.30.30.145:6443"
  talos_version    = "v1.12.0"

  controlplane_nodes = values(dependency.cp.outputs.vm_ipv4_addresses)
  worker_nodes       = values(dependency.workers.outputs.vm_ipv4_addresses)

  extensions   = ["iscsi-tools", "util-linux-tools", "qemu-guest-agent"]
  auto_upgrade = true

  kubernetes = {
    pod_subnet     = "10.244.0.0/17"
    service_subnet = "10.96.0.0/17"
  }

  network = {
    interface   = "enp6s18"
    vip         = "10.30.30.145"
    nameservers = ["192.168.50.120", "1.1.1.1"]
  }

  config_patches = [
    yamlencode({
      machine = {
        sysctls = {
          "user.max_user_namespaces" = "1024"
        }
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    })
  ]
}
