output "public_ip_gitlab" {
  description = "L'adresse IPv4 publique de la VM GitLab"
  value       = proxmox_vm_qemu.srv_gitlab.default_ipv4_address
}

output "k8s_nodes_public_ips" {
  description = "Carte des noms de nœuds Kubernetes vers leurs adresses IPv4"
  value = {
    for i, vm in proxmox_vm_qemu.cluster_nodes : vm.name => vm.default_ipv4_address
  }
}
