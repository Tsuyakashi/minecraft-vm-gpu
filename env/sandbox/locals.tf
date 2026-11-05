locals {
  env     = "sandbox"
  vm_name = "minecraft-vm-gpu-${local.env}"

  vm_mac = "BC:24:11:97:67:B5"

  proxmox_nodes = {
    "bare-pve" = {
      endpoint    = "https://lxc-bare-pve.tail65829d.ts.net:8006/"
      ssh_address = "bare-pve.tail65829d.ts.net"
    }
    "pve-rog" = {
      endpoint    = "https://lxc-pve-rog.tail65829d.ts.net:8006/"
      ssh_address = "pve-rog.tail65829d.ts.net"
    }
    "amd-pve" = {
      endpoint    = "https://lxc-amd-pve.tail65829d.ts.net:8006/"
      ssh_address = "amd-pve.tail65829d.ts.net"
    }
  }

  proxmox_endpoint = local.proxmox_nodes[var.proxmox_node].endpoint

  zone_id = "mcvm"
  vnet_id = "mcvmv"
  cidr    = "10.64.0.0/24"
  gateway = cidrhost(local.cidr, 1)
  vm_ipv4 = "${cidrhost(local.cidr, 10)}/${split("/", local.cidr)[1]}"

  dns_servers = ["1.1.1.1", "8.8.8.8"]
}
