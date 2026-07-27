#!/bin/bash
# Quick start script for presenters

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${BLUE}+======================================================+${NC}"
echo -e "${BLUE}|  ZTWIM Demo - Quick Start for Presenters            |${NC}"
echo -e "${BLUE}+======================================================+${NC}"
echo ""

echo -e "${YELLOW}This script will prepare your demo environment.${NC}"
echo ""
echo -e "It will:"
echo -e "  1. Test your environment"
echo -e "  2. Set up infrastructure if needed"
echo -e "  3. Verify everything is ready"
echo ""
read -p "Press Enter to continue..." </dev/tty

cd "$(dirname "$0")/scripts"

# Step 1: Test environment
echo ""
echo -e "${BLUE}[1/3] Testing environment...${NC}"
echo ""

if ./test-demo-environment.sh; then
    echo ""
    echo -e "${GREEN}✓ Environment looks good!${NC}"
    SETUP_NEEDED=false
else
    echo ""
    echo -e "${YELLOW}Some components are missing. Running setup...${NC}"
    SETUP_NEEDED=true
fi

# Step 2: Setup if needed
if [ "$SETUP_NEEDED" = true ]; then
    echo ""
    echo -e "${BLUE}[2/3] Setting up infrastructure...${NC}"
    echo ""

    if [ -x "setup-vault.sh" ]; then
        echo -e "${BLUE}Setting up Vault...${NC}"
        bash setup-vault.sh || true
    fi

    if [ -x "setup-ztwim.sh" ]; then
        echo -e "${BLUE}Setting up ZTWIM...${NC}"
        bash setup-ztwim.sh || true
    fi

    if [ -x "setup-vulnerable-vault.sh" ]; then
        echo -e "${BLUE}Setting up vulnerable environment...${NC}"
        bash setup-vulnerable-vault.sh || true
    fi
else
    echo ""
    echo -e "${BLUE}[2/3] Skipping setup (environment already ready)${NC}"
fi

# Step 3: Final verification
echo ""
echo -e "${BLUE}[3/3] Final verification...${NC}"
echo ""

./test-demo-environment.sh

echo ""
echo -e "${GREEN}+======================================================+${NC}"
echo -e "${GREEN}|  Demo Environment Ready!                            |${NC}"
echo -e "${GREEN}+======================================================+${NC}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo ""
echo -e "1. Review the presenter guide:"
echo -e "   ${YELLOW}cat ../PRESENTER-GUIDE.md${NC}"
echo ""
echo -e "2. Run the demo:"
echo -e "   ${YELLOW}./demo-runner.sh${NC}"
echo ""
echo -e "3. For your first run, choose option 1 (Full Demo)"
echo ""

echo -e "${BLUE}Terminal recommendations:${NC}"
echo -e "  • Font size: Large (readable from audience)"
echo -e "  • Encoding: UTF-8"
echo -e "  • Color support: Enabled"
echo -e "  • Window width: 100+ columns"
echo ""

echo -e "${GREEN}Good luck with your presentation!${NC}"
echo ""
