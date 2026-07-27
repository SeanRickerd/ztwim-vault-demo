#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Configuring Vault JWT/OIDC Auth for ZTWIM${NC}"
echo ""

# Configuration variables
VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
SPIRE_OIDC_URL="https://spire-oidc.spire.svc.cluster.local"
TRUST_DOMAIN="cluster.local"

echo -e "${BLUE}Step 1: Fetching SPIRE OIDC CA certificate${NC}"
# Get the CA cert from SPIRE OIDC service
kubectl get secret -n spire spire-oidc-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/spire-ca.crt
echo -e "${GREEN}✓ CA certificate saved to /tmp/spire-ca.crt${NC}"
echo ""

echo -e "${BLUE}Step 2: Enabling JWT auth method in Vault${NC}"
vault auth enable jwt 2>/dev/null || echo "JWT auth already enabled"
echo -e "${GREEN}✓ JWT auth method enabled${NC}"
echo ""

echo -e "${BLUE}Step 3: Configuring JWT auth with SPIRE OIDC discovery${NC}"
vault write auth/jwt/config \
  oidc_discovery_url="${SPIRE_OIDC_URL}" \
  oidc_discovery_ca_pem=@/tmp/spire-ca.crt \
  default_role="default" \
  bound_issuer="${SPIRE_OIDC_URL}"

echo -e "${GREEN}✓ JWT auth configured with SPIRE OIDC discovery${NC}"
echo ""

echo -e "${BLUE}Step 4: Creating Vault policy for payment service${NC}"
vault policy write payment-secrets - <<EOF
# Allow reading payment database secrets
path "secret/data/payment/database" {
  capabilities = ["read"]
}

# Allow listing secrets
path "secret/metadata/payment/*" {
  capabilities = ["list"]
}
EOF

echo -e "${GREEN}✓ Policy 'payment-secrets' created${NC}"
echo ""

echo -e "${BLUE}Step 5: Creating JWT role for payment-service workload${NC}"
vault write auth/jwt/role/payment-service \
  role_type="jwt" \
  bound_audiences="vault" \
  bound_subject="spiffe://${TRUST_DOMAIN}/ns/payment-demo/sa/payment-service" \
  user_claim="sub" \
  policies="payment-secrets" \
  ttl="1h" \
  max_ttl="2h"

echo -e "${GREEN}✓ Role 'payment-service' created${NC}"
echo ""

echo -e "${BLUE}Step 6: Creating test secrets${NC}"
vault kv put secret/payment/database \
  username="payment_user" \
  password="super-secret-password-123" \
  host="postgres.payment-demo.svc.cluster.local" \
  port="5432" \
  database="payments_db"

echo -e "${GREEN}✓ Test secrets created at secret/payment/database${NC}"
echo ""

echo -e "${BLUE}Step 7: Verifying configuration${NC}"
echo "OIDC Discovery URL: ${SPIRE_OIDC_URL}"
echo "Trust Domain: ${TRUST_DOMAIN}"
echo "Role: payment-service"
echo "Policy: payment-secrets"
echo ""

echo -e "${GREEN}✓ Vault JWT/OIDC auth configuration complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Deploy workloads with SPIFFE identity"
echo "2. Workloads will authenticate using JWT-SVIDs"
echo "3. Vault will validate via SPIRE OIDC discovery"
echo ""

# Test OIDC discovery endpoint
echo -e "${BLUE}Testing OIDC discovery endpoint:${NC}"
echo "Fetching ${SPIRE_OIDC_URL}/.well-known/openid-configuration"
kubectl run -it --rm --restart=Never --image=curlimages/curl:latest oidc-test \
  -- curl -k "${SPIRE_OIDC_URL}/.well-known/openid-configuration" || true
echo ""

echo -e "${GREEN}Configuration complete!${NC}"
