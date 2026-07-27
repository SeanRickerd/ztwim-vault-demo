# ZTWIM + Vault Architecture Diagrams

## Attack Flow Comparison

### Scenario 1: Vulnerable (Traditional Kubernetes Auth)

```
┌─────────────────────────────────────────────────────────────────┐
│  OpenShift Cluster (No ZTWIM)                                   │
│                                                                  │
│  ┌────────────────────────────────────────┐                     │
│  │  Pod: payment-service                  │                     │
│  │  ┌──────────────────────────────────┐  │                     │
│  │  │  Container                       │  │                     │
│  │  │                                  │  │                     │
│  │  │  /var/run/secrets/              │  │                     │
│  │  │   kubernetes.io/                 │  │                     │
│  │  │   serviceaccount/                │  │                     │
│  │  │   token ◄─────────────────────┐  │  │                     │
│  │  │                               │  │  │                     │
│  │  │  (Static JWT, ~10 years)     │  │  │                     │
│  │  └──────────────────────────────────┘  │                     │
│  └────────────────────────────────────────┘                     │
│                          │                                       │
│                          │ ❶ Attacker reads token               │
│                          ▼                                       │
│                   ┌──────────────┐                              │
│                   │  Exfiltrate  │                              │
│                   │   to attacker│                              │
│                   │  infrastructure                             │
│                   └──────┬───────┘                              │
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           │ ❷ Replay stolen token
                           ▼
                  ┌────────────────────┐
                  │  HashiCorp Vault   │
                  │                    │
                  │  Auth: Kubernetes  │
                  │                    │
                  │  ✗ Accepts token   │
                  │  ✗ Issues secrets  │
                  └────────────────────┘

Result: ✗ ATTACK SUCCEEDS
- Token stolen in seconds
- Replayed from anywhere
- Access persists for years
```

---

### Scenario 2: Protected (ZTWIM + Vault OIDC)

```
┌──────────────────────────────────────────────────────────────────────┐
│  OpenShift Cluster (With ZTWIM)                                      │
│                                                                       │
│  ┌──────────────────────┐        ┌───────────────────────────────┐  │
│  │  SPIRE Server        │        │  Pod: payment-service         │  │
│  │  (spire namespace)   │        │                               │  │
│  │                      │        │  ┌─────────────────────────┐  │  │
│  │  • Issues SPIFFE IDs │◄───────┼──┤ SPIRE Agent             │  │  │
│  │  • Signs JWT-SVIDs   │ Attest │  │ (DaemonSet)             │  │  │
│  │  • OIDC Discovery    │        │  │                         │  │  │
│  │                      │        │  │ ❶ Attests workload:     │  │  │
│  └──────┬───────────────┘        │  │   - Namespace           │  │  │
│         │                        │  │   - Service Account     │  │  │
│         │ ❸ OIDC Discovery       │  │   - Node                │  │  │
│         │   Keys & Metadata      │  │   - Container           │  │  │
│         │                        │  └─────────┬───────────────┘  │  │
│         │                        │            │                  │  │
│         │                        │            │ ❷ Issues         │  │
│         │                        │            │   JWT-SVID        │  │
│         │                        │            │   (5 minutes)     │  │
│         │                        │            ▼                  │  │
│         │                        │  ┌─────────────────────────┐  │  │
│         │                        │  │  App Container          │  │  │
│         │                        │  │                         │  │  │
│         │                        │  │  No static tokens! ✓    │  │  │
│         │                        │  │                         │  │  │
│         │                        │  │  Workload API           │  │  │
│         │                        │  │  (Unix socket)          │  │  │
│         │                        │  └─────────────────────────┘  │  │
│         │                        └──────────────┬────────────────┘  │
│         │                                       │                   │
│         │                                       │ JWT-SVID          │
│         │                                       │ (short-lived)     │
└─────────┼───────────────────────────────────────┼───────────────────┘
          │                                       │
          │                                       ▼
          │                          ┌────────────────────────────┐
          │                          │  HashiCorp Vault           │
          │                          │                            │
          │                          │  Auth: JWT/OIDC            │
          └──────────────────────────┤                            │
            ❸ Validate signature     │  ❹ Validation:             │
               against OIDC keys     │  ✓ Signature (OIDC)        │
                                     │  ✓ Issuer                  │
                                     │  ✓ Audience                │
                                     │  ✓ Subject (SPIFFE ID)     │
                                     │  ✓ Expiration (<5min)      │
                                     │                            │
                                     │  ✓ Issues secrets          │
                                     └────────────────────────────┘

Result: ✓ ATTACK PREVENTED
- No static tokens to steal
- JWT-SVID expires in 5 minutes
- OIDC validation blocks replay
- Cryptographically bound identity
```

---

## Component Architecture

### SPIRE Components

```
┌─────────────────────────────────────────────────────────────────┐
│  SPIRE Server (Control Plane)                                   │
│                                                                  │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │  Registration  │  │  CA Server   │  │  OIDC Discovery  │    │
│  │  API           │  │              │  │  Provider        │    │
│  │                │  │  Signs       │  │                  │    │
│  │  Stores        │  │  SVIDs       │  │  /.well-known/   │    │
│  │  workload      │  │              │  │  openid-config   │    │
│  │  entries       │  │              │  │                  │    │
│  └────────────────┘  └──────────────┘  └──────────────────┘    │
│                                                                  │
└───────────────────────────┬──────────────────────────────────────┘
                            │ Node Attestation
                            │ Agent Federation
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  SPIRE Agent (Data Plane - DaemonSet)                           │
│                                                                  │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  Node Attestor  │  │  Workload        │  │  Workload API  │ │
│  │                 │  │  Attestor        │  │                │ │
│  │  Proves agent's │  │                  │  │  Unix socket:  │ │
│  │  identity to    │  │  Verifies:       │  │  /run/spire/   │ │
│  │  SPIRE Server   │  │  - Namespace     │  │  sockets/      │ │
│  │                 │  │  - SA            │  │  agent.sock    │ │
│  │  (k8s PSAT)     │  │  - Node          │  │                │ │
│  │                 │  │  - Container     │  │  Issues SVIDs  │ │
│  └─────────────────┘  └──────────────────┘  └────────────────┘ │
│                                                     ▲            │
└─────────────────────────────────────────────────────┼────────────┘
                                                      │
                                           Workload requests SVID
                                                      │
                                              ┌───────┴──────┐
                                              │  Application │
                                              │  Container   │
                                              └──────────────┘
```

---

## SPIFFE ID Structure

```
spiffe://cluster.local/ns/payment-demo/sa/payment-service
└─┬──┘  └─────┬──────┘ └┬┘ └────┬──────┘ └┬┘ └──────┬────────┘
  │           │         │       │         │         │
  │           │         │       │         │         └─ Service Account Name
  │           │         │       │         └─────────── Selector Type
  │           │         │       └───────────────────── Namespace Name
  │           │         └───────────────────────────── Selector Type
  │           └─────────────────────────────────────── Trust Domain
  └─────────────────────────────────────────────────── SPIFFE Scheme
```

### Example SPIFFE IDs:

```
spiffe://cluster.local/ns/payment-demo/sa/payment-service
spiffe://cluster.local/ns/payment-demo/sa/database-service
spiffe://cluster.local/ns/prod/sa/api-gateway
spiffe://cluster.local/ns/prod/sa/frontend
```

---

## JWT-SVID Structure

```json
{
  "header": {
    "alg": "RS256",
    "kid": "spire-key-1",
    "typ": "JWT"
  },
  "payload": {
    "sub": "spiffe://cluster.local/ns/payment-demo/sa/payment-service",
    "aud": ["vault", "vault.vault.svc.cluster.local"],
    "exp": 1718548920,  // Expires in 5 minutes
    "iat": 1718548620,
    "iss": "https://spire-oidc.spire.svc.cluster.local",
    "jti": "unique-jwt-id-12345"
  },
  "signature": "<RSA signature using SPIRE's private key>"
}
```

**Key Properties:**
- `sub` (Subject): SPIFFE ID of the workload
- `aud` (Audience): Who can use this token (Vault)
- `exp` (Expiration): 5 minutes from issuance
- `iss` (Issuer): SPIRE OIDC Discovery URL
- Signature: Cryptographically signed by SPIRE

---

## Vault OIDC Validation Flow

```
┌────────────────────────────────────────────────────────────────┐
│  Application sends JWT-SVID to Vault                           │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Vault JWT Auth Handler                                        │
│                                                                 │
│  ❶ Parse JWT-SVID                                              │
│     └─> Extract header, payload, signature                     │
│                                                                 │
│  ❷ Fetch OIDC Discovery Metadata                               │
│     └─> GET https://spire-oidc/.well-known/openid-configuration│
│     └─> Returns: issuer, jwks_uri, supported algorithms        │
│                                                                 │
│  ❸ Fetch Signing Keys                                          │
│     └─> GET https://spire-oidc/.well-known/jwks.json           │
│     └─> Returns: Public keys for signature verification        │
│                                                                 │
│  ❹ Verify Signature                                            │
│     └─> Validate JWT signature against fetched public key      │
│     └─> Algorithm: RS256                                       │
│                                                                 │
│  ❺ Validate Claims                                             │
│     ✓ Issuer matches configured value                          │
│     ✓ Audience includes "vault"                                │
│     ✓ Subject matches expected SPIFFE ID pattern               │
│     ✓ Token not expired (exp > now)                            │
│     ✓ Issued-at time is sane (not future)                      │
│                                                                 │
│  ❻ Map to Vault Policy                                         │
│     └─> Role: payment-service                                  │
│     └─> bound_subject: spiffe://.../sa/payment-service         │
│     └─> Policy: payment-secrets                                │
│                                                                 │
│  ❼ Issue Vault Token                                           │
│     └─> TTL: 1 hour                                            │
│     └─> Policies: payment-secrets                              │
│                                                                 │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │  Application     │
                  │  receives Vault  │
                  │  access token    │
                  └──────────────────┘
```

---

## Registration Entry Flow

```
┌────────────────────────────────────────────────────────────────┐
│  Administrator creates RegistrationEntry CRD                    │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  apiVersion: spire.openshift.io/v1                              │
│  kind: RegistrationEntry                                        │
│  metadata:                                                      │
│    name: payment-service-entry                                 │
│  spec:                                                          │
│    spiffeId: spiffe://cluster.local/ns/payment-demo/           │
│               sa/payment-service                                │
│    selectors:                                                   │
│      - type: k8s                                                │
│        value: ns:payment-demo                                   │
│      - type: k8s                                                │
│        value: sa:payment-service                                │
│    jwt:                                                         │
│      enabled: true                                              │
│      audiences: ["vault"]                                       │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  SPIRE Operator processes CRD                                   │
│  └─> Translates to SPIRE Server registration entry             │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  SPIRE Server stores registration entry                         │
│  └─> Indexed by selectors                                      │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  When pod starts:                                               │
│                                                                 │
│  ❶ SPIRE Agent detects new workload                            │
│  ❷ Collects workload selectors:                                │
│     └─> Namespace: payment-demo                                │
│     └─> Service Account: payment-service                       │
│     └─> Node: worker-1                                         │
│     └─> Container ID: abc123                                   │
│  ❸ Queries SPIRE Server for matching registration entry        │
│  ❹ Server returns: spiffe://cluster.local/ns/payment-demo/     │
│                     sa/payment-service                          │
│  ❺ Agent issues SVID to workload via Workload API              │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

---

## Network Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Application Pod                                                │
│                                                                  │
│  ┌────────────────┐                                             │
│  │  App Container │                                             │
│  │                │                                             │
│  │  1. Request    │─────┐                                       │
│  │     JWT-SVID   │     │ Unix Domain Socket                    │
│  │                │◄────┘ /run/spire/sockets/agent.sock         │
│  └────────────────┘                                             │
│          │                                                       │
│          │ 2. JWT-SVID returned                                 │
│          ▼                                                       │
│  ┌────────────────┐                                             │
│  │  App uses      │                                             │
│  │  JWT-SVID      │─────────────────────┐                       │
│  └────────────────┘                     │                       │
└─────────────────────────────────────────┼───────────────────────┘
                                          │
                                          │ HTTPS POST
                                          │ /v1/auth/jwt/login
                                          │ {"jwt": "...", "role": "payment-service"}
                                          ▼
                                ┌──────────────────────┐
                                │  Vault Service       │
                                │  (vault.vault.svc)   │
                                │                      │
                                │  Port: 8200          │
                                └──────────┬───────────┘
                                           │
                                           │ 3. Fetch OIDC keys
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  SPIRE OIDC Discovery Service                                   │
│  (spire-oidc.spire.svc)                                         │
│                                                                  │
│  Endpoints:                                                     │
│  • /.well-known/openid-configuration                            │
│  • /.well-known/jwks.json                                       │
│  • /keys                                                        │
│                                                                  │
│  Returns:                                                       │
│  • Public keys for signature verification                       │
│  • Issuer URL                                                   │
│  • Supported algorithms (RS256)                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Security Layers

```
Layer 5: OIDC Validation
┌─────────────────────────────────────────────────────────────────┐
│  Vault verifies JWT signature against SPIRE OIDC keys          │
│  ✓ Cryptographic proof of authenticity                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
Layer 4: Workload Attestation
┌─────────────────────────────────────────────────────────────────┐
│  SPIRE Agent attests workload before issuing SVID              │
│  ✓ Namespace, Service Account, Node, Container verified        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
Layer 3: Cryptographic Identity
┌─────────────────────────────────────────────────────────────────┐
│  SPIFFE ID cryptographically bound in signed JWT-SVID          │
│  ✓ Cannot be forged without SPIRE's private key                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
Layer 2: Short-Lived Credentials
┌─────────────────────────────────────────────────────────────────┐
│  JWT-SVID expires in 5 minutes                                  │
│  ✓ Limits blast radius to minutes, not years                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
Layer 1: No Static Secrets
┌─────────────────────────────────────────────────────────────────┐
│  No tokens stored in filesystem                                 │
│  ✓ Nothing for attacker to steal via file read                 │
└─────────────────────────────────────────────────────────────────┘
```

**Defense in Depth:** Even if one layer is compromised, others still protect

---

## Credential Lifecycle

```
Time 0:00 - Pod Starts
    │
    ├─> SPIRE Agent detects new workload
    ├─> Attests workload identity
    └─> Issues first JWT-SVID (expires T+5:00)
    
Time 0:30 - Application requests Vault access
    │
    ├─> Fetches JWT-SVID from Workload API
    ├─> Sends to Vault
    ├─> Vault validates via OIDC
    └─> Vault issues access token (expires T+1:00:30)

Time 4:30 - Background rotation begins
    │
    └─> SPIFFE SDK fetches new JWT-SVID (expires T+9:30)
    
Time 5:00 - First JWT-SVID expires
    │
    └─> But new one already in use (seamless rotation)

Time 60:00 - Vault token expires
    │
    ├─> Application fetches current JWT-SVID
    ├─> Re-authenticates to Vault
    └─> Receives new Vault token

Continuous:
    └─> JWT-SVIDs rotate every ~5 minutes
        Vault tokens refresh as needed
        No manual intervention required
```

---

## Attack vs Defense Timeline

### Traditional (Vulnerable)

```
T+0:00   ┌─────────────────────┐
         │ Pod starts          │
         │ Token mounted       │
         └──────────┬──────────┘
                    │
T+0:30   ┌──────────▼──────────┐
         │ ✗ Attacker          │
         │   compromises pod   │
         └──────────┬──────────┘
                    │
T+1:00   ┌──────────▼──────────┐
         │ ✗ Token stolen      │
         │   (file read)       │
         └──────────┬──────────┘
                    │
T+2:00   ┌──────────▼──────────┐
         │ ✗ Exfiltrated       │
         └──────────┬──────────┘
                    │
T+3:00   ┌──────────▼──────────┐
         │ ✗ Vault access      │
         │   obtained          │
         └──────────┬──────────┘
                    │
         │  Years later...      │
         │                      │
T+1yr    ┌──────────▼──────────┐
         │ ✗ Still has access! │
         └─────────────────────┘
```

### ZTWIM (Protected)

```
T+0:00   ┌─────────────────────┐
         │ Pod starts          │
         │ SPIRE attests       │
         │ JWT-SVID issued     │
         └──────────┬──────────┘
                    │
T+0:30   ┌──────────▼──────────┐
         │ ✗ Attacker          │
         │   compromises pod   │
         └──────────┬──────────┘
                    │
T+1:00   ┌──────────▼──────────┐
         │ ✓ No static tokens  │
         │   to steal          │
         └──────────┬──────────┘
                    │
T+2:00   ┌──────────▼──────────┐
         │ ✓ Even if JWT-SVID  │
         │   extracted...      │
         └──────────┬──────────┘
                    │
T+3:00   ┌──────────▼──────────┐
         │ ✓ Vault rejects     │
         │   (OIDC validation) │
         └──────────┬──────────┘
                    │
T+5:00   ┌──────────▼──────────┐
         │ ✓ JWT-SVID expires  │
         │   Completely useless│
         └──────────┬──────────┘
                    │
T+1d     ┌──────────▼──────────┐
         │ ✓ No access         │
         │   Attack failed     │
         └─────────────────────┘
```

---

## Deployment Topology

```
┌─────────────────────────────────────────────────────────────────┐
│  OpenShift Cluster                                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: spire                                         │  │
│  │                                                           │  │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐  │  │
│  │  │ SPIRE Server     │  │ SPIRE Agent (DaemonSet)      │  │  │
│  │  │ (StatefulSet)    │  │ Runs on every node           │  │  │
│  │  │                  │  │                              │  │  │
│  │  │ • CA Server      │  │ Node 1: spire-agent-abc      │  │  │
│  │  │ • Registration   │  │ Node 2: spire-agent-def      │  │  │
│  │  │ • OIDC Provider  │  │ Node 3: spire-agent-ghi      │  │  │
│  │  └──────────────────┘  └──────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: vault                                         │  │
│  │                                                           │  │
│  │  ┌──────────────────┐                                    │  │
│  │  │ Vault Server     │                                    │  │
│  │  │ (Deployment)     │                                    │  │
│  │  │                  │                                    │  │
│  │  │ • JWT Auth       │                                    │  │
│  │  │ • KV Secrets     │                                    │  │
│  │  └──────────────────┘                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: payment-demo                                  │  │
│  │                                                           │  │
│  │  ┌──────────────────┐                                    │  │
│  │  │ payment-service  │                                    │  │
│  │  │ (Deployment)     │                                    │  │
│  │  │                  │                                    │  │
│  │  │ Gets SPIFFE ID:  │                                    │  │
│  │  │ spiffe://...     │                                    │  │
│  │  │ /sa/payment-svc  │                                    │  │
│  │  └──────────────────┘                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

This architecture demonstrates defense-in-depth through:
- Cryptographic identity (SPIFFE)
- Workload attestation (SPIRE)
- Short-lived credentials (5 minutes)
- OIDC validation (Vault)
- No static secrets

**Result: Complete mitigation of credential theft attacks**
