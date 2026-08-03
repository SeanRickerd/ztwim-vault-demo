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
echo -e "${BLUE}[1/5] Deleting production namespace...${NC}"
oc delete namespace production --ignore-not-found=true
echo -e "${GREEN}✓ Production namespace deleted${NC}"
echo ""

# Delete protected production namespace
echo -e "${BLUE}[2/5] Deleting protected production namespace...${NC}"
oc delete namespace production-protected --ignore-not-found=true
echo -e "${GREEN}✓ Protected production namespace deleted${NC}"
echo ""

# Delete vault namespace
echo -e "${BLUE}[3/5] Deleting vault namespace...${NC}"
oc delete namespace vault --ignore-not-found=true
echo -e "${GREEN}✓ Vault namespace deleted${NC}"
echo ""

# Clean up temporary files
echo -e "${BLUE}[4/5] Cleaning up temporary files...${NC}"
rm -rf /tmp/demo-tokens
rm -f /tmp/backdoor.yaml
rm -f /tmp/spire-ca.crt 2>/dev/null || true
echo -e "${GREEN}✓ Temporary files cleaned${NC}"
echo ""

# Kill any lingering port-forwards
echo -e "${BLUE}[4.5/5] Checking for lingering port-forwards...${NC}"
PORTFORWARD_PIDS=$(ps aux | grep "oc port-forward" | grep -E "vault|production" | grep -v grep | awk '{print $2}' || true)
if [[ -n "$PORTFORWARD_PIDS" ]]; then
    echo "$PORTFORWARD_PIDS" | xargs kill -9 2>/dev/null || true
    echo -e "${GREEN}✓ Port-forwards terminated${NC}"
else
    echo -e "${GREEN}✓ No port-forwards to clean${NC}"
fi
echo ""

# Wait for namespaces to fully terminate
echo -e "${BLUE}[5/5] Waiting for namespaces to fully terminate...${NC}"
while oc get namespace production &>/dev/null || oc get namespace production-protected &>/dev/null || oc get namespace vault &>/dev/null; do
    echo -e "${YELLOW}  Waiting for namespaces to terminate...${NC}"
    sleep 5
done
echo -e "${GREEN}✓ All namespaces terminated${NC}"
echo ""

echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|  Cleanup Complete!                                                 |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo ""

# Verification
echo -e "${BLUE}Verification:${NC}"
echo -e "  Checking for demo namespaces..."
REMAINING_NS=$(oc get namespace 2>/dev/null | grep -E "^(production|vault)" | wc -l)
if [[ $REMAINING_NS -eq 0 ]]; then
    echo -e "  ${GREEN}✓ No demo namespaces found${NC}"
else
    echo -e "  ${YELLOW}⚠ Warning: $REMAINING_NS demo namespace(s) still terminating${NC}"
fi

echo -e "  Checking for temporary files..."
TEMP_FILES=$(ls -1 /tmp/demo-tokens /tmp/backdoor.yaml /tmp/spire-ca.crt 2>/dev/null | wc -l)
if [[ $TEMP_FILES -eq 0 ]]; then
    echo -e "  ${GREEN}✓ No temporary files found${NC}"
else
    echo -e "  ${YELLOW}⚠ Warning: $TEMP_FILES temporary file(s) remaining${NC}"
fi

echo -e "  Checking for port-forwards..."
PF_COUNT=$(ps aux | grep "oc port-forward" | grep -E "vault|production" | grep -v grep | wc -l)
if [[ $PF_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}✓ No port-forwards running${NC}"
else
    echo -e "  ${YELLOW}⚠ Warning: $PF_COUNT port-forward(s) still running${NC}"
fi

echo ""
echo -e "${GREEN}Cluster is clean and ready for a fresh demo setup.${NC}"
echo -e "${BLUE}Run: ./setup-realistic-vulnerable-environment.sh${NC}"
echo ""
