module "vm" {
  source = "../../mod/pve-vm"

  node_name = var.proxmox_node
  name      = local.vm_name
  tags      = ["minecraft-vm-gpu", local.env]

  # Project-prefixed so it never collides with another repo's image on the node.
  cloud_image = {
    file_name = "minecraft-vm-gpu-resolute-amd64.qcow2"
  }

  hostpci = [{ mapping = proxmox_hardware_mapping_pci.gpu.name }]

  network = {
    bridge      = module.net.vnet_id
    mac_address = local.vm_mac
    ipv4 = {
      address = local.vm_ipv4
      gateway = local.gateway
    }
    dns_servers = local.dns_servers
  }

  user = {
    ssh_public_keys = var.ssh_public_keys
  }

  depends_on = [module.net]
}
