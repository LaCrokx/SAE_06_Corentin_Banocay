output "gitlab_ip" {
  description = "L'adresse IPv4 publique de la VM GitLab"
  value       = proxmox_vm_qemu.gitlab_vm.default_ipv4_address
}

output "k8s_node_ips" {
  description = "Carte des noms de nœuds Kubernetes vers leurs adresses IPv4"
  value = {
    for i, vm in proxmox_vm_qemu.k8s_nodes : vm.name => vm.default_ipv4_address
  }
}
