include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vm.hcl"
}

inputs = {
  target_node = "elysium"
  instances = [
    {
      vmname   = "aion-node-01"
      vmid     = 9004
      ipconfig = "ip=dhcp"
      macaddr  = "a2:45:24:08:74:dc"
    },
    {
      vmname   = "aion-node-02"
      vmid     = 9005
      ipconfig = "ip=dhcp"
      macaddr  = "9a:eb:4a:86:5c:7e"
    },
  ]

  vm_config_map = {
    bios                   = "ovmf"
    boot                   = "c"
    bootdisk               = "ide2"
    cores                  = 4
    define_connection_info = false
    machine                = "q35"
    memory                 = 8192
    onboot                 = true
    scsihw                 = "virtio-scsi-pci"
    balloon                = 8192
  }

  disk_configurations = {
    scsi = {
      scsi0 = { disk = {
        storage    = "local-lvm"
        backup     = true
        discard    = false
        emulatessd = false
        format     = "raw"
        iothread   = false
        readonly   = false
        replicate  = false
        size       = "200G" }
      }
    }

    ide = {
      ide2 = {
        cdrom = { iso = "nfs-elysium:iso/talos-1.9.5-qemu-guest-agent.iso" }
      }
    }
  }

  tags = "worker,talos,aion"
}
