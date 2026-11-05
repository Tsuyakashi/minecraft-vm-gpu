# Per-VM firewall lives in /etc/pve/firewall/<vmid>.fw and is deleted together
# with the VM. Without this, a recreated VM gets an in-place "update" of rules
# that no longer exist; tying them to vm_id makes them recreate with the VM.
resource "terraform_data" "vm_id" {
  input = module.vm.vm_id
}

resource "proxmox_virtual_environment_firewall_options" "vm" {
  node_name = var.proxmox_node
  vm_id     = module.vm.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  macfilter     = true
  dhcp          = false

  lifecycle {
    replace_triggered_by = [terraform_data.vm_id]
  }
}

resource "proxmox_virtual_environment_firewall_rules" "vm" {
  node_name = var.proxmox_node
  vm_id     = module.vm.vm_id

  # SSH only from the segment gateway (i.e. via `ssh -J root@<node>`).
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "22"
    source  = local.gateway
    comment = "ssh from node"
  }

  # The node routes the segment to everything it can reach itself,
  # so block every private range: LAN, other SDN segments, the node, tailnet.
  rule {
    type    = "out"
    action  = "DROP"
    dest    = "10.0.0.0/8"
    comment = "other segments + node"
  }

  rule {
    type    = "out"
    action  = "DROP"
    dest    = "172.16.0.0/12"
    comment = "private"
  }

  rule {
    type    = "out"
    action  = "DROP"
    dest    = "192.168.0.0/16"
    comment = "LAN"
  }

  rule {
    type    = "out"
    action  = "DROP"
    dest    = "100.64.0.0/10"
    comment = "tailnet via node"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.vm_id]
  }
}
