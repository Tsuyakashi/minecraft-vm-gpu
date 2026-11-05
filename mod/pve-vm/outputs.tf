output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4" {
  description = "Address the VM is reachable at inside its segment."
  value       = split("/", var.network.ipv4.address)[0]
}
