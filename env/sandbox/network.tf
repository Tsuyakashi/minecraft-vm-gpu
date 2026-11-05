module "net" {
  source = "../../mod/sdn-simple"

  node_name = var.proxmox_node
  zone_id   = local.zone_id
  vnet_id   = local.vnet_id
  cidr      = local.cidr
  gateway   = local.gateway
}
