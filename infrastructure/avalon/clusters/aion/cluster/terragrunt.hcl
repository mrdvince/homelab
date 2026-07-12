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

locals {
  external_kubelet_ssh = include.root.locals.secret_vars.aion.external_kubelet_ssh
  network_interface    = "eth0"
}

inputs = {
  cluster_name       = "aion"
  cluster_endpoint   = "https://10.30.30.145:6443"
  talos_version      = "v1.13.4"
  kubernetes_version = "1.35.6"

  controlplane_nodes = values(dependency.cp.outputs.vm_ipv4_addresses)
  worker_node_endpoints = {
    aion-21 = {
      endpoint = "10.30.30.134"
    }
    aion-22 = {
      endpoint = "10.30.30.135"
    }
    aion-23 = {
      endpoint = "10.30.30.136"
    }
    aion-24 = {
      endpoint = "10.30.30.137"
    }
  }
  worker_node_initial_taints = {
    aion-24 = [
      {
        key    = "dedicated"
        value  = "gitlab"
        effect = "PreferNoSchedule"
      }
    ]
  }

  extensions   = ["iscsi-tools", "util-linux-tools", "qemu-guest-agent"]
  auto_upgrade = true

  external_kubelet_upgrade_commands = {
    flux = <<-EOT
      ${local.external_kubelet_ssh} "set -e; sudo sed -E -i 's#core:/stable:/v[0-9]+\\.[0-9]+/rpm/#core:/stable:/v$${KUBERNETES_MINOR}/rpm/#' /etc/yum.repos.d/kubernetes.repo; sudo dnf clean metadata --disablerepo='*' --enablerepo=kubernetes; sudo dnf install -y --setopt=kubernetes.exclude= 'kubelet-$${KUBERNETES_VERSION}-*'; sudo systemctl restart kubelet"
    EOT
  }

  kubernetes = {
    pod_subnet     = "10.244.0.0/17"
    service_subnet = "10.96.0.0/17"
  }

  network = {
    interface   = local.network_interface
    vip         = "10.30.30.145"
    nameservers = ["192.168.50.120", "1.1.1.1"]
  }

  ethernet_configs = [
    {
      name = local.network_interface
      features = {
        "rx-gro"                       = false
        "rx-gro-hw"                    = false
        "tx-checksum-ip-generic"       = false
        "tx-generic-segmentation"      = false
        "tx-tcp-ecn-segmentation"      = false
        "tx-tcp-segmentation"          = false
        "tx-tcp6-segmentation"         = false
        "tx-udp-segmentation"          = false
        "tx-udp_tnl-csum-segmentation" = false
        "tx-udp_tnl-segmentation"      = false
      }
    }
  ]

  config_patches = [
    yamlencode({
      machine = {
        sysctls = {
          "user.max_user_namespaces"      = "11255"
          "kernel.kptr_restrict"          = "0"
          "net.core.bpf_jit_harden"       = "0"
          "fs.inotify.max_user_instances" = "8192"
          "fs.inotify.max_user_watches"   = "1048576"
        }
        files = [
          {
            op      = "create"
            path    = "/etc/cri/conf.d/20-customization.part"
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
            kubeReserved = {
              cpu               = "200m"
              memory            = "512Mi"
              ephemeral-storage = "2Gi"
            }
            systemReserved = {
              cpu               = "200m"
              memory            = "512Mi"
              ephemeral-storage = "2Gi"
            }
            evictionHard = {
              "memory.available"  = "500Mi"
              "nodefs.available"  = "10%"
              "imagefs.available" = "15%"
              "nodefs.inodesFree" = "5%"
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
