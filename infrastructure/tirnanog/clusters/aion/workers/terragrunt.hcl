include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vm.hcl"
}

inputs = {
  node_name = "tirnanog"

  instances = [
    {
      vmname       = "aion-25"
      vmid         = 9008
      macaddr      = "72:4B:9C:56:2D:A8"
      ipv4_address = "10.30.30.138"
    },
  ]

  cores                      = 8
  memory                     = 24576
  balloon                    = 24576
  bios                       = "ovmf"
  machine                    = "q35"
  on_boot                    = true
  cpu_type                   = "x86-64-v3"
  cpu_flags                  = ["+aes"]
  agent_enabled              = true
  agent_timeout              = "3m"
  agent_wait_for_ip_disabled = true
  reboot_after_update        = false

  include_vmname_tag = true

  disk = {
    storage   = "styx-lvm"
    size      = 200
    interface = "scsi0"
    format    = "raw"
    discard   = "on"
    ssd       = false
    iothread  = true
  }

  efi_disk = {
    storage           = "styx-lvm"
    type              = "4m"
    pre_enrolled_keys = false
  }

  cdrom = {
    iso       = "realm-nfs:iso/metal-amd64.iso"
    interface = "ide2"
  }

  tags = ["worker", "talos", "aion"]
}
