resource "proxmox_hardware_mapping_pci" "gpu" {
  name = "gtx770m" # cluster-unique

  map = [{
    node         = var.proxmox_node
    path         = "0000:01:00" # без функции = VGA + HDMI-audio
    id           = "10de:11e0"
    subsystem_id = "1043:213e"
    iommu_group  = 1
  }]
}
