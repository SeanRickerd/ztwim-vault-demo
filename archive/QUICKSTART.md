# ZTWIM + Vault Demo - Quick Start Guide

## Prerequisites

- OpenShift 4.20+ cluster (or Kubernetes 1.28+)
- `kubectl` or `oc` CLI configured
- Cluster admin access
- `jq`, `curl` installed locally

## 5-Minute Quick Demo

### Option 1: Automated Demo Runner

```bash
cd scripts
chmod +x *.sh
./demo-runner.sh
```

Select option 1 for full demo.

### Option 2: Manual Step-by-Step

#### Step 1: Setup Infrastructure (5 minutes)

```bash
# Setup Vault
cd scripts
chmod +x setup-vault.sh setup-ztwim.sh
./setup-vault.sh

# Setup ZTWIM
./setup-ztwim.sh
```

#### Step 2: Run Scenario 1 - Vulnerable (3 minutes)

```bash
# Deploy vulnerable app
cd ../scenario-1-vulnerable
kubectl apply -f deploy/

# Wait for ready
kubectl wait --for=condition=ready pod -l app=payment-service -n payment-demo --timeout=120s

# Run attack (succeeds)
cd attack
chmod +x demonstrate-theft.sh
./demonstrate-theft.sh
```

**Expected:** Attack succeeds, Vault access obtained ✗

#### Step 3: Run Scenario 2 - Protected (5 minutes)

```bash
# Clean up scenario 1
kubectl delete namespace payment-demo
kubectl create namespace payment-demo

# Deploy protected app
cd ../../scenario-2-protected
kubectl apply -f deploy/

# Wait for ready
kubectl wait --for=condition=ready pod -l app=payment-service -n payment-demo --timeout=120s

# Run same attack (fails)
cd attack
chmod +x demonstrate-theft.sh
./demonstrate-theft.sh
```

**Expected:** Attack fails, no Vault access ✓

## Understanding the Demo

### What's Being Demonstrated?

**Attack Scenario:** Service Account Token Theft & Replay

1. Attacker compromises a pod (simulated via `kubectl exec`)
2. Steals authentication credentials
3. Uses credentials to access Vault from external system
4. Retrieves secrets (database passwords, API keys)

### Scenario 1: Without ZTWIM

**Vulnerability:**
- Long-lived service account token at `/var/run/secrets/kubernetes.io/serviceaccount/token`
- Token valid for years
- Can be copied and used from anywhere
- No binding to pod's runtime identity

**Attack Result:** ✗ Succeeds
- Token successfully stolen
- Vault authentication works from external system
- Secrets retrieved
- Access persists even after pod deletion

### Scenario 2: With ZTWIM

**Protection:**
- No static tokens in filesystem
- Workload gets SPIFFE ID: `spiffe://cluster.local/ns/payment-demo/sa/payment-service`
- JWT-SVID credentials expire in 5 minutes
- Vault validates via OIDC against SPIRE
- Cryptographic binding to workload identity

**Attack Result:** ✓ Fails
- No static tokens to steal
- Even if JWT-SVID extracted, expires in minutes
- OIDC validation prevents external replay
- No persistent access

## Architecture Overview

### Traditional (Scenario 1)
```
Pod → Static SA Token → Vault (K8s Auth) → Secrets
  └─> Can be stolen and replayed ✗
```

### ZTWIM-Protected (Scenario 2)
```
Pod → SPIRE Agent → SPIRE Server → JWT-SVID (5min)
                         ↓
                    OIDC Discovery
                         ↓
                       Vault → Validates → Secrets
  └─> Short-lived, cryptographically bound ✓
```

## Key Components

### ZTWIM / SPIRE Components

1. **SPIRE Server** (spire namespace)
   - Issues SPIFFE identities (SVIDs)
   - Maintains registration entries
   - Provides OIDC discovery endpoint

2. **SPIRE Agent** (DaemonSet on all nodes)
   - Attests workload identity
   - Issues SVIDs to attested workloads
   - Provides Workload API via Unix socket

3. **Registration Entry** (CRD)
   - Maps workload attributes to SPIFFE ID
   - Selectors: namespace, service account
   - SPIFFE ID: `spiffe://cluster.local/ns/<ns>/sa/<sa>`

### Vault Configuration

1. **JWT Auth Method**
   - OIDC Discovery URL: SPIRE OIDC service
   - Validates JWT-SVID signatures
   - Checks claims (issuer, audience, subject, expiration)

2. **JWT Role**
   - Bound to specific SPIFFE ID
   - Maps SPIFFE ID to Vault policies
   - Controls access to secrets

## Files Overview

```
ztwim-vault-demo/
├── README.md                    # Main documentation
├── QUICKSTART.md               # This file
├── PRESENTATION.md             # Presentation guide
│
├── scenario-1-vulnerable/      # Traditional approach
│   ├── README.md               # Scenario details
│   ├── deploy/                 # Kubernetes manifests
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── deployment.yaml
│   │   └── configmap.yaml
│   └── attack/
│       └── demonstrate-theft.sh  # Attack simulation
│
├── scenario-2-protected/       # ZTWIM approach
│   ├── README.md               # Scenario details
│   ├── deploy/                 # Kubernetes manifests
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   └── deployment.yaml
│   ├── ztwim-config/           # ZTWIM configuration
│   │   ├── spire-server.yaml
│   │   ├── spire-agent.yaml
│   │   └── registration-entry.yaml
│   ├── vault-config/
│   │   └── vault-jwt-auth-config.sh
│   └── attack/
│       └── demonstrate-theft.sh  # Same attack (fails)
│
└── scripts/
    ├── setup-vault.sh          # Vault deployment
    ├── setup-ztwim.sh          # ZTWIM deployment
    └── demo-runner.sh          # Automated demo
```

## Customizing the Demo

### Change JWT-SVID Lifetime

Edit `scenario-2-protected/ztwim-config/spire-server.yaml`:
```yaml
spec:
  server:
    jwt:
      ttl: 5m  # Change to 1m, 10m, etc.
```

### Add More Workloads

Create additional registration entries:
```yaml
apiVersion: spire.openshift.io/v1
kind: RegistrationEntry
metadata:
  name: my-service-entry
spec:
  spiffeId: spiffe://cluster.local/ns/my-namespace/sa/my-service
  selectors:
    - type: k8s
      value: ns:my-namespace
    - type: k8s
      value: sa:my-service
  jwt:
    enabled: true
    audiences:
      - vault
```

### Use External Vault

Modify `VAULT_ADDR` in deployment manifests:
```yaml
env:
- name: VAULT_ADDR
  value: "https://vault.example.com:8200"
```

## Troubleshooting

### Issue: SPIRE Pods Not Running

**Check operator logs:**
```bash
kubectl logs -n openshift-operators -l name=openshift-spire-operator
```

**Check SPIRE Server:**
```bash
kubectl get pods -n spire
kubectl logs -n spire -l app=spire-server
```

### Issue: Workload Not Getting SPIFFE ID

**Verify registration entry:**
```bash
kubectl get registrationentry -n spire
kubectl describe registrationentry payment-service-entry -n spire
```

**Check selectors match:**
```bash
kubectl get pod -n payment-demo -l app=payment-service -o yaml | grep -A10 "labels:"
```

### Issue: Vault OIDC Discovery Failing

**Test OIDC endpoint:**
```bash
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -k https://spire-oidc.spire.svc.cluster.local/.well-known/openid-configuration
```

**Check Vault JWT config:**
```bash
kubectl exec -n vault deployment/vault -- vault read auth/jwt/config
```

### Issue: JWT-SVID Authentication Failing

**Check Vault role:**
```bash
kubectl exec -n vault deployment/vault -- \
  vault read auth/jwt/role/payment-service
```

**Verify SPIFFE ID matches:**
Should be: `spiffe://cluster.local/ns/payment-demo/sa/payment-service`

### Issue: Demo Script Fails

**Make scripts executable:**
```bash
find . -name "*.sh" -exec chmod +x {} \;
```

**Check prerequisites:**
```bash
which kubectl jq curl
```

## Cleanup

### Remove Demo Resources

```bash
kubectl delete namespace payment-demo
kubectl delete namespace spire
kubectl delete namespace vault
```

### Remove ZTWIM Operator (OpenShift)

```bash
kubectl delete subscription openshift-spire-operator -n openshift-operators
kubectl delete csv -n openshift-operators -l operators.coreos.com/openshift-spire-operator.openshift-operators
```

## Next Steps

1. **Read Full Documentation**
   - See `README.md` for detailed architecture
   - Review `PRESENTATION.md` for demo talking points

2. **Explore ZTWIM Features**
   - Multi-cluster federation
   - X.509-SVID for mTLS
   - Integration with service mesh

3. **Integrate with Your Applications**
   - Use SPIFFE SDK (go-spiffe, java-spiffe, py-spiffe)
   - Replace static secrets with Workload API calls
   - Update CI/CD for secretless deployments

## Resources

- [ZTWIM Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/zero-trust-workload-identity-manager)
- [SPIFFE/SPIRE Project](https://spiffe.io)
- [Vault JWT Auth](https://www.vaultproject.io/docs/auth/jwt)
- [Red Hat Developer Articles](https://developers.redhat.com/search?q=ztwim)

## Support

For issues with:
- **This demo:** Check troubleshooting section above
- **ZTWIM/SPIRE:** [GitHub Issues](https://github.com/openshift/zero-trust-workload-identity-manager/issues)
- **Vault:** [HashiCorp Support](https://support.hashicorp.com)
