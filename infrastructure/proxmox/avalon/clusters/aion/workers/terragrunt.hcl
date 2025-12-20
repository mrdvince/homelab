include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vm.hcl"
}

inputs = {
  node_name = "elysium"

  instances = [
    {
      vmname  = "aion-node-01"
      vmid    = 9004
      macaddr = "A2:45:24:08:74:DC"
    },
    {
      vmname  = "aion-node-02"
      vmid    = 9005
      macaddr = "9A:EB:4A:86:5C:7E"
    },
  ]

  cores   = 4
  memory  = 8192
  balloon = 8192
  bios    = "ovmf"
  machine = "q35"
  on_boot = true

  disk = {
    storage   = "nvme-data"
    size      = 200
    interface = "scsi0"
    format    = "raw"
    discard   = "on"
    ssd       = false
    iothread  = true
  }

  cdrom = {
    iso       = "nfs-elysium:iso/talos-1.11.5.iso"
    interface = "ide2"
  }

  tags = ["worker", "talos", "aion"]
}
