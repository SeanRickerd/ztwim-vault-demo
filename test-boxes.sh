#!/bin/bash
# Test script to verify box alignment

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo "Testing box alignment (all borders should line up perfectly):"
echo ""

echo -e "${CYAN}+====================================================================+${NC}"
echo -e "${CYAN}|                     SCENARIO 2: PROTECTED APP                      |${NC}"
echo -e "${CYAN}|          ZTWIM JWT-SVID - Credential Theft Attack (FAILS)          |${NC}"
echo -e "${CYAN}+====================================================================+${NC}"
echo ""

echo -e "${YELLOW}+====================================================================+${NC}"
echo -e "${YELLOW}| Finding #1: No static credentials found in pod                    |${NC}"
echo -e "${YELLOW}| ✓ ZTWIM eliminates static secrets                                 |${NC}"
echo -e "${YELLOW}+====================================================================+${NC}"
echo ""

echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|                   ✓ ATTACK COMPLETELY BLOCKED! ✓                   |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo ""

echo "All boxes should be exactly 70 characters wide (+ to +)"
echo "If they line up perfectly, the formatting is correct!"
echo ""
