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
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfyL2fjxRE/DlFxnDOY6SKF+Zr9GAfd4Ybdm/5yOeC+v+xBfXoRWnnfsgHi+PSf/8OZ06FnLNYkjoPGr3v3NN08onN7msE0nXblw7gZlhNsxrUBm8uyPtPNdbOGup5stJWAuDhVNTCVCojveiKM/B7P2J4CUqXxD58FYirfS1LZSNBXVVSxtV14JGl0GuiwZgHBoeQabVw+rZc3uNB0zNnHZFBZ1NZiQqMyq7T+rO3CeVYYXMnyGxKEuBCI4NX3IpkLYPjgVTB3bJ/btZ6rgNZsWoc85MsjDBR3tM+/c6xXIJjFtOzn25hFP05C7nFeC+pNzbOkFCbf40eyrU9bDUm0scPEclpuRfQ1aIYLwT92+2U3q/U2wrtc5A6QIVYy4San/kYK+Dgpw2kcVFSYt2O2yPUwFuaaiBKdwxHcRv29M8olDzU2kTDdpUqD0RYWv3JRaQ6xYco+gosj3tPISxKaVFKByXSg3DhHAdV+TXVNdG5UgQymonGcmvIvrGC+UGVhcjUOk2ZLe6VV6iurpcBcOwMIwG2uLu7ePmktr9zbJLJ+EHSh5b5U+4Hcscv594nehKs/tMoOGbqSq2tSQTviQY+c1I1dBtFHePvLqv3q6OkZvFEN8PFdt5OKziEx0VnVcTM4SJbLmNcPHiF5gVRseREV2YrLNanX5KVl6wIlw== vladimir@MacBook-Pro.local"
}
