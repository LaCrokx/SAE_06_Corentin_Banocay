resource "proxmox_vm_qemu" "gitlab_vm" {
  name        = "gitlab-server"
  target_node = var.target_node
  clone       = var.template_name
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disk {
    slot = 0
    size = "20G"
    type = "scsi"
    storage = "local-lvm"
    iothread = 1
  }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0 = "ip=dhcp"
  
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "k8s_nodes" {
  count       = 3
  name        = "k8s-node-${count.index + 1}"
  target_node = var.target_node
  clone       = var.template_name
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disk {
    slot = 0
    size = "20G"
    type = "scsi"
    storage = "local-lvm"
    iothread = 1
  }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0 = "ip=dhcp"

  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}
