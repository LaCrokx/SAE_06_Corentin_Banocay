#!/bin/bash
# Script de déploiement de l'infrastructure SAE6 DevCloud

set -e

# Couleurs pour la mise en forme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Répertoire du script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# --- Fonctions utilitaires ---

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform n'est pas installé. Veuillez l'installer."
        exit 1
    fi
    
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible n'est pas installé. Veuillez l'installer."
        echo "  Install via Homebrew : brew install ansible"
        echo "  Install via Pip : pip3 install ansible"
        exit 1
    fi
    
    log_info "Prérequis validés (terraform, ansible)."
}

provision_vms() {
    echo ""
    log_info "Étape 1 : Provisionnement des machines virtuelles via Terraform..."
    
    cd "$PROJECT_ROOT/terraform"
    
    if terraform plan -out=tfplan; then
        log_info "Planification Terraform réussie."
        read -p "Voulez-vous appliquer le plan Terraform ? (oui/non) : " apply_terraform
        if [[ "$apply_terraform" == "oui" || "$apply_terraform" == "yes" ]]; then
            terraform apply tfplan
            log_info "Machines virtuelles provisionnées avec succès."
        else
            log_warn "Application Terraform ignorée."
            exit 0
        fi
    else
        log_error "Échec de la planification Terraform."
        exit 1
    fi
}

generate_inventory() {
    echo ""
    log_info "Étape 2 : Génération de l'inventaire Ansible..."
    
    if [[ -x "./generate_inventory.sh" ]]; then
        ./generate_inventory.sh
    else
        log_error "Script generate_inventory.sh introuvable ou non exécutable."
        exit 1
    fi
    
    log_info "Inventaire généré."
    
    echo ""
    log_warn "Adresses IP générées :"
    terraform output
    
    cd "$PROJECT_ROOT"
}

wait_for_vms() {
    echo ""
    log_info "Étape 3 : Attente de la disponibilité des machines..."
    local wait_time=30
    echo "  Pause de ${wait_time} secondes..."
    sleep $wait_time
    log_info "Les machines devraient être accessibles."
}

check_ssh_connectivity() {
    echo ""
    log_info "Étape 4 : Test de la connectivité SSH..."
    
    cd "$PROJECT_ROOT/ansible"
    
    if ansible all -i inventory/hosts.ini -m ping; then
        log_info "Tous les hôtes sont joignables."
    else
        log_error "Échec de la connexion SSH. Vérifiez :"
        echo "  - Que les VMs sont démarrées"
        echo "  - Que les IPs dans inventory/hosts.ini sont correctes"
        echo "  - Que vos clés SSH sont configurées"
        echo ""
        echo "IPs actuelles dans l'inventaire :"
        grep ansible_host inventory/hosts.ini
        exit 1
    fi
}

run_ansible_playbooks() {
    local hosts_file="inventory/hosts.ini"
    
    echo ""
    log_info "Étape 5 : Installation de Docker et Kubernetes..."
    ansible-playbook -i "$hosts_file" playbook_docker_kubernetes.yml
    log_info "Docker et Kubernetes installés."
    
    echo ""
    log_info "Étape 5b : Configuration de Containerd (Registre non sécurisé)..."
    ansible-playbook -i "$hosts_file" playbook_configure_containerd.yml
    log_info "Containerd configuré."
    
    echo ""
    log_info "Étape 6 : Configuration du serveur DNS..."
    ansible-playbook -i "$hosts_file" playbook_dns.yml
    log_info "Serveur DNS configuré."
    
    echo ""
    log_info "Étape 7 : Installation de GitLab et du Runner..."
    ansible-playbook -i "$hosts_file" playbook_gitlab.yml
    log_info "GitLab et Runner installés."
    
    echo ""
    log_info "Étape 7b : Configuration de l'accès Kubernetes pour le Runner..."
    ansible-playbook -i "$hosts_file" playbook_configure_k8s_access.yml
    log_info "Accès K8s pour le Runner configuré."
    
    echo ""
    log_info "Étape 8 : Déploiement du microservice Python..."
    ansible-playbook -i "$hosts_file" playbook_deploy.yml
    log_info "Application déployée."
}

display_final_info() {
    # Récupération des IPs finales
    local gitlab_ip
    local k8s_master_ip
    local gitlab_password
    
    gitlab_ip=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw gitlab_ip)
    k8s_master_ip=$(cd "$PROJECT_ROOT/terraform" && terraform output -json k8s_node_ips | jq -r '."k8s-node-1"')
    
    # Tentative de récupération du mot de passe GitLab via SSH
    gitlab_password=$(ssh -o StrictHostKeyChecking=no root@"${gitlab_ip}" "grep 'Mot de passe :' /root/gitlab_credentials.txt | awk '{print \$NF}'" 2>/dev/null || echo "Non récupéré (voir /root/gitlab_credentials.txt sur VM)")
    
    echo ""
    echo "=========================================="
    log_info "Mise en place de l'infrastructure terminée !"
    echo "=========================================="
    echo ""
    echo "Accéder à vos services :"
    echo "  - URL GitLab : http://${gitlab_ip}"
    echo "  - Utilisateur : root"
    echo "  - Mot de passe : ${gitlab_password}"
    echo ""
    echo "  - Application : http://${k8s_master_ip}:30080/addresses"
    echo ""
    echo "Prochaines étapes :"
    echo "  1. Connectez-vous à GitLab avec les identifiants root."
    echo "  2. Surveillez le pipeline CI/CD : http://${gitlab_ip}/root/python-microservice-tornado/-/pipelines"
    echo "  3. Vérifiez l'état du cluster Kubernetes."
    echo ""
}

# --- Exécution principale ---

main() {
    echo "=========================================="
    echo "SAE6 DevCloud - Déploiement Complet"
    echo "=========================================="
    echo ""
    
    cd "$PROJECT_ROOT"
    
    check_prerequisites
    provision_vms
    generate_inventory
    wait_for_vms
    check_ssh_connectivity
    run_ansible_playbooks
    display_final_info
}

# Lancer le script principal
main
