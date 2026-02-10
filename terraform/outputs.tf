output "gitlab_ip" {
  value = proxmox_vm_qemu.gitlab_vm.default_ipv4_address
}

output "k8s_node_ips" {
  value = {
    for i, vm in proxmox_vm_qemu.k8s_nodes : vm.name => vm.default_ipv4_address
  }
}
