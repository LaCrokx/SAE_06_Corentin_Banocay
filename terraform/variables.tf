variable "pm_api_url" {
  description = "The URL of the Proxmox API (e.g., https://192.168.1.10:8006/api2/json)"
  type        = string
}

variable "pm_user" {
  description = "The Proxmox user (e.g., root@pam)"
  type        = string
}

variable "pm_password" {
  description = "The Proxmox user password"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "The Proxmox node to deploy VMs to"
  type        = string
}

variable "template_name" {
  description = "The name of the VM template to clone"
  type        = string
}

variable "ssh_key" {
  description = "SSH public key to inject into the VMs"
  type        = string
}
