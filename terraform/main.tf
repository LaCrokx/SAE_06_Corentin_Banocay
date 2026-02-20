resource "terraform_data" "timestamp_trigger" {
  input = timestamp()
}

resource "proxmox_vm_qemu" "srv_gitlab" {
  lifecycle {
    replace_triggered_by = [terraform_data.timestamp_trigger]
  }
  name        = "gitlab-server"
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true
  os_type     = "cloud-init"
  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }
  memory   = 8192
  agent    = 1
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = "scsi0"
    size     = "20G"
    type     = "disk"
    storage  = "local-lvm"
    iothread = true
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    id     = 0
  }

  vga {
    type = "std"
  }

  serial {
    id   = 0
    type = "socket"
  }

  ipconfig0  = "ip=dhcp"
  ciuser     = var.admin_account
  cipassword = var.admin_auth

  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "cluster_nodes" {
  lifecycle {
    replace_triggered_by = [terraform_data.timestamp_trigger]
  }
  count       = 3
  name        = "k8s-node-${count.index + 1}"
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true
  os_type     = "cloud-init"
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  memory   = 4096
  agent    = 1
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = "scsi0"
    size     = "20G"
    type     = "disk"
    storage  = "local-lvm"
    iothread = true
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    id     = 0
  }

  vga {
    type = "std"
  }

  serial {
    id   = 0
    type = "socket"
  }

  ipconfig0  = "ip=dhcp"
  ciuser     = var.admin_account
  cipassword = var.admin_auth

  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}
