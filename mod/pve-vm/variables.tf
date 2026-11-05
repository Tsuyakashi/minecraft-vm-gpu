variable "node_name" {
  description = "Proxmox node the VM runs on."
  type        = string
}

variable "name" {
  description = "VM name, also used as the guest hostname."
  type        = string
}

variable "description" {
  description = "Free-form note shown for the VM in Proxmox."
  type        = string
  default     = "Managed by Terraform"
}

variable "tags" {
  description = "Extra Proxmox tags for grouping and filtering the VM."
  type        = list(string)
  default     = []
}

variable "on_boot" {
  description = "Whether the VM starts together with the node."
  type        = bool
  default     = true
}

variable "cpu" {
  description = "Compute capacity and the CPU model exposed to the guest."
  type = object({
    cores = optional(number, 8)
    type  = optional(string, "x86-64-v2-AES")
  })
  default = {}
}

variable "hostpci" {
  description = "PCI devices passed through to the VM, by cluster hardware-mapping name."
  type = list(object({
    mapping  = string
    pcie     = optional(bool, true)
    rombar   = optional(bool, true)
    rom_file = optional(string)
    xvga     = optional(bool, false)
  }))
  default = []
}

variable "memory" {
  description = "RAM reserved for the VM, in MiB. With PCI passthrough all of it is pinned on the host."
  type = object({
    dedicated = optional(number, 10240)
  })
  default = {}
}

variable "disk" {
  description = "Boot disk created from the cloud image."
  type = object({
    datastore_id = optional(string, "local-lvm")
    size         = optional(number, 40)
  })
  default = {}
}

variable "cloud_image" {
  description = "Base OS image the boot disk is built from."
  type = object({
    datastore_id = optional(string, "local")
    url          = optional(string, "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img")
    file_name    = optional(string, "resolute-server-cloudimg-amd64.qcow2")
  })
  default = {}
}

variable "snippets_datastore_id" {
  description = "Storage that holds the cloud-init vendor-data snippet."
  type        = string
  default     = "local"
}

variable "cloud_init_datastore_id" {
  description = "Storage for the cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "network" {
  description = "How the VM attaches to its network and resolves names."
  type = object({
    bridge      = string
    mac_address = optional(string)
    ipv4 = object({
      address = string
      gateway = string
    })
    dns_servers = list(string)
  })
}

variable "user" {
  description = "Admin account: SSH access, owner of X, the Horizon server, the bots and Claude Code."
  type = object({
    username        = optional(string, "deploy")
    ssh_public_keys = list(string)
  })
}
