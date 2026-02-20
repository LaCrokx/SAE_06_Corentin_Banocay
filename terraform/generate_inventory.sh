#!/bin/bash
# Creation de l'inventaire Ansible basés sur les sorties Terraform

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Construction de l'inventaire Ansible..."

# Check jq presence
if ! command -v jq &> /dev/null; then
    echo "Avertissement : jq manquant. Installation recommandée."
    echo "  Brew : brew install jq"
fi

# Fetch Terraform outputs
PUBLIC_IP_GITLAB=$(terraform output -raw public_ip_gitlab 2>/dev/null || echo "")
K8S_NODE_1_IP=$(terraform output -json k8s_nodes_public_ips 2>/dev/null | jq -r '."k8s-node-1"' 2>/dev/null || echo "")
K8S_NODE_2_IP=$(terraform output -json k8s_nodes_public_ips 2>/dev/null | jq -r '."k8s-node-2"' 2>/dev/null || echo "")
K8S_NODE_3_IP=$(terraform output -json k8s_nodes_public_ips 2>/dev/null | jq -r '."k8s-node-3"' 2>/dev/null || echo "")

if [ -z "$PUBLIC_IP_GITLAB" ] || [ -z "$K8S_NODE_1_IP" ]; then
    echo "Erreur critique : Echec de récupération des IPs. Vérifiez l'état de 'terraform apply'."
    exit 1
fi

# Write inventory file
cat > ../Ansible/inventory/hosts.ini <<EOF
# Inventaire généré automatiquement
# Date : $(date)

[gitlab]
gitlab-server ansible_host=${PUBLIC_IP_GITLAB} ansible_user=root

[k8s_master]
k8s-master ansible_host=${K8S_NODE_1_IP} ansible_user=root

[k8s_workers]
k8s-node-1 ansible_host=${K8S_NODE_2_IP} ansible_user=root
k8s-node-2 ansible_host=${K8S_NODE_3_IP} ansible_user=root

[kubernetes:children]
k8s_master
k8s_workers

[dns_server]
gitlab-server ansible_host=${PUBLIC_IP_GITLAB} ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "✓ Fichier d'inventaire créé : ../Ansible/inventory/hosts.ini"
echo ""
echo "Récapitulatif des IPs :"
echo "  GitLab        : ${PUBLIC_IP_GITLAB}"
echo "  K8s Master    : ${K8S_NODE_1_IP}"
echo "  K8s Worker 1  : ${K8S_NODE_2_IP}"
echo "  K8s Worker 2  : ${K8S_NODE_3_IP}"

