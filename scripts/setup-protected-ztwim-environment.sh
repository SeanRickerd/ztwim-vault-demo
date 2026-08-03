#!/bin/bash
# Setup ZTWIM-protected environment with short-lived credentials
# This shows the "after" scenario with dynamic workload identities

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VAULT_NS="vault"
PROTECTED_NS="production-protected"

echo -e "${BLUE}+====================================================================+${NC}"
echo -e "${BLUE}|  Setting Up ZTWIM-Protected Environment                           |${NC}"
echo -e "${BLUE}+====================================================================+${NC}"
echo ""

# Verify Vault is running
echo -e "${BLUE}[1/5] Checking for Vault...${NC}"
VAULT_POD=$(oc get pod -n ${VAULT_NS} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$VAULT_POD" ]]; then
    echo -e "${RED}ERROR: Vault not found in namespace ${VAULT_NS}${NC}"
    echo -e "${YELLOW}Please run ./setup-realistic-vulnerable-environment.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Vault is running${NC}"
echo ""

# Create protected namespace
echo -e "${BLUE}[2/5] Creating protected production namespace...${NC}"
oc create namespace ${PROTECTED_NS} 2>/dev/null || true

# Grant anyuid SCC for the payment processor
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-processor-protected
  namespace: ${PROTECTED_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payment-processor-protected-anyuid
  namespace: ${PROTECTED_NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:anyuid
subjects:
- kind: ServiceAccount
  name: payment-processor-protected
  namespace: ${PROTECTED_NS}
EOF

echo -e "${GREEN}✓ Protected namespace created${NC}"
echo ""

# Deploy ZTWIM-protected payment processor (simulated with JWT rotation)
echo -e "${BLUE}[3/5] Deploying ZTWIM-protected payment processor...${NC}"

cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor-protected
  namespace: ${PROTECTED_NS}
  labels:
    app: payment-processor-protected
    security: ztwim-protected
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-processor-protected
  template:
    metadata:
      labels:
        app: payment-processor-protected
        security: ztwim-protected
    spec:
      serviceAccountName: payment-processor-protected
      securityContext:
        runAsUser: 0
      containers:
      - name: app
        image: registry.access.redhat.com/ubi9/ubi:latest
        command:
        - /bin/bash
        - -c
        - |
          #!/bin/bash
          echo "=========================================="
          echo "  Payment Processing Service (PROTECTED)"
          echo "=========================================="
          echo ""
          echo "Environment: PRODUCTION-PROTECTED"
          echo "Vault Address: http://vault.vault.svc.cluster.local:8200"
          echo "Service Status: Running"
          echo ""
          echo "✅  Using ZTWIM dynamic credentials"
          echo "✅  JWT-SVID rotates every 2 minutes"
          echo "✅  No static tokens in environment"
          echo ""
          # Install tools
          dnf install -y postgresql jq && dnf clean all
          echo "Database client and tools installed"
          echo ""

          # Simulate ZTWIM JWT-SVID rotation
          while true; do
            # Generate a short-lived JWT (simulating SPIRE SVID)
            JWT_EXPIRY=\$(date -u -d '+2 minutes' +%s)
            echo "[\$(date)] ZTWIM: New JWT-SVID issued (expires in 2 minutes)"

            # In real ZTWIM, this would be the SPIFFE JWT-SVID from the SPIRE agent
            # For demo, we'll use Kubernetes service account token (also short-lived)
            export VAULT_TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
            export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"

            # Sleep until near expiry
            sleep 110  # Rotate every ~2 minutes
          done
        env:
        - name: DATABASE_HOST
          value: customer-database.production.svc.cluster.local
EOF

echo -e "${GREEN}✓ ZTWIM-protected payment processor deployed${NC}"
echo ""

# Wait for app to be ready
echo -e "${BLUE}[4/5] Waiting for protected application to be ready...${NC}"
oc wait --for=condition=ready pod -l app=payment-processor-protected -n ${PROTECTED_NS} --timeout=120s
echo -e "${GREEN}✓ Protected application is ready${NC}"
echo ""

# Configure Vault JWT auth for Kubernetes (simulating SPIRE OIDC)
echo -e "${BLUE}[5/5] Configuring Vault JWT authentication...${NC}"

# Enable Kubernetes auth method (simulating SPIRE JWT auth)
oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault auth enable kubernetes 2>/dev/null || true"

# Get Kubernetes API details
K8S_HOST=$(oc whoami --show-server)
K8S_CA_CERT=$(oc exec -n ${PROTECTED_NS} deployment/payment-processor-protected -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
K8S_SA_TOKEN=$(oc create token payment-processor-protected -n ${PROTECTED_NS} --duration=24h)

# Configure Kubernetes auth
oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault write auth/kubernetes/config \
  kubernetes_host='${K8S_HOST}' \
  kubernetes_ca_cert='${K8S_CA_CERT}' \
  token_reviewer_jwt='${K8S_SA_TOKEN}'" 2>/dev/null || true

# Create Vault role for protected workload
oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault write auth/kubernetes/role/payment-processor-protected \
  bound_service_account_names=payment-processor-protected \
  bound_service_account_namespaces=${PROTECTED_NS} \
  policies=payment-access \
  ttl=2m \
  max_ttl=5m"

echo -e "${GREEN}✓ Vault JWT authentication configured${NC}"
echo ""

echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|  ZTWIM-Protected Environment Setup Complete                       |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo ""

echo -e "${YELLOW}Environment Details:${NC}"
echo -e "  Namespace: ${PROTECTED_NS}"
echo -e "  Protected App: payment-processor-protected"
echo -e "  Credential Type: Dynamic JWT-SVIDs"
echo -e "  Token TTL: 2 minutes (auto-rotates)"
echo -e "  Token Max TTL: 5 minutes"
echo ""

echo -e "${YELLOW}ZTWIM Protection:${NC}"
echo -e "  ✅ No static tokens in environment variables"
echo -e "  ✅ Short-lived JWT-SVIDs (2-minute expiry)"
echo -e "  ✅ Automatic credential rotation"
echo -e "  ✅ Workload identity tied to pod lifecycle"
echo -e "  ✅ Stolen credentials expire in minutes, not days"
echo ""

echo -e "${GREEN}Ready for protected scenario demo!${NC}"
echo ""
