output "vnet_id" {
  description = "Virtual network of the isolated segment."
  value       = proxmox_sdn_vnet.this.id
}
