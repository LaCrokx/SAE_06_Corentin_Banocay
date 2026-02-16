#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "      GitLab Project Push Helper"
echo "=========================================="
echo ""

# Change to repo root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# 1. Get GitLab IP from Terraform
echo -e "${YELLOW}Step 1: Retrieving GitLab IP from Terraform...${NC}"
if [ -d "terraform" ]; then
    GITLAB_IP=$(cd terraform && terraform output -raw gitlab_ip 2>/dev/null || echo "")
else
    echo -e "${RED}Error: terraform directory not found.${NC}"
    exit 1
fi

if [ -z "$GITLAB_IP" ]; then
    echo -e "${RED}Error: Could not retrieve GitLab IP. Is Terraform state valid?${NC}"
    exit 1
fi
echo -e "${GREEN}✓ GitLab IP: $GITLAB_IP${NC}"

# 2. Get GitLab Root Password via SSH
echo -e "${YELLOW}Step 2: Retrieving GitLab root password...${NC}"
PASSWORD=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "grep 'Password:' /root/gitlab_credentials.txt | awk '{print \$2}'")

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Could not retrieve password from GitLab VM.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Password retrieved${NC}"

# 3. Configure Git Remote
PROJECT_DIR="tutorial-python-microservice-tornado-master"
PROJECT_PATH="root/python-microservice-tornado"

echo -e "${YELLOW}Step 3: Configuring Git Remote for '$PROJECT_DIR'...${NC}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: Project directory '$PROJECT_DIR' not found.${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# Initialize git if not present
if [ ! -d ".git" ]; then
    echo "Initializing new git repository..."
    git init
    git checkout -b main 2>/dev/null || true
    git add .
    git commit -m "Initial commit"
fi

# URL Encode Password (basic encoding for common special chars)
# bash-friendly replacement for the sed command in ansible
ENCODED_PASS=$(echo "$PASSWORD" | sed 's/+/%2B/g; s/\//%2F/g; s/=/%3D/g')

REMOTE_URL="http://root:${ENCODED_PASS}@${GITLAB_IP}/${PROJECT_PATH}.git"

# Remove existing 'gitlab' remote if it exists to ensure we have the latest IP/Pass
git remote remove gitlab 2>/dev/null || true

# Add 'gitlab' remote
git remote add gitlab "$REMOTE_URL"

echo -e "${GREEN}✓ Remote 'gitlab' configured${NC}"

# 4. Unprotect main branch (to allow force push)
echo -e "${YELLOW}Step 4: Unprotecting 'main' branch...${NC}"
# 4. Unprotect main branch (to allow force push)
echo -e "${YELLOW}Step 4: Unprotecting all branches...${NC}"

# 4. Unprotect main branch (to allow force push)
echo -e "${YELLOW}Step 4: Unprotecting 'main' branch via API...${NC}"

# Generate a temporary PAT via Rails console
PAT=$(ssh -o StrictHostKeyChecking=no root@$GITLAB_IP "gitlab-rails runner \"token = User.find_by(username: 'root').personal_access_tokens.create(scopes: ['api'], name: 'Push Script Token', expires_at: 1.day.from_now); puts token.token\"")

if [ -z "$PAT" ]; then
    echo -e "${RED}Error: Could not generate Access Token.${NC}"
    # Start of debugging: try to continue if PAT failed but maybe we don't need it? No, we do.
    exit 1
fi

# Get Project ID
PROJECT_ID_JSON=$(curl -s --header "PRIVATE-TOKEN: $PAT" "http://$GITLAB_IP/api/v4/projects/$(echo $PROJECT_PATH | sed 's/\//%2F/g')")
PROJECT_ID=$(echo $PROJECT_ID_JSON | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

if [ -z "$PROJECT_ID" ]; then
     echo -e "${RED}Error: Could not find project ID for $PROJECT_PATH${NC}"
     exit 1
fi

echo "Project ID: $PROJECT_ID"

# Configure 'main' to allow force push
echo "Configuring 'main' to allow force push..."

# curl -s --request DELETE ... # Don't delete, update/create instead.

# Create protected branch 'main' with allow_force_push=true
# 40 = Maintainer access
curl -s --request POST --header "PRIVATE-TOKEN: $PAT" \
     --header "Content-Type: application/json" \
     --data '{
       "name": "main",
       "push_access_level": 40,
       "merge_access_level": 40,
       "allow_force_push": true
     }' \
     "http://$GITLAB_IP/api/v4/projects/$PROJECT_ID/protected_branches" > /dev/null

echo -e "${GREEN}✓ Protection updated (allow force push)${NC}"

# 5. Push to GitLab
echo -e "${YELLOW}Step 5: Pushing to GitLab...${NC}"
echo "Pushing 'main' branch to 'gitlab' remote..."

if git push -u gitlab main --force; then
    echo -e "${GREEN}✓ Successfully pushed to GitLab!${NC}"
    echo ""
    echo "CI/CD Pipeline should be triggered."
    echo "Check status at: http://${GITLAB_IP}/${PROJECT_PATH}/-/pipelines"
else
    echo -e "${RED}✗ Push failed.${NC}"
    exit 1
fi
