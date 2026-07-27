#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setting up ZTWIM (Zero Trust Workload Identity Manager)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on OpenShift
echo -e "${BLUE}Step 1: Checking cluster type${NC}"
if kubectl get clusterversion &>/dev/null; then
    echo -e "${GREEN}✓ OpenShift cluster detected${NC}"
    PLATFORM="openshift"
else
    echo -e "${YELLOW}⚠ Not an OpenShift cluster${NC}"
    echo -e "${BLUE}  ZTWIM is designed for OpenShift, but we'll proceed with manual setup${NC}"
    PLATFORM="kubernetes"
fi
echo ""

# Install ZTWIM Operator (OpenShift)
if [ "$PLATFORM" = "openshift" ]; then
    echo -e "${BLUE}Step 2: Installing ZTWIM Operator${NC}"

    cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-spire-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: openshift-spire-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    echo -e "${BLUE}  Waiting for operator to be ready...${NC}"
    sleep 10
    kubectl wait --for=condition=ready pod -l name=openshift-spire-operator -n openshift-operators --timeout=300s
    echo -e "${GREEN}✓ ZTWIM Operator installed${NC}"
else
    echo -e "${BLUE}Step 2: Installing SPIRE manually${NC}"
    echo -e "${YELLOW}  For non-OpenShift clusters, refer to: https://spiffe.io/docs/latest/deploying/installing/${NC}"
fi
echo ""

# Create SPIRE namespace
echo -e "${BLUE}Step 3: Creating SPIRE namespace${NC}"
kubectl create namespace spire --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Deploy SPIRE Server
echo -e "${BLUE}Step 4: Deploying SPIRE Server${NC}"
kubectl apply -f ../scenario-2-protected/ztwim-config/spire-server.yaml

echo -e "${BLUE}  Waiting for SPIRE Server to be ready...${NC}"
sleep 20
kubectl wait --for=condition=ready pod -l app=spire-server -n spire --timeout=300s 2>/dev/null || \
    echo -e "${YELLOW}  Waiting for SPIRE Server (this may take a few minutes)...${NC}"

echo -e "${GREEN}✓ SPIRE Server deployed${NC}"
echo ""

# Deploy SPIRE Agent
echo -e "${BLUE}Step 5: Deploying SPIRE Agent (DaemonSet)${NC}"
kubectl apply -f ../scenario-2-protected/ztwim-config/spire-agent.yaml

echo -e "${BLUE}  Waiting for SPIRE Agents to be ready...${NC}"
sleep 15
kubectl wait --for=condition=ready pod -l app=spire-agent -n spire --timeout=300s 2>/dev/null || \
    echo -e "${YELLOW}  SPIRE Agents starting (this may take a minute)...${NC}"

echo -e "${GREEN}✓ SPIRE Agents deployed${NC}"
echo ""

# Create registration entries
echo -e "${BLUE}Step 6: Creating workload registration entries${NC}"
kubectl apply -f ../scenario-2-protected/ztwim-config/registration-entry.yaml

echo -e "${GREEN}✓ Registration entries created${NC}"
echo ""

# Detect Vault type
VAULT_TYPE="vault"
VAULT_CMD="vault"
if kubectl get svc -n vault openbao >/dev/null 2>&1; then
    VAULT_TYPE="openbao"
    VAULT_CMD="bao"
    echo -e "${BLUE}Detected OpenBao${NC}"
else
    echo -e "${BLUE}Detected HashiCorp Vault${NC}"
fi

# Configure Vault/OpenBao JWT/OIDC auth
echo -e "${BLUE}Step 7: Configuring ${VAULT_TYPE^^} for SPIRE OIDC integration${NC}"
echo -e "${BLUE}  Running ${VAULT_TYPE^^} configuration script...${NC}"

# Port-forward
kubectl port-forward -n vault svc/${VAULT_TYPE} 8200:8200 &
PF_PID=$!
sleep 3

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'

# Get SPIRE OIDC discovery URL
SPIRE_OIDC_SERVICE=$(kubectl get svc -n spire -l app=spire-oidc -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "spire-oidc")
SPIRE_OIDC_URL="https://${SPIRE_OIDC_SERVICE}.spire.svc.cluster.local"

echo -e "${BLUE}  SPIRE OIDC Discovery URL: $SPIRE_OIDC_URL${NC}"

# Enable JWT auth
${VAULT_CMD} auth enable jwt 2>/dev/null || echo "  JWT auth already enabled"

# Get SPIRE CA cert
echo -e "${BLUE}  Fetching SPIRE CA certificate...${NC}"
kubectl get secret -n spire spire-server-ca -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d > /tmp/spire-ca.crt || \
    echo "  (CA cert will be configured later)"

# Configure JWT auth
if [ -f /tmp/spire-ca.crt ]; then
    ${VAULT_CMD} write auth/jwt/config \
        oidc_discovery_url="$SPIRE_OIDC_URL" \
        oidc_discovery_ca_pem=@/tmp/spire-ca.crt \
        default_role="default" \
        bound_issuer="$SPIRE_OIDC_URL"

    echo -e "${GREEN}✓ ${VAULT_TYPE^^} JWT auth configured with SPIRE OIDC${NC}"
else
    echo -e "${YELLOW}⚠ Manual Vault configuration required${NC}"
    echo -e "${BLUE}  Run: ../scenario-2-protected/vault-config/vault-jwt-auth-config.sh${NC}"
fi

# Create JWT role for payment service
${VAULT_CMD} write auth/jwt/role/payment-service \
    role_type="jwt" \
    bound_audiences="vault" \
    bound_subject="spiffe://cluster.local/ns/payment-demo/sa/payment-service" \
    user_claim="sub" \
    policies="payment-secrets" \
    ttl="1h" \
    max_ttl="2h"

echo -e "${GREEN}✓ ${VAULT_TYPE^^} role created for payment-service${NC}"

# Cleanup
kill $PF_PID 2>/dev/null || true
echo ""

# Verify setup
echo -e "${BLUE}Step 8: Verifying ZTWIM setup${NC}"

SPIRE_SERVER_PODS=$(kubectl get pods -n spire -l app=spire-server --no-headers 2>/dev/null | wc -l)
SPIRE_AGENT_PODS=$(kubectl get pods -n spire -l app=spire-agent --no-headers 2>/dev/null | wc -l)

echo -e "${BLUE}  SPIRE Server pods: $SPIRE_SERVER_PODS${NC}"
echo -e "${BLUE}  SPIRE Agent pods: $SPIRE_AGENT_PODS${NC}"

if [ "$SPIRE_SERVER_PODS" -ge 1 ] && [ "$SPIRE_AGENT_PODS" -ge 1 ]; then
    echo -e "${GREEN}✓ ZTWIM components running${NC}"
else
    echo -e "${YELLOW}⚠ ZTWIM components still starting${NC}"
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ZTWIM Setup Complete!                                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}SPIRE Components:${NC}"
echo "  Namespace: spire"
echo "  SPIRE Server: spire-server.spire.svc.cluster.local"
echo "  SPIRE OIDC: $SPIRE_OIDC_URL"
echo "  Trust Domain: cluster.local"
echo ""
echo -e "${BLUE}Vault Integration:${NC}"
echo "  Auth Method: JWT/OIDC"
echo "  OIDC Provider: SPIRE"
echo "  Role: payment-service"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Deploy protected workload: cd scenario-2-protected && kubectl apply -f deploy/"
echo "  2. Run attack simulation: cd scenario-2-protected/attack && ./demonstrate-theft.sh"
echo ""
echo -e "${GREEN}Ready for Scenario 2 demo!${NC}"
