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
    {
      vmname  = "aion-24"
      vmid    = 9007
      macaddr = "7A:0F:A7:BE:01:76"
      resources = {
        cores   = 6
        memory  = 12288
        balloon = 0
      }
    },
    {
      vmname       = "aion-26"
      vmid         = 9009
      macaddr      = "02:CD:00:B5:38:E4"
      ipv4_address = "10.30.30.139"
    },
  ]

  cores                      = 4
  memory                     = 16384
  balloon                    = 16384
  bios                       = "ovmf"
  boot_order                 = ["scsi0", "net0"]
  cpu_flags                  = ["+nested-virt"]
  cpu_type                   = "host"
  machine                    = "q35"
  on_boot                    = true
  agent_timeout              = "3m"
  agent_wait_for_ip_disabled = true
  reboot_after_update        = false

  include_vmname_tag = true

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
    iso       = "realm-nfs:iso/metal-amd64.iso"
    interface = "ide2"
  }

  tags = ["worker", "talos", "aion"]
}
