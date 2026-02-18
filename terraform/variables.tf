variable "pm_api_url" {
  description = "L'URL de l'API Proxmox (par ex. https://192.168.1.10:8006/api2/json)"
  type        = string
}

variable "pm_user" {
  description = "L'utilisateur Proxmox (par ex. root@pam)"
  type        = string
}

variable "pm_password" {
  description = "Le mot de passe de l'utilisateur Proxmox"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Le nœud Proxmox sur lequel déployer les VMs"
  type        = string
}

variable "template_name" {
  description = "Le nom du modèle de VM à cloner"
  type        = string
}

variable "ssh_key" {
  description = "Clé publique SSH à injecter dans les VMs"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfyL2fjxRE/DlFxnDOY6SKF+Zr9GAfd4Ybdm/5yOeC+v+xBfXoRWnnfsgHi+PSf/8OZ06FnLNYkjoPGr3v3NN08onN7msE0nXblw7gZlhNsxrUBm8uyPtPNdbOGup5stJWAuDhVNTCVCojveiKM/B7P2J4CUqXxD58FYirfS1LZSNBXVVSxtV14JGl0GuiwZgHBoeQabVw+rZc3uNB0zNnHZFBZ1NZiQqMyq7T+rO3CeVYYXMnyGxKEuBCI4NX3IpkLYPjgVTB3bJ/btZ6rgNZsWoc85MsjDBR3tM+/c6xXIJjFtOzn25hFP05C7nFeC+pNzbOkFCbf40eyrU9bDUm0scPEclpuRfQ1aIYLwT92+2U3q/U2wrtc5A6QIVYy4San/kYK+Dgpw2kcVFSYt2O2yPUwFuaaiBKdwxHcRv29M8olDzU2kTDdpUqD0RYWv3JRaQ6xYco+gosj3tPISxKaVFKByXSg3DhHAdV+TXVNdG5UgQymonGcmvIvrGC+UGVhcjUOk2ZLe6VV6iurpcBcOwMIwG2uLu7ePmktr9zbJLJ+EHSh5b5U+4Hcscv594nehKs/tMoOGbqSq2tSQTviQY+c1I1dBtFHePvLqv3q6OkZvFEN8PFdt5OKziEx0VnVcTM4SJbLmNcPHiF5gVRseREV2YrLNanX5KVl6wIlw== vladimir@MacBook-Pro.local"
}

variable "vm_user" {
  description = "L'utilisateur cloud-init pour la VM"
  type        = string
  default     = "root"
}

variable "vm_password" {
  description = "Le mot de passe cloud-init pour la VM"
  type        = string
  sensitive   = true
}
