#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo -e "${YELLOW}==========================================${NC}"
echo -e "${YELLOW}       CI/CD Status Check Tool            ${NC}"
echo -e "${YELLOW}==========================================${NC}"

# Get GitLab IP
cd "$TERRAFORM_DIR"
GITLAB_IP=$(terraform output -raw gitlab_ip)

if [ -z "$GITLAB_IP" ]; then
    echo -e "${RED}Error: Could not retrieve GitLab IP from Terraform.${NC}"
    exit 1
fi

echo "GitLab IP: $GITLAB_IP"

echo -e "${YELLOW}Verifying Docker Registry Access on GitLab Server...${NC}"

# Check daemon.json content
# ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "cat /etc/docker/daemon.json"

# Test Docker Login (expecting 401 Unauthorized, NOT HTTP/HTTPS error)
LOGIN_OUTPUT=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "docker login -u test -p test gitlab.local:5005 2>&1 || true")

if echo "$LOGIN_OUTPUT" | grep -q "server gave HTTP response to HTTPS client"; then
    echo -e "${RED}FAIL: HTTP response to HTTPS client error detected.${NC}"
    echo -e "${RED}Run 'ansible-playbook ansible/playbook_docker_kubernetes.yml --tags docker' to fix.${NC}"
    exit 1
elif echo "$LOGIN_OUTPUT" | grep -q -E "unauthorized:|401 Unauthorized"; then
    echo -e "${GREEN}SUCCESS: Registry is reachable via HTTP!${NC}"
    echo -e "${GREEN}(Access denied is expected as we are using test credentials).${NC}"
elif echo "$LOGIN_OUTPUT" | grep -q "Login Succeeded"; then
    echo -e "${GREEN}SUCCESS: Login succeeded!${NC}"
else
    echo -e "${YELLOW}WARNING: Unexpected output from docker login:${NC}"
    echo "$LOGIN_OUTPUT"
fi

echo -e "${YELLOW}Verifying kubectl and envsubst on GitLab Server...${NC}"
TOOLS_CHECK=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "command -v kubectl >/dev/null && command -v envsubst >/dev/null && echo 'TOOLS_OK' || echo 'TOOLS_MISSING'")

if [ "$TOOLS_CHECK" == "TOOLS_OK" ]; then
    echo -e "${GREEN}SUCCESS: kubectl and envsubst are installed!${NC}"
else
    echo -e "${RED}FAIL: kubectl or envsubst is missing.${NC}"
    echo -e "${RED}Run 'ansible-playbook ansible/playbook_docker_kubernetes.yml --tags docker' to fix.${NC}"
    exit 1
fi

echo -e "${YELLOW}Verifying Kubeconfig for gitlab-runner...${NC}"
KUBECONFIG_CHECK=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "sudo -u gitlab-runner test -r /etc/gitlab-runner/kubeconfig/config && echo 'CONFIG_OK' || echo 'CONFIG_MISSING'")

if [ "$KUBECONFIG_CHECK" == "CONFIG_OK" ]; then
    echo -e "${GREEN}SUCCESS: Kubeconfig exists and is readable by gitlab-runner!${NC}"
else
    echo -e "${RED}FAIL: Kubeconfig missing or not readable by gitlab-runner.${NC}"
    echo -e "${RED}Run 'ansible-playbook ansible/playbook_docker_kubernetes.yml --tags docker' to fix.${NC}"
    exit 1
fi

echo -e "${YELLOW}Verifying Connectivity to K8s API...${NC}"
# Get K8s Master IP from Terraform or fallback to known IP
K8S_MASTER_IP=$(terraform output -raw k8s_master_ip 2>/dev/null || echo "10.129.5.43")

if [ -z "$K8S_MASTER_IP" ]; then
    echo -e "${RED}Warning: Could not get K8s Master IP. Skipping API check.${NC}"
else
    echo "K8s Master IP: $K8S_MASTER_IP"
    API_CHECK=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "curl --connect-timeout 5 -k https://$K8S_MASTER_IP:6443/version >/dev/null 2>&1 && echo 'API_OK' || echo 'API_FAIL'")
    
    if [ "$API_CHECK" == "API_OK" ]; then
        echo -e "${GREEN}SUCCESS: GitLab Server can reach K8s API!${NC}"
    else
        echo -e "${RED}FAIL: GitLab Server CANNOT reach K8s API ($K8S_MASTER_IP:6443).${NC}"
        echo -e "${RED}Possible firewall issue. Run 'ansible-playbook ansible/playbook_docker_kubernetes.yml' to configure UFW.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}==========================================${NC}"
