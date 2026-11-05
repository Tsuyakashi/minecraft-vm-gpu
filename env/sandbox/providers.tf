provider "proxmox" {
  endpoint  = local.proxmox_endpoint
  api_token = var.proxmox_api_token

  # Snippet uploads go over SSH; the API cannot write them.
  ssh {
    agent    = true
    username = "root"

    # Without explicit addresses the provider would SSH to the node IPs
    # reported by the Proxmox API (LAN), not to the tailnet names.
    dynamic "node" {
      for_each = local.proxmox_nodes
      content {
        name    = node.key
        address = node.value.ssh_address
      }
    }
  }
}
