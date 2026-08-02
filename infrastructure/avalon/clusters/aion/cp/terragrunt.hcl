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
      vmname       = "aion-cp-01"
      vmid         = 9001
      macaddr      = "CA:08:B1:D7:42:FF"
      ipv4_address = "10.30.30.141"
    },
    {
      vmname       = "aion-cp-02"
      vmid         = 9002
      macaddr      = "D2:1F:CC:81:09:F7"
      ipv4_address = "10.30.30.142"
    },
    {
      vmname       = "aion-cp-03"
      vmid         = 9003
      macaddr      = "D6:DB:15:B4:D2:8A"
      ipv4_address = "10.30.30.143"
    },
  ]

  cores                      = 2
  memory                     = 8192
  balloon                    = 8192
  bios                       = "ovmf"
  boot_order                 = ["scsi0", "net0"]
  machine                    = "q35"
  on_boot                    = true
  cpu_type                   = "host"
  cpu_flags                  = ["+nested-virt"]
  agent_enabled              = true
  agent_timeout              = "3m"
  agent_wait_for_ip_disabled = true
  reboot_after_update        = false

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
    iso       = "none"
    interface = "ide2"
  }

  tags = ["controlplane", "talos", "aion"]
}
