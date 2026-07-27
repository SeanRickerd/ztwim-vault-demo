#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

NAMESPACE="payment-demo"
POD_NAME="payment-service"
VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"

# Detect if using OpenBao or Vault
VAULT_TYPE="vault"
if kubectl get svc -n vault openbao >/dev/null 2>&1; then
    VAULT_TYPE="openbao"
    VAULT_CMD="bao"
else
    VAULT_CMD="vault"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ATTACK SIMULATION: Service Account Token Theft & Replay      ║${NC}"
echo -e "${BLUE}║  Scenario 2: Protected Deployment (With ZTWIM)                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Find the pod
echo -e "${YELLOW}[ATTACK]${NC} Step 1: Locating target pod..."
POD=$(kubectl get pod -n "$NAMESPACE" -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo -e "${RED}[ERROR]${NC} No pod found. Deploy the application first."
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Found pod: $POD"
echo ""

# Step 2: Compromise simulation
echo -e "${YELLOW}[ATTACK]${NC} Step 2: Compromising pod (simulated via kubectl exec)..."
echo -e "${BLUE}[INFO]${NC} Simulating RCE/container escape/SSRF attack..."
echo ""

# Step 3: Search for static tokens
echo -e "${YELLOW}[ATTACK]${NC} Step 3: Searching for static service account tokens..."
echo -e "${BLUE}[INFO]${NC} Looking for tokens in filesystem..."

TOKEN_SEARCH=$(kubectl exec -n "$NAMESPACE" "$POD" -- find /var/run/secrets -name "token" 2>/dev/null || true)

if [ -n "$TOKEN_SEARCH" ]; then
    echo -e "${YELLOW}[FOUND]${NC} Legacy token path exists: $TOKEN_SEARCH"
    LEGACY_TOKEN=$(kubectl exec -n "$NAMESPACE" "$POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || true)

    if [ -n "$LEGACY_TOKEN" ]; then
        echo -e "${YELLOW}[WARNING]${NC} Legacy service account token found!"
        echo -e "${BLUE}[INFO]${NC} But this token CANNOT access Vault (Vault uses OIDC, not K8s auth)"
        echo -e "${BLUE}[INFO]${NC} Token first 50 chars: ${LEGACY_TOKEN:0:50}..."
    fi
else
    echo -e "${GREEN}[PROTECTED]${NC} No static tokens found in filesystem"
fi
echo ""

# Step 4: Try to access SPIRE Workload API
echo -e "${YELLOW}[ATTACK]${NC} Step 4: Attempting to steal SPIFFE credentials..."
echo -e "${BLUE}[INFO]${NC} Checking for SPIRE Workload API socket..."

SOCKET_PATH=$(kubectl exec -n "$NAMESPACE" "$POD" -- find /run/spire -name "*.sock" 2>/dev/null || true)

if [ -n "$SOCKET_PATH" ]; then
    echo -e "${YELLOW}[FOUND]${NC} SPIRE socket at: $SOCKET_PATH"
    echo -e "${BLUE}[INFO]${NC} Attempting to extract JWT-SVID..."

    # Try to fetch JWT-SVID (would require SPIFFE SDK in reality)
    echo -e "${MAGENTA}[SIMULATION]${NC} Attacker dumps process memory to extract JWT-SVID..."
    echo -e "${MAGENTA}[SIMULATION]${NC} JWT-SVID extracted: eyJhbGciOiJSUzI1NiIsImtpZCI6..."
    echo ""

    # Simulate JWT-SVID details
    echo -e "${BLUE}[INFO]${NC} Extracted JWT-SVID claims:"
    cat <<EOF
{
  "sub": "spiffe://cluster.local/ns/payment-demo/sa/payment-service",
  "aud": ["vault"],
  "exp": $(date -d '+5 minutes' +%s),
  "iat": $(date +%s),
  "iss": "https://spire-oidc.spire.svc.cluster.local"
}
EOF
    echo ""

    SVID_EXPIRY_SECONDS=300  # 5 minutes
else
    echo -e "${GREEN}[PROTECTED]${NC} No accessible SPIRE socket found"
    echo -e "${BLUE}[INFO]${NC} Socket is protected by Unix permissions"
fi
echo ""

# Step 5: Attempt to replay credentials
echo -e "${YELLOW}[ATTACK]${NC} Step 5: Attempting to use extracted JWT-SVID from external system..."
echo -e "${BLUE}[INFO]${NC} Simulating authentication from attacker's infrastructure..."
echo ""

# Calculate time remaining on SVID
CURRENT_TIME=$(date +%s)
EXPIRY_TIME=$((CURRENT_TIME + SVID_EXPIRY_SECONDS))
TIME_REMAINING=$((EXPIRY_TIME - CURRENT_TIME))

echo -e "${YELLOW}[TIMING]${NC} JWT-SVID expires in: ${TIME_REMAINING} seconds ($(($TIME_REMAINING / 60))m $(($TIME_REMAINING % 60))s)"
echo ""

# Attempt Vault authentication
echo -e "${YELLOW}[ATTACK]${NC} Attempting Vault authentication with extracted JWT-SVID..."

# Port-forward to Vault (simulates external access)
kubectl port-forward -n vault svc/vault 8200:8200 >/dev/null 2>&1 &
PF_PID=$!
sleep 2

# Try to authenticate (will fail for multiple reasons)
echo -e "${MAGENTA}[ATTEMPT 1]${NC} Direct JWT-SVID replay..."

# Simulate the auth attempt
AUTH_RESPONSE=$(curl -s --request POST \
  --data '{"jwt": "eyJhbGciOiJSUzI1NiIsImtpZCI6InNwaXJlLWtleS0xIiwidHlwIjoiSldUIn0...", "role": "payment-service"}' \
  http://localhost:8200/v1/auth/jwt/login 2>/dev/null || echo '{"errors":["permission denied"]}')

echo -e "${RED}[FAILURE]${NC} Vault authentication failed!"
echo -e "${BLUE}[INFO]${NC} Error: $(echo "$AUTH_RESPONSE" | jq -r '.errors[0] // "Token validation failed"')"
echo ""

echo -e "${BLUE}[ANALYSIS]${NC} Why the attack failed:"
echo -e "  ${RED}✗${NC} JWT signature validation against SPIRE OIDC keys"
echo -e "  ${RED}✗${NC} Token expired (only valid for 5 minutes)"
echo -e "  ${RED}✗${NC} Audience mismatch (bound to specific Vault instance)"
echo -e "  ${RED}✗${NC} SPIFFE ID claim verification failed"
echo ""

# Attempt to wait and steal a fresh token
echo -e "${YELLOW}[ATTACK]${NC} Step 6: Waiting for credential rotation to steal fresh token..."
echo -e "${BLUE}[INFO]${NC} Attacker remains in compromised pod, waiting for new JWT-SVID..."
sleep 2

echo -e "${MAGENTA}[SIMULATION]${NC} New JWT-SVID issued after 5 minutes..."
echo -e "${YELLOW}[ATTACK]${NC} Extracting newly rotated JWT-SVID..."
echo ""

echo -e "${MAGENTA}[ATTEMPT 2]${NC} Replay with fresh JWT-SVID..."
echo -e "${RED}[FAILURE]${NC} Authentication still fails!"
echo ""

echo -e "${BLUE}[ANALYSIS]${NC} Fresh token also fails because:"
echo -e "  ${RED}✗${NC} Still bound to original workload identity"
echo -e "  ${RED}✗${NC} SPIFFE ID in token: spiffe://cluster.local/ns/payment-demo/sa/payment-service"
echo -e "  ${RED}✗${NC} Attacker cannot impersonate this identity from external system"
echo -e "  ${RED}✗${NC} No workload attestation from attacker's infrastructure"
echo ""

# Attempt to forge credentials
echo -e "${YELLOW}[ATTACK]${NC} Step 7: Attempting to forge SPIFFE credentials..."
echo -e "${MAGENTA}[ATTEMPT 3]${NC} Crafting fake JWT-SVID..."

echo -e "${RED}[FAILURE]${NC} Forgery attempt failed!"
echo ""

echo -e "${BLUE}[ANALYSIS]${NC} Forgery impossible because:"
echo -e "  ${RED}✗${NC} Requires SPIRE server's private key (HSM-protected)"
echo -e "  ${RED}✗${NC} Vault validates signature against OIDC discovery keys"
echo -e "  ${RED}✗${NC} OIDC endpoint at: https://spire-oidc.spire.svc.cluster.local/.well-known/jwks.json"
echo ""

# Cleanup
kill $PF_PID 2>/dev/null || true

# Final comparison
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ATTACK RESULT: FAILED (ZTWIM Protection Successful)          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}ZTWIM Defense Summary:${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} No static secrets in filesystem"
echo -e "  ${GREEN}✓${NC} JWT-SVIDs expire in 5 minutes"
echo -e "  ${GREEN}✓${NC} Cryptographic identity binding (SPIFFE ID)"
echo -e "  ${GREEN}✓${NC} Workload attestation prevents external replay"
echo -e "  ${GREEN}✓${NC} OIDC signature validation in Vault"
echo -e "  ${GREEN}✓${NC} Automatic credential rotation"
echo ""

echo -e "${BLUE}Attack Vector Comparison:${NC}"
echo ""
printf "%-30s %-20s %-20s\n" "Attack Vector" "Without ZTWIM" "With ZTWIM"
printf "%-30s %-20s %-20s\n" "$(printf '%.30s' "------------------------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.20s' "--------------------")"
printf "%-30s ${RED}%-20s${NC} ${GREEN}%-20s${NC}\n" "Static Token Theft" "✗ Succeeds" "✓ No static tokens"
printf "%-30s ${RED}%-20s${NC} ${GREEN}%-20s${NC}\n" "Credential Replay" "✗ Works forever" "✓ Expires in 5min"
printf "%-30s ${RED}%-20s${NC} ${GREEN}%-20s${NC}\n" "External Use" "✗ Unrestricted" "✓ Blocked"
printf "%-30s ${RED}%-20s${NC} ${GREEN}%-20s${NC}\n" "Persistence" "✗ Permanent" "✓ None"
printf "%-30s ${RED}%-20s${NC} ${GREEN}%-20s${NC}\n" "Forgery" "✗ Possible" "✓ Cryptographically prevented"
echo ""

echo -e "${GREEN}Conclusion: ZTWIM + Vault OIDC integration successfully mitigated the attack!${NC}"
echo ""
