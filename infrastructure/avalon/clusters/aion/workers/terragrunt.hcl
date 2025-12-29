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
      vmname  = "aion-21"
      vmid    = 9004
      macaddr = "A2:45:24:08:74:DC"
    },
    {
      vmname  = "aion-22"
      vmid    = 9005
      macaddr = "9A:EB:4A:86:5C:7E"
    },
    {
      vmname  = "aion-23"
      vmid    = 9006
      macaddr = "7E:99:DF:12:72:5F"
    },
  ]

  cores   = 4
  memory  = 16384
  balloon = 16384
  bios    = "ovmf"
  machine = "q35"
  on_boot = true

  disk = {
    storage   = "local-lvm"
    size      = 200
    interface = "scsi0"
    format    = "raw"
    discard   = "on"
    ssd       = false
    iothread  = true
  }

  efi_disk = {
    storage = "local-lvm"
  }
  
  cdrom = {
    iso       = "nfs-avalon:iso/talos-1.11.5.iso"
    interface = "ide2"
  }

  tags = ["worker", "talos", "aion"]
}
