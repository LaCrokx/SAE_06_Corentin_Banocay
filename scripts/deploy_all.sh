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
NC='\033[0m' # No Color

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found. Please install terraform.${NC}"
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    echo -e "${RED}✗ Ansible not found. Please install ansible.${NC}"
    echo "  Install with: brew install ansible"
    echo "  Or: pip3 install ansible"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK (terraform, ansible)${NC}"

echo ""
echo -e "${YELLOW}Step 1: Provisioning VMs with Terraform...${NC}"
cd terraform
if terraform plan -out=tfplan; then
    echo -e "${GREEN}Terraform plan successful${NC}"
    read -p "Do you want to apply the Terraform plan? (yes/no): " apply_terraform
    if [ "$apply_terraform" == "yes" ]; then
        terraform apply tfplan
        echo -e "${GREEN}✓ VMs provisioned successfully${NC}"
    else
        echo -e "${YELLOW}Skipping Terraform apply${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Generating Ansible inventory from Terraform outputs...${NC}"
./generate_inventory.sh
echo -e "${GREEN}✓ Inventory generated${NC}"

# Display generated IPs
echo ""
echo -e "${YELLOW}Generated IPs:${NC}"
terraform output

cd ..

echo ""
echo -e "${YELLOW}Step 3: Waiting for VMs to be ready...${NC}"
sleep 30
echo -e "${GREEN}✓ VMs should be accessible now${NC}"

echo ""
echo -e "${YELLOW}Step 4: Testing SSH connectivity...${NC}"
cd ansible
ansible all -i inventory/hosts.ini -m ping || {
    echo -e "${RED}✗ SSH connectivity failed. Please check:${NC}"
    echo "  - VMs are running"
    echo "  - IPs in inventory/hosts.ini are correct"
    echo "  - SSH keys are configured"
    echo ""
    echo "Current inventory IPs:"
    cat inventory/hosts.ini | grep ansible_host
    exit 1
}
echo -e "${GREEN}✓ All hosts are reachable${NC}"

echo ""
echo -e "${YELLOW}Step 5: Installing Docker and Kubernetes...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_docker_kubernetes.yml
echo -e "${GREEN}✓ Docker and Kubernetes installed${NC}"

echo ""
echo -e "${YELLOW}Step 5b: Configuring Containerd for Insecure Registry...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_configure_containerd.yml
echo -e "${GREEN}✓ Containerd configured${NC}"

echo ""
echo -e "${YELLOW}Step 6: Setting up DNS server...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_dns.yml
echo -e "${GREEN}✓ DNS configured${NC}"

echo ""
echo -e "${YELLOW}Step 7: Installing GitLab and Runner...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
echo -e "${GREEN}✓ GitLab and Runner installed${NC}"

echo ""
echo -e "${YELLOW}Step 7b: Configuring GitLab Runner Access to Kubernetes...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_configure_k8s_access.yml
echo -e "${GREEN}✓ GitLab Runner K8s access configured${NC}"

echo ""
echo -e "${YELLOW}Step 8: Deploying Python microservice...${NC}"
ansible-playbook -i inventory/hosts.ini playbook_deploy.yml
echo -e "${GREEN}✓ Application deployed${NC}"

# Get final IPs
GITLAB_IP=$(cd ../terraform && terraform output -raw gitlab_ip)
K8S_MASTER_IP=$(cd ../terraform && terraform output -json k8s_node_ips | jq -r '."k8s-node-1"')
GITLAB_PASSWORD=$(ssh -o StrictHostKeyChecking=no root@${GITLAB_IP} "grep 'Password:' /root/gitlab_credentials.txt | awk '{print \$2}'")

echo ""
echo "=========================================="
echo -e "${GREEN}Infrastructure Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Access your services:"
echo "  - GitLab URL: http://${GITLAB_IP}"
echo "  - Username:   root"
echo "  - Password:   ${GITLAB_PASSWORD}"
echo ""
echo "  - Application: http://${K8S_MASTER_IP}:30080/addresses"
echo ""
echo "Next steps:"
echo "  1. Access GitLab and login with root credentials"
echo "  2. Monitor CI/CD pipeline: http://${GITLAB_IP}/root/python-microservice-tornado/-/pipelines"
echo "  3. Check Kubernetes cluster status"
echo ""
