# Scenario 1: Vulnerable Deployment (Without ZTWIM)

This scenario demonstrates traditional Kubernetes service account token authentication to Vault.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ OpenShift Cluster (Without ZTWIM)                           │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │ Pod: payment-service                 │                   │
│  │                                      │                   │
│  │  App Container                       │                   │
│  │  └─> Reads: /var/run/secrets/.../   │                   │
│  │      token (long-lived JWT)          │──────┐            │
│  │                                      │      │            │
│  └──────────────────────────────────────┘      │            │
│                                                 │            │
└─────────────────────────────────────────────────┼────────────┘
                                                  │
                                                  │ JWT Token
                                                  │ (static, never expires)
                                                  │
                                                  ▼
                                        ┌─────────────────────┐
                                        │  HashiCorp Vault    │
                                        │                     │
                                        │  Auth Method:       │
                                        │  - kubernetes       │
                                        │                     │
                                        │  Validates against: │
                                        │  - K8s API server   │
                                        │  - Service Account  │
                                        └─────────────────────┘
```

## Vulnerability

The service account token:
- Is a long-lived JWT (can last years)
- Lives at a predictable path in every pod
- Can be copied and used from anywhere
- Has no binding to the pod's runtime identity

## Attack Simulation

### Step 1: Deploy Vulnerable Application

The application authenticates to Vault using traditional Kubernetes auth method.

### Step 2: Compromise Simulation

An attacker gains code execution in the pod (simulated via `kubectl exec`).

### Step 3: Token Theft

```bash
# Attacker reads the service account token
kubectl exec -it payment-service -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Step 4: Token Exfiltration & Replay

The attacker:
1. Copies the token to their machine
2. Uses it to authenticate to Vault from their infrastructure
3. Retrieves secrets (database passwords, API keys, etc.)
4. Maintains access indefinitely (token never expires)

### Step 5: Persistent Access

Even after the original pod is deleted:
- Token remains valid
- Attacker retains Vault access
- Secrets can be continuously accessed

## Demo Execution

```bash
# Deploy the vulnerable application
kubectl apply -f deploy/

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=payment-service

# Simulate the attack
./attack/demonstrate-theft.sh

# Observe: successful Vault authentication and secret retrieval
```

## Expected Output

```
[ATTACK] Step 1: Compromising pod...
[ATTACK] Step 2: Stealing service account token...
[ATTACK] Token acquired: eyJhbGciOiJSUzI1NiIsImtpZCI6...
[ATTACK] Step 3: Exfiltrating token to attacker machine...
[ATTACK] Step 4: Authenticating to Vault from external system...
[SUCCESS] Vault authentication successful!
[SUCCESS] Token: s.aBcDeFgHiJkLmNoPqRsTuVwXyZ
[ATTACK] Step 5: Retrieving secrets...
[SUCCESS] Database password: super-secret-password-123
[ATTACK] Step 6: Verifying persistent access (even after pod deletion)...
[SUCCESS] Still authenticated to Vault!
[RESULT] Attack succeeded - full Vault access obtained and persisted
```

## Why This Attack Works

1. **Static Credentials**: Service account token doesn't change
2. **No Identity Binding**: Token isn't tied to pod's runtime context
3. **Unlimited Replay Window**: Token valid indefinitely
4. **No Workload Attestation**: Vault can't verify WHERE the token is coming from

## Remediation

See `scenario-2-protected/` for how ZTWIM + Vault OIDC integration prevents this attack.
