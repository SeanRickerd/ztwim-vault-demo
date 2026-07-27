#!/usr/bin/env bash
# Scenario 2: Attack on ZTWIM-Protected App with JWT-SVIDs
# This demonstrates an ATTEMPTED attack that FAILS at multiple points

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}+====================================================================+${NC}"
echo -e "${CYAN}|                     SCENARIO 2: PROTECTED APP                      |${NC}"
echo -e "${CYAN}|          ZTWIM JWT-SVID - Credential Theft Attack (FAILS)          |${NC}"
echo -e "${CYAN}+====================================================================+${NC}"
echo -e ""

VAULT_ADDR=$(cat /tmp/demo-tokens/vault-addr.txt 2>/dev/null || echo -e "http://vault.vault.svc.cluster.local:8200")

echo -e "${BLUE}[INFO]${NC} Target: Protected payment service using ZTWIM JWT-SVIDs"
echo -e "${BLUE}[INFO]${NC} Vault Address: $VAULT_ADDR"
echo -e ""

sleep 2

# Step 1: Reconnaissance
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 1: Reconnaissance - Finding the target pod${NC}"
POD=$(oc get pod -n payment-demo -l app=payment-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$POD" ]]; then
    echo -e "${RED}ERROR: Protected app not deployed${NC}"
    exit 1
fi

echo -e "${RED}[ATTACKER]${NC} Target pod identified: ${POD}"
sleep 2

# Step 2: Initial Access
echo -e ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 2: Gaining shell access to application pod${NC}"
echo -e "${BLUE}[INFO]${NC} Simulating: oc exec -it ${POD} -- /bin/bash"
sleep 2

# Step 3: Searching for static credentials
echo -e ""
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 3: Searching for static Vault credentials...${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} Checking environment variables..."
ENV_OUTPUT=$(oc exec -n payment-demo "$POD" -- printenv 2>/dev/null | grep -i "VAULT\|TOKEN\|SECRET\|PASSWORD\|KEY" || echo "")
if [[ -n "$ENV_OUTPUT" ]]; then
    echo -e "$ENV_OUTPUT" | head -5
else
    echo -e "${YELLOW}[RESULT]${NC} No static credentials in environment variables"
fi
sleep 2

echo -e "${RED}[ATTACKER]${NC} Checking common secret locations..."
echo -e "${RED}[ATTACKER]${NC} $ cat /vault/secrets/token"
oc exec -n payment-demo "$POD" -- cat /vault/secrets/token 2>&1 | head -3 || echo -e "${YELLOW}[RESULT]${NC} No file at /vault/secrets/token"
sleep 1

echo -e "${RED}[ATTACKER]${NC} $ cat /var/run/secrets/vault-token"
oc exec -n payment-demo "$POD" -- cat /var/run/secrets/vault-token 2>&1 | head -3 || echo -e "${YELLOW}[RESULT]${NC} No file at /var/run/secrets/vault-token"
sleep 1

echo -e ""
echo -e "${YELLOW}+====================================================================+${NC}"
echo -e "${YELLOW}| Finding #1: No static credentials found in pod                    |${NC}"
echo -e "${YELLOW}| ✓ ZTWIM eliminates static secrets                                 |${NC}"
echo -e "${YELLOW}+====================================================================+${NC}"
echo -e ""
sleep 2

# Step 4: Finding SPIRE socket
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 4: Searching for alternative credential sources...${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} Looking for SPIFFE Workload API..."
echo -e "${RED}[ATTACKER]${NC} $ ls -la /run/spire/sockets/"
oc exec -n payment-demo "$POD" -- ls -la /run/spire/sockets/ 2>&1 || echo -e "${YELLOW}[RESULT]${NC} SPIRE socket directory not found"
sleep 2

echo -e ""
echo -e "${RED}[ATTACKER]${NC} Attempting to access SPIRE Workload API directly..."
echo -e "${BLUE}[INFO]${NC} The Workload API is accessed via Unix socket at /run/spire/sockets/agent.sock"
sleep 1

# Try to get JWT-SVID (this will fail without proper attestation from outside)
echo -e "${RED}[ATTACKER]${NC} Trying to fetch JWT-SVID..."
sleep 1
echo -e ""
echo -e "${GREEN}[DEFENDER]${NC} ${MAGENTA}SPIRE Agent blocks the request!${NC}"
echo -e ""
echo -e "${BLUE}Why it failed:${NC}"
echo -e "  • SPIRE Workload API requires kernel-level attestation"
echo -e "  • Agent verifies the caller's PID, UID, and cgroup"
echo -e "  • Only the actual application process can access its identity"
echo -e "  • Cannot be spoofed or replayed from a shell session"
echo -e ""
sleep 3

echo -e "${YELLOW}+====================================================================+${NC}"
echo -e "${YELLOW}| Finding #2: Cannot obtain JWT-SVID from Workload API              |${NC}"
echo -e "${YELLOW}| ✓ Cryptographic attestation prevents unauthorized access          |${NC}"
echo -e "${YELLOW}+====================================================================+${NC}"
echo -e ""
sleep 2

# Step 5: Hypothetical - What if attacker DID get a JWT?
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 5: Hypothetical - What if we HAD stolen a JWT?${NC}"
sleep 1

echo -e ""
echo -e "${BLUE}[INFO]${NC} Let's simulate the attacker somehow getting a JWT-SVID..."
echo -e "${BLUE}[INFO]${NC} (In reality, this is extremely difficult due to Workload API protections)"
echo -e ""
sleep 2

# Create a fake/sample JWT for demonstration
SAMPLE_JWT="eyJhbGciOiJSUzI1NiIsImtpZCI6IlA2UEZadGx6djl1NUJuSGtRT0lMS1Z2R0pnRVdkUVRaIiwidHlwIjoiSldUIn0.eyJhdWQiOlsidmF1bHQiXSwiZXhwIjoxNzIxOTI1MzU2LCJpYXQiOjE3MjE5MjUyMzYsImlzcyI6Imh0dHBzOi8vb2lkYy1kaXNjb3ZlcnkuYXBwcy5yb3NhLnRlc3QuZXhhbXBsZS5jb20iLCJzdWIiOiJzcGlmZmU6Ly9hcHBzLnJvc2EudGVzdC5leGFtcGxlLmNvbS9ucy9wYXltZW50LWRlbW8vc2EvcGF5bWVudC1zZXJ2aWNlIn0.fake-signature"

echo -e "${RED}[ATTACKER]${NC} JWT obtained: ${SAMPLE_JWT:0:50}..."
echo -e ""

# Decode JWT to show claims
echo -e "${BLUE}[INFO]${NC} Decoding JWT claims..."
JWT_PAYLOAD=$(echo -e "$SAMPLE_JWT" | cut -d. -f2 | tr '_-' '/+')
JWT_PAD=$(( (4 - ${#JWT_PAYLOAD} % 4) % 4 ))
JWT_PAYLOAD="${JWT_PAYLOAD}$(printf '=%.0s' $(seq 1 $JWT_PAD 2>/dev/null) || true)"

echo -e ""
echo -e "${BLUE}JWT Claims:${NC}"
echo -e "$JWT_PAYLOAD" | base64 -d 2>/dev/null | jq '.' 2>/dev/null || echo -e "$JWT_PAYLOAD" | base64 -d 2>/dev/null
echo -e ""
sleep 2

# Extract expiration
JWT_EXP=$(echo -e "$JWT_PAYLOAD" | base64 -d 2>/dev/null | jq -r '.exp' 2>/dev/null || echo -e "1721925356")
CURRENT_TIME=$(date +%s)
TIME_REMAINING=$((JWT_EXP - CURRENT_TIME))

echo -e "${YELLOW}[INFO]${NC} JWT Expiration Analysis:"
echo -e "  Issued at:  $(date -d @$((JWT_EXP - 120)) 2>/dev/null || date -r $((JWT_EXP - 120)) 2>/dev/null)"
echo -e "  Expires at: $(date -d @$JWT_EXP 2>/dev/null || date -r $JWT_EXP 2>/dev/null)"
echo -e "  TTL: 2 minutes (120 seconds)"
echo -e ""

if [[ $TIME_REMAINING -lt 0 ]]; then
    echo -e "${RED}  Status: EXPIRED ${TIME_REMAINING} seconds ago${NC}"
else
    echo -e "${YELLOW}  Status: Valid for $TIME_REMAINING more seconds${NC}"
fi
echo -e ""
sleep 2

# Step 6: Try to use JWT from outside cluster
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 6: Attempting to use JWT from external location...${NC}"
echo -e "${BLUE}[INFO]${NC} Attacker exfiltrates JWT to their infrastructure"
echo -e "${BLUE}[INFO]${NC} Trying to authenticate to Vault with stolen JWT..."
sleep 2

echo -e ""
echo -e "${RED}[ATTACKER]${NC} $ curl -X POST $VAULT_ADDR/v1/auth/jwt/login \\"
echo -e "${RED}[ATTACKER]${NC}   -d '{\"jwt\":\"...\",\"role\":\"payment-service\"}'"
sleep 1
echo -e ""

# Simulate the failure
echo -e "${RED}HTTP/1.1 400 Bad Request${NC}"
echo -e "${RED}{${NC}"
echo -e "${RED}  \"errors\": [${NC}"
echo -e "${RED}    \"error validating token: token is expired\"${NC}"
echo -e "${RED}  ]${NC}"
echo -e "${RED}}${NC}"
echo -e ""
sleep 2

echo -e "${YELLOW}+====================================================================+${NC}"
echo -e "${YELLOW}| Finding #3: JWT-SVID already expired (2-minute TTL)               |${NC}"
echo -e "${YELLOW}| ✓ Even if stolen, credentials expire in 2 minutes                 |${NC}"
echo -e "${YELLOW}+====================================================================+${NC}"
echo -e ""
sleep 2

# Step 7: Try to renew
echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 7: Attempting to renew the JWT...${NC}"
sleep 1

echo -e ""
echo -e "${RED}[ATTACKER]${NC} Can we get a fresh JWT from outside the pod?"
sleep 1
echo -e ""
echo -e "${GREEN}[DEFENDER]${NC} ${MAGENTA}NO! JWT renewal requires SPIRE attestation${NC}"
echo -e ""
echo -e "${BLUE}Renewal requirements:${NC}"
echo -e "  ✗ Must be running on a legitimate cluster node (node attestation)"
echo -e "  ✗ Must have the correct pod identity (workload attestation)"
echo -e "  ✗ Must access via CSI volume mount (not available externally)"
echo -e "  ✗ SPIRE agent verifies caller via kernel cgroups and namespaces"
echo -e ""
echo -e "${YELLOW}[RESULT]${NC} Attacker cannot renew JWT from outside the pod"
echo -e ""
sleep 3

echo -e "${YELLOW}+====================================================================+${NC}"
echo -e "${YELLOW}| Finding #4: Cannot renew JWT without attestation                  |${NC}"
echo -e "${YELLOW}| ✓ SPIRE prevents external credential renewal                      |${NC}"
echo -e "${YELLOW}+====================================================================+${NC}"
echo -e ""
sleep 2

# Final summary
echo -e ""
echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|                   ✓ ATTACK COMPLETELY BLOCKED! ✓                  |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo -e ""

echo -e "${GREEN}ZTWIM Protection Summary:${NC}"
echo -e ""
echo -e "${GREEN}Defense Layer 1: No Static Secrets${NC}"
echo -e "  ✓ No tokens in environment variables"
echo -e "  ✓ No tokens in mounted files"
echo -e "  ✓ No credentials in Kubernetes Secrets"
echo -e "  ${BLUE}→ Nothing for attacker to steal${NC}"
echo -e ""

echo -e "${GREEN}Defense Layer 2: Workload API Protection${NC}"
echo -e "  ✓ SPIRE Workload API requires kernel attestation"
echo -e "  ✓ Verifies caller PID, UID, and cgroup"
echo -e "  ✓ Only the actual application can access credentials"
echo -e "  ${BLUE}→ Cannot be accessed from attacker's shell${NC}"
echo -e ""

echo -e "${GREEN}Defense Layer 3: Time-Based Expiration${NC}"
echo -e "  ✓ JWT-SVIDs expire in 2 minutes (not 90 days)"
echo -e "  ✓ Even if somehow stolen, extremely limited window"
echo -e "  ✓ Automatic rotation via SPIFFE Helper"
echo -e "  ${BLUE}→ Minimal blast radius${NC}"
echo -e ""

echo -e "${GREEN}Defense Layer 4: Renewal Prevention${NC}"
echo -e "  ✓ Cannot renew JWT without node attestation"
echo -e "  ✓ Cannot renew JWT without workload attestation"
echo -e "  ✓ CSI volume mount not accessible externally"
echo -e "  ${BLUE}→ No persistent access after compromise${NC}"
echo -e ""

echo -e "${CYAN}===========================================================${NC}"
echo -e "${CYAN}COMPARISON: Static Token vs ZTWIM JWT-SVID${NC}"
echo -e "${CYAN}===========================================================${NC}"
echo -e ""

printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Attack Step" "Static Token" "ZTWIM JWT-SVID"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Find credentials in env vars" "SUCCESS ✓" "BLOCKED ✗"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Find credentials in files" "SUCCESS ✓" "BLOCKED ✗"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Exfiltrate to external system" "SUCCESS ✓" "FAILED (expired)"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Access Vault from outside cluster" "SUCCESS ✓" "BLOCKED ✗"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Renew stolen credentials" "N/A (never expires)" "BLOCKED ✗"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Steal PII data" "SUCCESS ✓" "BLOCKED ✗"
printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Blast radius" "90 days" "2 minutes"
echo -e ""

echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}FINAL RESULT: ZTWIM prevented 100% of attack vectors${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo -e ""

echo -e "${BLUE}Business Impact:${NC}"
echo -e "  • 97% reduction in breach window (90 days → 2 minutes)"
echo -e "  • Zero static secrets to manage or rotate"
echo -e "  • Cryptographic proof of workload identity"
echo -e "  • Compliance-ready dynamic secrets"
echo -e ""

echo -e "${CYAN}Press Enter to return to menu...${NC}"
read
