#!/bin/bash
# Script d'automatisation de l'infrastructure Cloud SAE6

set -e

# Configuration des couleurs
COL_ERR='\033[0;31m'
COL_SUCC='\033[0;32m'
COL_WARN='\033[1;33m'
COL_RESET='\033[0m'

# Chemins
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$CURRENT_DIR"

# --- Helpers ---

log_success() {
    echo -e "${COL_SUCC}[SUCCES] $1${COL_RESET}"
}

log_warning() {
    echo -e "${COL_WARN}[ATTENTION] $1${COL_RESET}"
}

log_fail() {
    echo -e "${COL_ERR}[ECHEC] $1${COL_RESET}"
}

verify_tools() {
    log_success "Contrôle des dépendances..."
    
    if ! command -v terraform &> /dev/null; then
        log_fail "Outil manquant: Terraform."
        exit 1
    fi
    
    if ! command -v ansible &> /dev/null; then
        log_fail "Outil manquant: Ansible."
        echo "  Veuillez installer ansible (brew/pip)."
        exit 1
    fi
    
    log_success "Outils détectés."
}

step_terraform_apply() {
    echo ""
    log_success "Phase 1 : Déploiement IaaS (Terraform)..."
    
    cd "$ROOT_DIR/Terraform"
    
    if terraform plan -out=tfplan; then
        log_success "Planification OK."
        read -p "Confirmer le déploiement ? (y/n) : " confirm
        if [[ "$confirm" == "y" || "$confirm" == "yes" || "$confirm" == "oui" ]]; then
            terraform apply tfplan
            log_success "Infrastructure provisionnée."
        else
            log_warning "Annulation utilisateur."
            exit 0
        fi
    else
        log_fail "Erreur de planification Terraform."
        exit 1
    fi
}

step_ansible_inventory() {
    echo ""
    log_success "Phase 2 : Construction de l'inventaire..."
    
    if [[ -x "./generate_inventory.sh" ]]; then
        ./generate_inventory.sh
    else
        log_fail "Script de génération d'inventaire absent."
        exit 1
    fi
    
    log_success "Fichier hosts.ini prêt."
    
    echo ""
    log_warning "IPs provisionnées :"
    terraform output
    
    cd "$ROOT_DIR"
}

wait_vm_boot() {
    echo ""
    log_success "Phase 3 : Stabilisation des instances..."
    local delay=30
    echo "  Patientez ${delay}s..."
    sleep $delay
    log_success "Délai écoulé."
}

verify_ssh_access() {
    echo ""
    log_success "Phase 4 : Validation SSH..."
    
    cd "$ROOT_DIR/Ansible"
    
    if ansible all -i inventory/hosts.ini -m ping; then
        log_success "Connectivité SSH établie."
    else
        log_fail "Impossible de joindre les hôtes."
        echo "  - Vérifiez l'état des VMs"
        echo "  - Vérifiez les IPs dans inventory/hosts.ini"
        exit 1
    fi
}

execute_configuration() {
    local inventory_path="inventory/hosts.ini"
    
    echo ""
    log_success "Phase 5 : Installation Container Runtime & Orchestrator..."
    ansible-playbook -i "$inventory_path" playbook_docker_kubernetes.yml
    log_success "Docker/K8s installés."
    
    echo ""
    log_success "Phase 5b : Configuration Containerd..."
    ansible-playbook -i "$inventory_path" playbook_configure_containerd.yml
    log_success "Runtime configuré."
    
    echo ""
    log_success "Phase 6 : Services DNS..."
    ansible-playbook -i "$inventory_path" playbook_dns.yml
    log_success "Service DNS actif."
    
    echo ""
    log_success "Phase 7 : Déploiement SCM (GitLab)..."
    ansible-playbook -i "$inventory_path" playbook_gitlab.yml
    log_success "GitLab opérationnel."
    
    echo ""
    log_success "Phase 7b : Permissions K8s..."
    ansible-playbook -i "$inventory_path" playbook_configure_k8s_access.yml
    log_success "Accès Cluster configuré."
    
    echo ""
    log_success "Phase 8 : Déploiement Application..."
    ansible-playbook -i "$inventory_path" playbook_deploy.yml
    log_success "Déploiement terminé."
}

show_deployment_summary() {
    local ip_gl
    local ip_k8s_node
    local pass_gl
    
    ip_gl=$(cd "$ROOT_DIR/Terraform" && terraform output -raw public_ip_gitlab)
    ip_k8s_node=$(cd "$ROOT_DIR/Terraform" && terraform output -json k8s_nodes_public_ips | jq -r '."k8s-node-1"')
    
    # Try to fetch password
    pass_gl=$(ssh -o StrictHostKeyChecking=no root@"${ip_gl}" "grep 'Mot de passe :' /root/gitlab_credentials.txt | awk '{print \$NF}'" 2>/dev/null || echo "Voir /root/gitlab_credentials.txt sur la VM")
    
    echo ""
    echo "##########################################"
    log_success "Déploiement terminé avec succès."
    echo "##########################################"
    echo ""
    echo "Accès Services :"
    echo "  - GitLab      : http://${ip_gl}"
    echo "  - Admin User  : root"
    echo "  - Admin Pass  : ${pass_gl}"
    echo ""
    echo "  - App Demo    : http://${ip_k8s_node}:30080/addresses"
    echo ""
}

# --- Main ---

run_pipeline() {
    echo "##########################################"
    echo "SAE6 Cloud Automation - Pipeline Started"
    echo "##########################################"
    echo ""
    
    cd "$ROOT_DIR"
    
    verify_tools
    step_terraform_apply
    step_ansible_inventory
    wait_vm_boot
    verify_ssh_access
    execute_configuration
    show_deployment_summary
}

run_pipeline
