output "vm_id" {
  description = "Proxmox VM ID."
  value       = module.vm.vm_id
}

output "ipv4" {
  description = "Address the VM is reachable at inside its segment."
  value       = module.vm.ipv4
}

output "ssh" {
  description = "SSH through the node — works before Tailscale is joined and if it breaks."
  value       = "ssh -J root@${local.proxmox_nodes[var.proxmox_node].ssh_address} deploy@${module.vm.ipv4}"
}

output "ssh_tailnet" {
  description = "SSH over the tailnet once the VM is joined as tag:mc-bots (MagicDNS name = VM name)."
  value       = "ssh deploy@${local.vm_name}"
}
