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
  config_path = "../../../../elysium/clusters/aion/workers"
}

inputs = {
  cluster_name      = "aion"
  cluster_endpoint  = "https://10.30.30.145:6443"
  talos_version     = "v1.12.0"
  config_apply_mode = "reboot"

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
          "user.max_user_namespaces"           = "11255"
          "kernel.kptr_restrict"               = "0"
          "net.core.bpf_jit_harden"            = "0"
          "fs.inotify.max_user_instances"      = "8192"
          "fs.inotify.max_user_watches"        = "1048576"
        }
        files = [
          {
            op   = "create"
            path = "/etc/cri/conf.d/20-customization.part"
            content = <<-EOT
              [plugins]
                [plugins."io.containerd.grpc.v1.cri"]
                  enable_unprivileged_ports = true
                  enable_unprivileged_icmp = true
                [plugins."io.containerd.cri.v1.images"]
                  discard_unpacked_layers = false
                [plugins."io.containerd.cri.v1.runtime"]
                  device_ownership_from_security_context = true
            EOT
          },
          {
            op          = "overwrite"
            path        = "/etc/nfsmount.conf"
            permissions = 420
            content     = <<-EOT
              [ NFSMount_Global_Options ]
              nfsvers=4.2
              hard=True
              noatime=True
              nconnect=16
            EOT
          }
        ]
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
          extraConfig = {
            featureGates = {
              UserNamespacesSupport = true
            }
          }
        }
        registries = {
          config = {
            "registry.home.mrdvince.me" = {
              auth = {
                username = include.root.locals.secret_vars.registry.username
                password = include.root.locals.secret_vars.registry.token
              }
            }
          }
        }
      }
      cluster = {
        apiServer = {
          extraArgs = {
            feature-gates = "UserNamespacesSupport=true"
          }
        }
      }
    })
  ]
}
