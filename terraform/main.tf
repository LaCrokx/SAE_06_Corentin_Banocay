resource "terraform_data" "always_run" {
  input = timestamp()
}

resource "proxmox_vm_qemu" "gitlab_vm" {
  lifecycle {
    replace_triggered_by = [terraform_data.always_run]
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
  ciuser     = var.vm_user
  cipassword = var.vm_password

  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "k8s_nodes" {
  lifecycle {
    replace_triggered_by = [terraform_data.always_run]
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
  ciuser     = var.vm_user
  cipassword = var.vm_password

  sshkeys = <<EOF
  ${var.ssh_key}
  EOF
}
