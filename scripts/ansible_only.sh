#!/bin/bash
set -e

echo "=========================================="
echo "SAE6 DevCloud - Ansible Playbooks Only"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Check ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}✗ Ansible not found. Please install ansible.${NC}"
    echo "  Install with: brew install ansible"
    echo "  Or: pip3 install ansible"
    exit 1
fi

echo -e "${GREEN}✓ Ansible found${NC}"

echo ""
echo -e "${YELLOW}Step 1: Testing SSH connectivity...${NC}"
cd ansible
ansible all -i inventory/hosts.ini -m ping || {
    echo -e "${RED}✗ SSH connectivity failed. Please check:${NC}"
    echo "  - VMs are running"
    echo "  - IPs in inventory/hosts.ini are correct"
    echo "  - SSH keys are configured"
    echo ""
    echo "Current inventory IPs:"
    cat inventory/hosts.ini | grep ansible_host
    echo ""
    echo "If IPs have changed, regenerate inventory:"
    echo "  cd ../terraform && ./generate_inventory.sh"
    exit 1
}
echo -e "${GREEN}✓ All hosts are reachable${NC}"

echo ""
echo -e "${YELLOW}Step 2: Installing Docker and Kubernetes...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_docker_kubernetes.yml
echo -e "${GREEN}✓ Docker and Kubernetes installed${NC}"

echo ""
echo -e "${YELLOW}Step 3: Setting up DNS server...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_dns.yml
echo -e "${GREEN}✓ DNS configured${NC}"

echo ""
echo -e "${YELLOW}Step 4: Installing GitLab and Runner...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
echo -e "${GREEN}✓ GitLab and Runner installed${NC}"

echo ""
echo -e "${YELLOW}Step 5: Deploying Python microservice...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_deploy.yml
echo -e "${GREEN}✓ Application deployed${NC}"

# Get GitLab IP from inventory
GITLAB_IP=$(grep "gitlab-server" inventory/hosts.ini | grep -oP 'ansible_host=\K[^ ]+')

echo ""
echo "=========================================="
echo -e "${GREEN}Ansible Configuration Complete!${NC}"
echo "=========================================="
echo ""
echo "Access your services:"
echo "  - GitLab: http://${GITLAB_IP}"
echo "  - or: http://gitlab.local (if DNS is configured)"
echo ""
echo "Next steps:"
echo "  1. Get credentials: ssh root@${GITLAB_IP} 'cat /root/gitlab_credentials.txt'"
echo "  2. Register GitLab Runner (check /tmp/register_runner.sh on GitLab VM)"
echo "  3. Monitor CI/CD pipeline"
echo ""
