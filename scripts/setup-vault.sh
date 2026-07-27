#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setting up HashiCorp Vault for ZTWIM Demo                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create vault namespace
echo -e "${BLUE}Step 1: Creating vault namespace${NC}"
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Deploy Vault using Helm (or manifests)
echo -e "${BLUE}Step 2: Deploying Vault${NC}"

# Check if Helm is available
if command -v helm &> /dev/null; then
    echo -e "${BLUE}Using Helm to deploy Vault...${NC}"

    # Add HashiCorp Helm repo
    helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
    helm repo update

    # Install Vault in dev mode for demo
    helm upgrade --install vault hashicorp/vault \
        --namespace vault \
        --set "server.dev.enabled=true" \
        --set "server.dev.devRootToken=root" \
        --set "injector.enabled=false" \
        --wait

    echo -e "${GREEN}✓ Vault deployed via Helm${NC}"
else
    echo -e "${YELLOW}Helm not found, deploying Vault with manifests...${NC}"

    # Deploy Vault using manifest
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
spec:
  ports:
  - port: 8200
    targetPort: 8200
    name: http
  selector:
    app: vault
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: vault
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: vault
        image: hashicorp/vault:latest
        ports:
        - containerPort: 8200
          name: http
        env:
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        command:
        - vault
        - server
        - -dev
        securityCapabilities:
          add:
          - IPC_LOCK
EOF

    echo -e "${GREEN}✓ Vault deployed with manifests${NC}"
fi
echo ""

# Wait for Vault to be ready
echo -e "${BLUE}Step 3: Waiting for Vault to be ready${NC}"
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s
echo -e "${GREEN}✓ Vault is ready${NC}"
echo ""

# Set up port forward for local access
echo -e "${BLUE}Step 4: Setting up port-forward for configuration${NC}"
kubectl port-forward -n vault svc/vault 8200:8200 &
PF_PID=$!
sleep 3

# Export Vault variables
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

echo -e "${GREEN}✓ Port-forward active (PID: $PF_PID)${NC}"
echo -e "${BLUE}  Vault Address: $VAULT_ADDR${NC}"
echo ""

# Enable KV secrets engine
echo -e "${BLUE}Step 5: Enabling KV secrets engine${NC}"
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV secrets engine already enabled"
echo -e "${GREEN}✓ KV secrets engine enabled${NC}"
echo ""

# Create initial secrets for demo
echo -e "${BLUE}Step 6: Creating demo secrets${NC}"
vault kv put secret/payment/database \
    username="payment_user" \
    password="demo-secret-password-123" \
    host="postgres.payment-demo.svc.cluster.local" \
    port="5432" \
    database="payments_db"

vault kv put secret/payment/api \
    api_key="demo-api-key-xyz789" \
    api_secret="demo-api-secret-abc456"

echo -e "${GREEN}✓ Demo secrets created${NC}"
echo ""

# For Scenario 1: Configure Kubernetes auth (traditional)
echo -e "${BLUE}Step 7: Configuring Kubernetes auth method (for Scenario 1)${NC}"

# Get Kubernetes info
K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')
K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)

# Enable Kubernetes auth
vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# Configure Kubernetes auth
kubectl exec -n vault deployment/vault -- vault write auth/kubernetes/config \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$K8S_CA_CERT" \
    disable_local_ca_jwt=false

# Create role for traditional auth
vault write auth/kubernetes/role/payment-service-role \
    bound_service_account_names=payment-service \
    bound_service_account_namespaces=payment-demo \
    policies=payment-secrets \
    ttl=24h

echo -e "${GREEN}✓ Kubernetes auth configured${NC}"
echo ""

# Create policy
echo -e "${BLUE}Step 8: Creating Vault policies${NC}"
vault policy write payment-secrets - <<EOF
path "secret/data/payment/*" {
  capabilities = ["read"]
}

path "secret/metadata/payment/*" {
  capabilities = ["list"]
}
EOF

echo -e "${GREEN}✓ Policies created${NC}"
echo ""

# Kill port-forward
kill $PF_PID 2>/dev/null || true

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Vault Setup Complete!                                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Vault Information:${NC}"
echo "  Namespace: vault"
echo "  Service: vault.vault.svc.cluster.local:8200"
echo "  Root Token: root (dev mode)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. For Scenario 1 (vulnerable): Ready to use"
echo "  2. For Scenario 2 (protected): Run ./setup-ztwim.sh"
echo ""
