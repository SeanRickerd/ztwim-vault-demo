#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ZTWIM Demo - Secrets Manager Selection                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}This demo supports multiple secrets management backends:${NC}"
echo ""
echo "  1) OpenBao (Recommended - Open Source, Vault-compatible)"
echo "  2) HashiCorp Vault (Community Edition)"
echo "  3) Auto-detect (tries OpenBao, falls back to Vault)"
echo ""

# Default to auto-detect
CHOICE="${1:-3}"

if [ -z "$1" ]; then
    echo -n "Select option [1-3] (default: 3): "
    read -r CHOICE
    CHOICE=${CHOICE:-3}
fi

case $CHOICE in
    1)
        echo ""
        echo -e "${GREEN}Deploying OpenBao...${NC}"
        export VAULT_TYPE="openbao"
        ;;
    2)
        echo ""
        echo -e "${GREEN}Deploying HashiCorp Vault...${NC}"
        export VAULT_TYPE="vault"
        ;;
    3)
        echo ""
        echo -e "${BLUE}Auto-detecting best option...${NC}"

        # Check if we can pull OpenBao image
        if kubectl run openbao-test --image=quay.io/openbao/openbao:2.0.1 --dry-run=client -o yaml >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OpenBao image available${NC}"
            export VAULT_TYPE="openbao"
        else
            echo -e "${YELLOW}⚠ OpenBao image not available, using Vault${NC}"
            export VAULT_TYPE="vault"
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}Deploying ${VAULT_TYPE^^}...${NC}"
echo ""

# Run the deployment script
./deploy-vault.sh

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Secrets Manager Setup Complete!                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$VAULT_TYPE" = "openbao" ]; then
    echo -e "${BLUE}About OpenBao:${NC}"
    echo "  OpenBao is a community-driven fork of HashiCorp Vault"
    echo "  100% compatible with Vault APIs and workflows"
    echo "  True open-source (MPL 2.0 license)"
    echo "  Community-governed via Linux Foundation"
    echo ""
    echo -e "${BLUE}CLI Tools:${NC}"
    echo "  - Use 'bao' command (OpenBao native)"
    echo "  - Or 'vault' command (compatibility mode)"
    echo ""
fi

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Verify deployment: kubectl get pods -n vault"
echo "  2. Test access: kubectl port-forward -n vault svc/${VAULT_TYPE} 8200:8200"
echo "  3. Continue demo setup: ./setup-ztwim.sh"
echo ""
