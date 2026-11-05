resource "proxmox_sdn_applier" "finalizer" {

}

resource "proxmox_sdn_zone_simple" "this" {
  id    = var.zone_id
  nodes = [var.node_name]

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_vnet" "this" {
  id   = var.vnet_id
  zone = proxmox_sdn_zone_simple.this.id
}

resource "proxmox_sdn_subnet" "this" {
  vnet    = proxmox_sdn_vnet.this.id
  cidr    = var.cidr
  gateway = var.gateway
  snat    = true
}

resource "proxmox_sdn_applier" "applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.this,
      proxmox_sdn_vnet.this,
      proxmox_sdn_subnet.this,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_simple.this,
    proxmox_sdn_vnet.this,
    proxmox_sdn_subnet.this,
  ]
}
