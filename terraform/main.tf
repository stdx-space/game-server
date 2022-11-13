terraform {
  cloud {
    organization = "stdx-space"

    workspaces {
      name = "game-server"
    }
  }
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.11"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "3.27.0"
    }
  }
}

data "http" "ssh_keys" {
  url = "https://github.com/STommydx.keys"
}

resource "proxmox_vm_qemu" "game" {
  name = "game"
  desc = "Game server for misc games"

  target_node = "pve"
  vmid        = 504

  clone = "fedora-cloudinit"

  bios  = "ovmf"
  agent = 1

  memory  = 12288
  balloon = 4096
  sockets = 1
  cores   = 4
  cpu     = "host"
  scsihw  = "virtio-scsi-pci"

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "192G"
    format  = "raw"
  }

  network {
    model  = "virtio"
    bridge = "vmbr2"
  }

  os_type = "cloud-init"
  ciuser  = "stommydx"
  sshkeys = data.http.ssh_keys.response_body

  automatic_reboot = false
}

data "cloudflare_zone" "stdx_space" {
  name = "stdx.space"
}

resource "cloudflare_record" "game" {
  zone_id = data.cloudflare_zone.stdx_space.id
  name    = "game"
  value   = "game.penguin-anaconda.ts.net"
  type    = "CNAME"
}

resource "local_file" "inventory" {
  content  = <<-EOF
  [remote]
  ${proxmox_vm_qemu.game.default_ipv4_address}
  EOF
  filename = "../ansible/inventory.txt"
}

output "server_ip" {
  value = proxmox_vm_qemu.game.default_ipv4_address
}

