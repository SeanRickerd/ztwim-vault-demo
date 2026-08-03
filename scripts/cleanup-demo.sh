#!/bin/bash
# Cleanup script for ZTWIM realistic attack demo
# Removes all demo resources to prepare for next demo

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}+====================================================================+${NC}"
echo -e "${BLUE}|  Cleaning Up ZTWIM Demo Environment                               |${NC}"
echo -e "${BLUE}+====================================================================+${NC}"
echo ""

# Delete production namespace
echo -e "${BLUE}[1/4] Deleting production namespace...${NC}"
oc delete namespace production --ignore-not-found=true
echo -e "${GREEN}✓ Production namespace deleted${NC}"
echo ""

# Delete vault namespace
echo -e "${BLUE}[2/4] Deleting vault namespace...${NC}"
oc delete namespace vault --ignore-not-found=true
echo -e "${GREEN}✓ Vault namespace deleted${NC}"
echo ""

# Clean up temporary files
echo -e "${BLUE}[3/4] Cleaning up temporary files...${NC}"
rm -rf /tmp/demo-tokens
rm -f /tmp/backdoor.yaml
echo -e "${GREEN}✓ Temporary files cleaned${NC}"
echo ""

# Wait for namespaces to fully terminate
echo -e "${BLUE}[4/4] Waiting for namespaces to fully terminate...${NC}"
while oc get namespace production &>/dev/null || oc get namespace vault &>/dev/null; do
    echo -e "${YELLOW}  Waiting for namespaces to terminate...${NC}"
    sleep 5
done
echo -e "${GREEN}✓ All namespaces terminated${NC}"
echo ""

echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|  Cleanup Complete!                                                 |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo ""
echo -e "${BLUE}Environment is ready for a fresh demo setup.${NC}"
echo -e "${BLUE}Run: ./setup-realistic-vulnerable-environment.sh${NC}"
echo ""
