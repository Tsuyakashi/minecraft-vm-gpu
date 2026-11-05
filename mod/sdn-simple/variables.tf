variable "zone_id" {
  description = "Identifier of the isolated SDN zone."
  type        = string
}

variable "vnet_id" {
  description = "Identifier of the virtual network that guests attach to."
  type        = string
}

variable "node_name" {
  description = "Proxmox node that hosts the segment's gateway and NAT."
  type        = string
}

variable "cidr" {
  description = "Address range of the isolated segment."
  type        = string
}

variable "gateway" {
  description = "Segment gateway that provides guests with outbound internet access via SNAT."
  type        = string
}
