variable "proxmox_node" {
  description = "Proxmox node that hosts both the isolated segment and the VM."
  type        = string
  default     = "pve-rog"

  validation {
    condition     = contains(keys(local.proxmox_nodes), var.proxmox_node)
    error_message = "proxmox_node must be one of the nodes defined in local.proxmox_nodes."
  }
}

variable "proxmox_api_token" {
  description = "API token Terraform authenticates to Proxmox with."
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "Public keys allowed to log in to the VM's admin account."
  type        = list(string)
}
