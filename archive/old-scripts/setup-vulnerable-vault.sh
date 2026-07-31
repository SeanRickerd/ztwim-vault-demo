#!/bin/bash
# Setup vulnerable Vault configuration for Scenario 1 demo
set -e

VAULT_ADDR="http://$(oc get route vault -n vault -o jsonpath='{.spec.host}')"
export VAULT_ADDR

echo "==> Setting up vulnerable Vault configuration..."
echo "    VAULT_ADDR: $VAULT_ADDR"

# Vault is in dev mode with root token 'root'
export VAULT_TOKEN=root

# Enable KV secrets engine if not already enabled
echo "==> Enabling KV secrets engine..."
oc exec -n vault vault-0 -- vault secrets enable -path=secret kv 2>/dev/null || echo "KV already enabled"

# Store sensitive data that will be stolen
echo "==> Storing sensitive PII data..."
oc exec -n vault vault-0 -- vault kv put secret/customer-data \
  credit_card='4532-1234-5678-9012' \
  ssn='123-45-6789' \
  api_key='sk-prod-super-secret-key-12345' \
  database_password='MySecureP@ssw0rd123!' \
  customer_name='John Doe' \
  account_balance='$50,000'

# Create a policy for the vulnerable app
echo "==> Creating vulnerable-app policy..."
cat <<POLICY | oc exec -i -n vault vault-0 -- sh -c "cat > /tmp/vulnerable-policy.hcl"
path "secret/customer-data" {
  capabilities = ["read"]
}
path "secret/data/customer-data" {
  capabilities = ["read"]
}
POLICY

oc exec -n vault vault-0 -- vault policy write vulnerable-app /tmp/vulnerable-policy.hcl

# Create a long-lived token (THIS IS THE VULNERABILITY)
echo "==> Creating long-lived static token (90-day TTL)..."
VULNERABLE_TOKEN=$(oc exec -n vault vault-0 -- \
  vault token create \
    -policy=vulnerable-app \
    -ttl=2160h \
    -format=json | jq -r '.auth.client_token')

echo ""
echo "✓ Vulnerable Vault setup complete!"
echo ""
echo "=== VULNERABLE CONFIGURATION ==="
echo "Static Token: ${VULNERABLE_TOKEN}"
echo "Token TTL: 90 days (2160 hours)"
echo "Accessible Secret: secret/customer-data"
echo ""
echo "This token will be 'stolen' in Scenario 1 and used by attackers."
echo ""

# Save token for demo scripts
mkdir -p /tmp/demo-tokens
echo "$VULNERABLE_TOKEN" > /tmp/demo-tokens/vulnerable-static-token.txt
echo "$VAULT_ADDR" > /tmp/demo-tokens/vault-addr.txt

echo "Token saved to: /tmp/demo-tokens/vulnerable-static-token.txt"
