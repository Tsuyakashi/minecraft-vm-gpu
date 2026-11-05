locals {
  vendor_data_file_name = "${var.name}-vendor-data.yaml"
  vendor_data_file_id   = "${var.snippets_datastore_id}:snippets/${local.vendor_data_file_name}"
}

resource "proxmox_download_file" "image" {
  node_name    = var.node_name
  datastore_id = var.cloud_image.datastore_id
  content_type = "import"
  url          = var.cloud_image.url
  file_name    = var.cloud_image.file_name

  overwrite = false
}

resource "proxmox_virtual_environment_file" "vendor_data" {
  node_name    = var.node_name
  datastore_id = var.snippets_datastore_id
  content_type = "snippets"

  source_raw {
    file_name = local.vendor_data_file_name
    data = templatefile("${path.module}/templates/vendor-data.yaml.tftpl", {
      username = var.user.username
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.node_name
  name        = var.name
  description = var.description
  tags        = sort(distinct(concat(["terraform"], var.tags)))
  on_boot     = var.on_boot

  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
    trim    = true

    wait_for_ip {
      ipv4 = true
    }
  }

  cpu {
    cores = var.cpu.cores
    type  = var.cpu.type
  }

  # Whole PCI devices through cluster resource mappings: an API token can attach
  # a mapping with Mapping.Use + VM.Config.HWType; a raw PCI address is root@pam-only.
  dynamic "hostpci" {
    for_each = var.hostpci
    content {
      device   = "hostpci${hostpci.key}"
      mapping  = hostpci.value.mapping
      pcie     = hostpci.value.pcie
      rombar   = hostpci.value.rombar
      rom_file = hostpci.value.rom_file
      xvga     = hostpci.value.xvga
    }
  }

  memory {
    dedicated = var.memory.dedicated
  }

  # Secure Boot on: nouveau is an in-tree, signed module, so it loads. Side effect:
  # kernel lockdown=integrity closes debugfs, so nouveau can't be reclocked by hand.
  efi_disk {
    datastore_id      = var.disk.datastore_id
    type              = "4m"
    pre_enrolled_keys = true
  }

  disk {
    datastore_id = var.disk.datastore_id
    import_from  = proxmox_download_file.image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk.size
  }

  network_device {
    bridge      = var.network.bridge
    mac_address = var.network.mac_address
    model       = "virtio"
    firewall    = true
  }

  # Cloud images log to the serial console.
  serial_device {}

  initialization {
    datastore_id = var.cloud_init_datastore_id

    ip_config {
      ipv4 {
        address = var.network.ipv4.address
        gateway = var.network.ipv4.gateway
      }
    }

    dns {
      servers = var.network.dns_servers
    }

    user_account {
      username = var.user.username
      keys     = [for k in var.user.ssh_public_keys : trimspace(k)]
    }

    vendor_data_file_id = local.vendor_data_file_id
  }

  depends_on = [proxmox_virtual_environment_file.vendor_data]
}
