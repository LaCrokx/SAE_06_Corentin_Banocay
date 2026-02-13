#!/bin/bash
set -e

echo "=========================================="
echo "SAE6 DevCloud - Complete Infrastructure Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
print_section() { echo -e "\n${CYAN}▸ $1${NC}"; }

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."
cd "$PROJECT_DIR"

# ============================================================================
# STEP 1: CHECK PREREQUISITES
# ============================================================================

echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install terraform."
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    print_error "Ansible not found. Please install ansible."
    echo "  Install with: brew install ansible"
    echo "  Or: pip3 install ansible"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_info "jq not found (optional but recommended). Install with: brew install jq"
fi

print_success "Prerequisites OK (terraform, ansible)"

# ============================================================================
# STEP 2: PROVISION VMs WITH TERRAFORM
# ============================================================================

echo ""
echo -e "${YELLOW}Step 1: Provisioning VMs with Terraform...${NC}"
cd terraform
if terraform plan -out=tfplan; then
    print_success "Terraform plan successful"
    read -p "Do you want to apply the Terraform plan? (yes/no): " apply_terraform
    if [ "$apply_terraform" == "yes" ]; then
        terraform apply tfplan
        print_success "VMs provisioned successfully"
    else
        echo -e "${YELLOW}Skipping Terraform apply${NC}"
        exit 0
    fi
else
    print_error "Terraform plan failed"
    exit 1
fi

# ============================================================================
# STEP 3: GENERATE ANSIBLE INVENTORY
# ============================================================================

echo ""
echo -e "${YELLOW}Step 2: Generating Ansible inventory from Terraform outputs...${NC}"
./generate_inventory.sh
print_success "Inventory generated"

# Extract IPs from Terraform for later use
GITLAB_IP=$(terraform output -raw gitlab_ip 2>/dev/null)
K8S_NODE_1_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-1"' 2>/dev/null || echo "")
K8S_NODE_2_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-2"' 2>/dev/null || echo "")
K8S_NODE_3_IP=$(terraform output -json k8s_node_ips 2>/dev/null | jq -r '."k8s-node-3"' 2>/dev/null || echo "")

echo ""
echo -e "${YELLOW}Generated IPs:${NC}"
echo "  GitLab:     $GITLAB_IP"
echo "  K8s Master: $K8S_NODE_1_IP"
echo "  K8s Worker1: $K8S_NODE_2_IP"
echo "  K8s Worker2: $K8S_NODE_3_IP"
terraform output

cd ..

# ============================================================================
# STEP 4: WAIT FOR VMs
# ============================================================================

echo ""
echo -e "${YELLOW}Step 3: Waiting for VMs to be ready...${NC}"
sleep 30
print_success "VMs should be accessible now"

# ============================================================================
# STEP 5: TEST SSH CONNECTIVITY
# ============================================================================

echo ""
echo -e "${YELLOW}Step 4: Testing SSH connectivity...${NC}"
cd ansible

max_attempts=10
attempt=1
while [ $attempt -le $max_attempts ]; do
    print_info "Attempt $attempt/$max_attempts..."
    if ansible all -i inventory/hosts.ini -m ping &> /dev/null; then
        print_success "All hosts are reachable"
        break
    fi
    if [ $attempt -eq $max_attempts ]; then
        print_error "SSH connectivity failed after $max_attempts attempts."
        echo "  - VMs are running"
        echo "  - IPs in inventory/hosts.ini are correct"
        echo "  - SSH keys are configured"
        echo ""
        echo "Current inventory IPs:"
        cat inventory/hosts.ini | grep ansible_host
        exit 1
    fi
    sleep 15
    attempt=$((attempt + 1))
done

# ============================================================================
# STEP 6: INSTALL DOCKER AND KUBERNETES
# ============================================================================

echo ""
echo -e "${YELLOW}Step 5: Installing Docker and Kubernetes...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_docker_kubernetes.yml
print_success "Docker and Kubernetes installed"

# ============================================================================
# STEP 7: SETUP DNS
# ============================================================================

echo ""
echo -e "${YELLOW}Step 6: Setting up DNS server...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_dns.yml
print_success "DNS configured"

# ============================================================================
# STEP 8: INSTALL GITLAB AND RUNNER
# ============================================================================

echo ""
echo -e "${YELLOW}Step 7: Installing GitLab and Runner...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
print_success "GitLab and Runner installed (auto-registered)"

# ============================================================================
# STEP 9: CONFIGURE CONTAINER REGISTRY ACCESS
# ============================================================================

echo ""
echo -e "${YELLOW}Step 7b: Configuring Container Registry Access...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_configure_registry.yml
ansible-playbook -i inventory/hosts.ini playbook_configure_containerd.yml
print_success "Container Registry Access configured (port 5050)"

# ============================================================================
# STEP 10: SYNC KUBECONFIG TO GITLAB RUNNER
# ============================================================================

echo ""
echo -e "${YELLOW}Step 7c: Syncing Kubeconfig to GitLab Runner...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_setup_kubeconfig.yml
print_success "Kubeconfig synced to gitlab-runner"

# ============================================================================
# STEP 11: CONFIGURE SSH BETWEEN RUNNER AND K8s NODES
# ============================================================================

echo ""
echo -e "${YELLOW}Step 8: Configuring SSH between GitLab Runner and K8s nodes...${NC}"

# Generate SSH key for gitlab-runner on GitLab VM
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${GITLAB_IP} <<'EOSSH'
sudo -u gitlab-runner bash -c '
if [ ! -f ~/.ssh/id_rsa ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa -q
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
fi
'
EOSSH

# Get the runner's public key
RUNNER_KEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${GITLAB_IP} "cat /home/gitlab-runner/.ssh/id_rsa.pub")

# Distribute to all K8s nodes
for NODE_IP in ${K8S_NODE_1_IP} ${K8S_NODE_2_IP} ${K8S_NODE_3_IP}; do
    if [ -n "$NODE_IP" ] && [ "$NODE_IP" != "null" ]; then
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@${NODE_IP} "echo '$RUNNER_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null || true
    fi
done

print_success "SSH configured between runner and K8s nodes"

# ============================================================================
# STEP 12: DEPLOY PYTHON MICROSERVICE TO GITLAB
# ============================================================================

echo ""
echo -e "${YELLOW}Step 9: Deploying Python microservice to GitLab...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_deploy.yml
print_success "Application deployed to GitLab"

# ============================================================================
# STEP 13: INJECT CI/CD VARIABLES
# ============================================================================

echo ""
echo -e "${YELLOW}Step 10: Injecting CI/CD variables into GitLab...${NC}"

# Get GitLab root password
GITLAB_ROOT_PASSWORD=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${GITLAB_IP} "grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "")

# Create a personal access token for API access
PRIVATE_TOKEN="sae-deploy-token-$(date +%s)"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${GITLAB_IP} <<EOSSH
gitlab-rails runner "
user = User.find_by_username('root')
token = user.personal_access_tokens.create(scopes: ['api', 'write_repository'], name: 'Deploy-Token-CI', expires_at: 30.days.from_now)
token.set_token('${PRIVATE_TOKEN}')
token.save!
puts 'Token created successfully'
" 2>/dev/null || true
EOSSH

# Wait for GitLab API to be ready
sleep 5

# Get the project path - use the same name as in playbook_deploy.yml
PROJECT_NAME="python-microservice-tornado"
PROJECT_PATH="root%2F${PROJECT_NAME}"

# Helper function to set a CI/CD variable
set_ci_variable() {
    local KEY="$1"
    local VALUE="$2"
    local MASKED="${3:-false}"
    
    # Try to create (POST), if exists update (PUT)
    curl -s -X POST -H "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" \
        "http://${GITLAB_IP}/api/v4/projects/${PROJECT_PATH}/variables" \
        --data "key=${KEY}" --data-urlencode "value=${VALUE}" \
        --data "masked=${MASKED}" > /dev/null 2>&1
    
    curl -s -X PUT -H "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" \
        "http://${GITLAB_IP}/api/v4/projects/${PROJECT_PATH}/variables/${KEY}" \
        --data-urlencode "value=${VALUE}" > /dev/null 2>&1
}

# Inject infrastructure variables
set_ci_variable "GITLAB_IP" "${GITLAB_IP}"
set_ci_variable "MASTER_IP" "${K8S_NODE_1_IP}"
set_ci_variable "WORKER1_IP" "${K8S_NODE_2_IP}"
set_ci_variable "WORKER2_IP" "${K8S_NODE_3_IP}"
set_ci_variable "CI_REGISTRY" "${GITLAB_IP}:5050"
set_ci_variable "K8S_REGISTRY_USER" "root"
set_ci_variable "K8S_REGISTRY_PASSWORD" "${GITLAB_ROOT_PASSWORD}" "true"
set_ci_variable "STABLE_REGISTRY_TOKEN" "${GITLAB_ROOT_PASSWORD}" "true"

print_success "CI/CD variables injected into GitLab"

# ============================================================================
# STEP 14: CONFIGURE SSH_PRIVATE_KEY FOR CI/CD
# ============================================================================

echo ""
echo -e "${YELLOW}Step 11: Configuring SSH_PRIVATE_KEY for CI/CD pipeline...${NC}"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${GITLAB_IP} <<'EOSSH'
set -e
# Copy runner's private key to a temp file
cp /home/gitlab-runner/.ssh/id_rsa /tmp/id_rsa.tmp
chmod 644 /tmp/id_rsa.tmp

# Inject via gitlab-rails
gitlab-rails runner "
  project = Project.find_by_full_path('root/python-microservice-tornado')
  if project
    key_content = File.read('/tmp/id_rsa.tmp')
    variable = project.variables.find_or_initialize_by(key: 'SSH_PRIVATE_KEY')
    variable.update!(value: key_content, variable_type: 'file', protected: false, masked: false)
    puts 'SUCCESS: SSH_PRIVATE_KEY variable set'
  else
    puts 'ERROR: Project not found'
    exit 1
  end
" 2>/dev/null

rm -f /tmp/id_rsa.tmp
EOSSH

if [ $? -eq 0 ]; then
    print_success "SSH_PRIVATE_KEY configured in GitLab"
else
    print_info "SSH_PRIVATE_KEY may need manual configuration in GitLab > Settings > CI/CD > Variables"
fi

# ============================================================================
# STEP 15: TRIGGER INITIAL PIPELINE
# ============================================================================

echo ""
echo -e "${YELLOW}Step 12: Triggering initial CI/CD pipeline...${NC}"

curl -s -X POST -H "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" \
    "http://${GITLAB_IP}/api/v4/projects/${PROJECT_PATH}/pipeline" \
    -d "ref=main" > /dev/null 2>&1 || true

print_success "Initial pipeline triggered"

# ============================================================================
# STEP 16: DISPLAY FINAL INFO
# ============================================================================

cd "$PROJECT_DIR"

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Infrastructure Setup Complete!${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Access your services:"
echo "  - GitLab:     http://${GITLAB_IP}"
echo "  - Registry:   http://${GITLAB_IP}:5050"
echo "  - App:        http://${K8S_NODE_1_IP}:30080/addresses/"
echo "  - or:         http://gitlab.local (if DNS is configured on your machine)"
echo ""
echo "GitLab Credentials:"
echo "  - Username: root"
echo "  - Password: ssh root@${GITLAB_IP} 'cat /etc/gitlab/initial_root_password'"
echo ""
echo "SSH Access:"
echo "  - GitLab:     ssh root@${GITLAB_IP}"
echo "  - K8s Master: ssh root@${K8S_NODE_1_IP}"
echo "  - K8s Worker1: ssh root@${K8S_NODE_2_IP}"
echo "  - K8s Worker2: ssh root@${K8S_NODE_3_IP}"
echo ""
echo "Useful commands:"
echo "  - Check cluster:    ssh root@${K8S_NODE_1_IP} 'kubectl get nodes'"
echo "  - Check pods:       ssh root@${K8S_NODE_1_IP} 'kubectl get pods -n addrservice'"
echo "  - Check pipeline:   http://${GITLAB_IP}/root/python-microservice-tornado/-/pipelines"
echo "  - GitLab Runner:    ssh root@${GITLAB_IP} 'gitlab-runner list'"
echo "  - Check app:        curl http://${K8S_NODE_1_IP}:30080/addresses/"
echo ""
echo "Cleanup:"
echo "  cd terraform && terraform destroy -auto-approve"
echo ""

# Save deployment info
cat > "$PROJECT_DIR/deployment-info.txt" <<EOF
═══════════════════════════════════════════════════════════
  SAE6.devcloud.01 - Deployment Information
═══════════════════════════════════════════════════════════
Date: $(date)

URLS
─────────────────────────────────────────────────────────
GitLab:       http://${GITLAB_IP}
Registry:     http://${GITLAB_IP}:5050
Application:  http://${K8S_NODE_1_IP}:30080/addresses/
Pipeline:     http://${GITLAB_IP}/root/python-microservice-tornado/-/pipelines

SSH ACCESS
─────────────────────────────────────────────────────────
GitLab:       ssh root@${GITLAB_IP}
K8s Master:   ssh root@${K8S_NODE_1_IP}
K8s Worker 1: ssh root@${K8S_NODE_2_IP}
K8s Worker 2: ssh root@${K8S_NODE_3_IP}

VERIFICATION
─────────────────────────────────────────────────────────
# Cluster
ssh root@${K8S_NODE_1_IP} 'kubectl get nodes'
ssh root@${K8S_NODE_1_IP} 'kubectl get pods -n addrservice'
# GitLab
ssh root@${GITLAB_IP} 'gitlab-ctl status'
ssh root@${GITLAB_IP} 'gitlab-runner list'
# Application
curl http://${K8S_NODE_1_IP}:30080/addresses/

CLEANUP
─────────────────────────────────────────────────────────
cd terraform && terraform destroy -auto-approve
═══════════════════════════════════════════════════════════
EOF

print_success "Deployment info saved to deployment-info.txt"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
