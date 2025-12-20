include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vm.hcl"
}

inputs = {
  node_name = "avalon"

  instances = [
    {
      vmname  = "aion-cp-01"
      vmid    = 9001
      macaddr = "CA:08:B1:D7:42:FF"
    },
    {
      vmname  = "aion-cp-02"
      vmid    = 9002
      macaddr = "D2:1F:CC:81:09:F7"
    },
    {
      vmname  = "aion-cp-03"
      vmid    = 9003
      macaddr = "D6:DB:15:B4:D2:8A"
    },
  ]

  cores   = 4
  memory  = 8192
  balloon = 8192
  bios    = "ovmf"
  machine = "q35"
  on_boot = true
  agent_enabled = true
  agent_timeout = "3m"

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
    iso       = "nfs-avalon:iso/talos-1.11.5.iso"
    interface = "ide2"
  }

  tags = ["controlplane", "talos", "aion"]
}
