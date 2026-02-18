#!/bin/bash
# Génère l'inventaire Ansible à partir des outputs Terraform

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Génération de l'inventaire Ansible depuis Terraform..."

# Vérification de la présence de jq
if ! command -v jq &> /dev/null; then
    echo "Attention : jq n'est pas installé. Son installation est recommandée pour un meilleur parsing JSON."
    echo "Installation via Homebrew : brew install jq"
fi

# Récupération des outputs Terraform
GITLAB_IP=$(terraform output -raw gitlab_ip 2>/dev/null || echo "")
K8S_NODE_1_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-1"' 2>/dev/null || echo "")
K8S_NODE_2_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-2"' 2>/dev/null || echo "")
K8S_NODE_3_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-3"' 2>/dev/null || echo "")

if [ -z "$GITLAB_IP" ] || [ -z "$K8S_NODE_1_IP" ]; then
    echo "Erreur : Impossible de récupérer les outputs Terraform. Assurez-vous que 'terraform apply' a été exécuté avec succès."
    exit 1
fi

# Génération du fichier d'inventaire
cat > ../ansible/inventory/hosts.ini <<EOF
# Inventaire auto-généré depuis les outputs Terraform
# Généré le : $(date)

[gitlab]
gitlab-server ansible_host=${GITLAB_IP} ansible_user=root

[k8s_master]
k8s-master ansible_host=${K8S_NODE_1_IP} ansible_user=root

[k8s_workers]
k8s-node-1 ansible_host=${K8S_NODE_2_IP} ansible_user=root
k8s-node-2 ansible_host=${K8S_NODE_3_IP} ansible_user=root

[kubernetes:children]
k8s_master
k8s_workers

[dns_server]
gitlab-server ansible_host=${GITLAB_IP} ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "✓ Inventaire généré avec succès dans ../ansible/inventory/hosts.ini"
echo ""
echo "Adresses IP récupérées :"
echo "  GitLab : ${GITLAB_IP}"
echo "  K8s Master (k8s-node-1) : ${K8S_NODE_1_IP}"
echo "  K8s Worker 1 (k8s-node-2) : ${K8S_NODE_2_IP}"
echo "  K8s Worker 2 (k8s-node-3) : ${K8S_NODE_3_IP}"

