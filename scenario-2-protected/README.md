# Scenario 2: Protected Deployment (With ZTWIM + Vault)

This scenario demonstrates how ZTWIM (Zero Trust Workload Identity Manager) integrated with Vault OIDC prevents token theft and replay attacks.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ OpenShift Cluster (With ZTWIM)                                       │
│                                                                       │
│  ┌────────────────────┐         ┌──────────────────────────────┐    │
│  │ SPIRE Server       │         │ Pod: payment-service         │    │
│  │                    │         │                              │    │
│  │ Issues:            │◄────────│  SPIRE Agent (DaemonSet)     │    │
│  │ - SPIFFE IDs       │ Attest  │  └─> Attests workload        │    │
│  │ - X.509 SVIDs      │         │  └─> Issues short-lived cert │    │
│  │ - JWT-SVIDs        │         │                              │    │
│  │                    │         │  App Container               │    │
│  └────────┬───────────┘         │  └─> Gets SPIFFE ID via     │    │
│           │                     │      Workload API            │    │
│           │                     └──────────────┬───────────────┘    │
│           │ OIDC Discovery                     │                    │
│           │ /.well-known/openid-configuration  │ JWT-SVID           │
│           │                                    │ (expires in mins)  │
└───────────┼────────────────────────────────────┼────────────────────┘
            │                                    │
            │                                    │
            ▼                                    ▼
    ┌─────────────────────────────────────────────────────┐
    │  HashiCorp Vault                                    │
    │                                                     │
    │  Auth Method: JWT/OIDC                              │
    │                                                     │
    │  OIDC Discovery URL:                                │
    │  https://spire-oidc.spire.svc.cluster.local/       │
    │                                                     │
    │  Validation:                                        │
    │  ✓ Token signature (via OIDC discovery keys)       │
    │  ✓ SPIFFE ID format and claims                     │
    │  ✓ Token expiration (1-5 minutes)                  │
    │  ✓ Audience match                                  │
    │                                                     │
    │  Role Binding:                                      │
    │  spiffe://cluster.local/ns/payment-demo/           │
    │    sa/payment-service → payment-secrets-policy      │
    └─────────────────────────────────────────────────────┘
```

## How ZTWIM Prevents the Attack

### 1. Workload Attestation
SPIRE Agent verifies the workload's identity before issuing credentials:
- Pod's namespace
- Service account
- Node identity
- Container ID

**Attack Impact:** Even if an attacker compromises a pod, they can't create credentials for a different workload.

### 2. Short-Lived Credentials
JWT-SVIDs expire in minutes (default: 5 minutes), not years:
```
Token Lifetime Comparison:
- Traditional SA Token: ~10 years
- JWT-SVID:             ~5 minutes
```

**Attack Impact:** Exfiltrated credentials expire before the attacker can establish persistence.

### 3. Cryptographic Identity Binding
SPIFFE IDs are embedded in the JWT-SVID and cryptographically signed:
```json
{
  "sub": "spiffe://cluster.local/ns/payment-demo/sa/payment-service",
  "aud": ["vault"],
  "exp": 1718548920,  // Expires in 5 minutes
  "iat": 1718548620,
  "iss": "https://spire-oidc.spire.svc.cluster.local"
}
```

**Attack Impact:** Token cannot be forged or modified.

### 4. OIDC Discovery Validation
Vault validates tokens against SPIRE's OIDC discovery endpoint:
- Fetches signing keys from `/.well-known/jwks.json`
- Verifies token signature
- Validates claims (iss, aud, exp, sub)

**Attack Impact:** Replay from external infrastructure fails validation.

### 5. No Static Secrets in Pods
No long-lived tokens mounted in the pod:
```bash
# Traditional approach:
/var/run/secrets/kubernetes.io/serviceaccount/token  # ← Long-lived, stealable

# ZTWIM approach:
# Credentials obtained dynamically via Unix Domain Socket (Workload API)
# No files to steal!
```

**Attack Impact:** No static credentials to exfiltrate.

## Attack Simulation (Will Fail)

### Step 1: Deploy Protected Application

The application uses ZTWIM's Workload API to obtain SPIFFE credentials.

### Step 2: Compromise Simulation

Attacker gains code execution in the pod.

### Step 3: Attempted Token Theft

```bash
# Attacker tries to find credentials
kubectl exec -it payment-service -- find / -name "token" 2>/dev/null

# Result: No static tokens found!
# Credentials only exist in memory via Workload API
```

### Step 4: Even If Credentials Are Dumped...

Let's say the attacker dumps memory and extracts a JWT-SVID:

```bash
# Attacker attempts to use it from their infrastructure
```

**Attack Fails Because:**
1. Token expires within 5 minutes
2. Vault's OIDC validation checks signature against SPIRE's keys
3. Even if valid, token has narrow scope (can't be used for other services)

### Step 5: No Persistent Access

- Original JWT-SVID expires
- Attacker can't request new SVIDs (requires workload attestation)
- No long-term access maintained

## Demo Execution

```bash
# Deploy ZTWIM and configure Vault integration
./setup.sh

# Deploy the protected application
kubectl apply -f deploy/

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=payment-service

# Attempt the same attack (will fail)
./attack/demonstrate-theft.sh

# Observe: attack mitigation in action
```

## Expected Output

```
[ATTACK] Step 1: Compromising pod...
[ATTACK] Step 2: Searching for service account tokens...
[RESULT] No static tokens found
[ATTACK] Step 3: Attempting to extract credentials from memory...
[INFO] Even if credentials are dumped, they expire in 4m 23s
[ATTACK] Step 4: Attempting to use extracted JWT-SVID from external system...
[FAILURE] Vault authentication failed
[ERROR] Token signature validation failed
[ATTACK] Step 5: Waiting for credential refresh to steal new token...
[INFO] New SVID issued, but still bound to original workload identity
[FAILURE] Cannot authenticate as different workload
[RESULT] Attack failed - no Vault access obtained
```

## Security Benefits Summary

| Attack Vector | Traditional | With ZTWIM |
|--------------|-------------|------------|
| Token Lifetime | Years | Minutes |
| Identity Binding | None | Cryptographic |
| Replay Window | Unlimited | < 5 minutes |
| Workload Attestation | No | Yes |
| Static Secrets | Yes | No |
| External Replay | Succeeds | Fails |
| Persistence After Compromise | Yes | No |

## Configuration Highlights

### ZTWIM SPIRE Server Config
```yaml
apiVersion: spire.openshift.io/v1
kind: SPIREServer
metadata:
  name: spire-server
spec:
  # OIDC Discovery enabled for Vault integration
  oidc:
    enabled: true
    service:
      type: ClusterIP
```

### Vault JWT Auth Config
```bash
# Configure Vault to trust SPIRE as OIDC provider
vault write auth/jwt/config \
  oidc_discovery_url="https://spire-oidc.spire.svc.cluster.local" \
  oidc_discovery_ca_pem=@spire-ca.crt \
  default_role="default"

# Create role bound to SPIFFE ID
vault write auth/jwt/role/payment-service \
  role_type="jwt" \
  bound_audiences="vault" \
  bound_subject="spiffe://cluster.local/ns/payment-demo/sa/payment-service" \
  user_claim="sub" \
  policies="payment-secrets" \
  ttl=1h
```

### Application Integration
```go
// Application uses SPIFFE Workload API
import "github.com/spiffe/go-spiffe/v2/workloadapi"

// Obtain JWT-SVID
source, _ := workloadapi.NewJWTSource(ctx)
svid, _ := source.FetchJWTSVID(ctx, jwtsvid.Params{
    Audience: "vault",
})

// Use JWT-SVID to authenticate to Vault
vaultClient.SetToken(svid.Marshal())
```

## Key Takeaways

1. **Zero Static Secrets**: No long-lived tokens in pods
2. **Automatic Rotation**: Credentials refresh every 5 minutes
3. **Workload Identity**: Cryptographically bound to pod's runtime context
4. **Defense in Depth**: Multiple validation layers (attestation, signing, expiration)
5. **Reduced Blast Radius**: Compromised pod has minutes, not months, of access

## References

- [ZTWIM Vault OIDC Integration](https://developers.redhat.com/articles/2026/05/08/federated-identity-across-hybrid-cloud-using-zero-trust-workload-identity)
- [SPIFFE/SPIRE Workload API](https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/)
- [Vault JWT/OIDC Auth Method](https://www.vaultproject.io/docs/auth/jwt)
