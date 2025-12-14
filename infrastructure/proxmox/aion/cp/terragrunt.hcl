include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vm.hcl"
}

inputs = {
  target_node = "avalon"
  instances = [
    {
      vmname   = "aion-cp-01"
      vmid     = 9001
      ipconfig = "ip=dhcp"
      macaddr  = "ca:08:b1:d7:42:ff"
    },
    {
      vmname   = "aion-cp-02"
      vmid     = 9002
      ipconfig = "ip=dhcp"
      macaddr  = "d2:1f:cc:81:09:f7"
    },
    {
      vmname   = "aion-cp-03"
      vmid     = 9003
      ipconfig = "ip=dhcp"
      macaddr  = "d6:db:15:b4:d2:8a"
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
        storage    = "nvme-data"
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
        cdrom = { iso = "nfs-avalon:iso/talos-1.11.5.iso" }
      }
    }
  }

  tags = "controlplane,talos,aion"
}
