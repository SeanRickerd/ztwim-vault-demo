# ZTWIM 1.1 + Vault Integration - Adversarial Demo

[![OpenShift](https://img.shields.io/badge/OpenShift-4.20%2B-red)](https://www.openshift.com/)
[![SPIFFE](https://img.shields.io/badge/SPIFFE-compliant-blue)](https://spiffe.io/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

This demo showcases how Zero Trust Workload Identity Manager (ZTWIM) 1.1 integrated with HashiCorp Vault through OIDC federation **completely prevents** service account token theft and replay attacks.

## 🎯 What You'll Learn

- Why traditional Kubernetes service account tokens are vulnerable
- How attackers steal and replay credentials to access secrets
- How ZTWIM's cryptographic workload identity prevents these attacks
- The security benefits of SPIFFE-based authentication with Vault

## ⚡ Quick Start

```bash
# Clone the demo
git clone <this-repo>
cd ztwim-vault-demo

# Deploy secrets manager (OpenBao or Vault)
cd scripts
./setup-secrets-manager.sh

# Run automated demo (recommended)
./demo-runner.sh

# Or follow the manual quick start guide
See QUICKSTART.md for step-by-step instructions
```

### Secrets Manager Options

This demo supports **OpenBao** (recommended) or **HashiCorp Vault**:
- **OpenBao**: 100% Vault-compatible, true open-source, community-governed
- **Vault**: Industry standard, enterprise features available

See [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) for detailed comparison.

## 📋 Documentation Index

- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute setup and execution guide
- **[DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md)** - OpenBao vs Vault comparison and setup
- **[PRESENTATION.md](PRESENTATION.md)** - Complete presentation guide with talking points
- **[COMPARISON.md](COMPARISON.md)** - Security comparison tables and metrics
- **[DEMO_CHECKLIST.md](DEMO_CHECKLIST.md)** - Pre-flight checklist for live demos
- **[SUMMARY.md](SUMMARY.md)** - Executive summary and business case
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Visual diagrams and architecture flows

## 🎭 Attack Scenario: Service Account Token Theft & Replay

### The Vulnerability (Without ZTWIM)

In traditional OpenShift deployments, applications authenticate to Vault using:
- Static Kubernetes service account tokens mounted as secrets
- Long-lived tokens that don't expire
- Tokens that can be exfiltrated and replayed from anywhere

**Attack Flow:**
1. Attacker compromises a pod (e.g., via RCE, SSRF, or container breakout)
2. Reads the service account token from `/var/run/secrets/kubernetes.io/serviceaccount/token`
3. Exfiltrates the token to external system
4. Uses the token to authenticate to Vault from attacker's infrastructure
5. Accesses secrets and persists access indefinitely

### The Defense (With ZTWIM + Vault)

ZTWIM replaces static tokens with cryptographically-bound workload identities:
- **SPIFFE IDs**: Each workload gets a unique identity (e.g., `spiffe://cluster.local/ns/myapp/sa/myservice`)
- **Short-lived SVIDs**: X.509 certificates valid for minutes, not months
- **Workload attestation**: Identity bound to pod's actual runtime attributes (namespace, service account, node)
- **Vault OIDC integration**: Vault validates SPIFFE identity via OIDC before issuing secrets

**Attack Mitigation:**
1. Attacker compromises pod and attempts to steal credentials
2. SPIFFE SVID (X.509 cert) expires within minutes
3. Even if exfiltrated, Vault's OIDC validation checks:
   - Token signature against SPIRE's OIDC discovery keys
   - Token claims match expected SPIFFE ID format
   - Token hasn't expired
4. Token cannot be replayed from external infrastructure (workload attestation binds it to cluster context)
5. Attack fails - no persistent access gained

## Demo Structure

```
├── scenario-1-vulnerable/      # Traditional static secret approach
│   ├── deploy/                 # Vulnerable workload manifests
│   ├── attack/                 # Attack simulation scripts
│   └── README.md               # Scenario walkthrough
│
├── scenario-2-protected/       # ZTWIM + Vault integration
│   ├── deploy/                 # Protected workload manifests
│   ├── ztwim-config/           # ZTWIM operator configuration
│   ├── vault-config/           # Vault OIDC integration
│   ├── attack/                 # Same attack (will fail)
│   └── README.md               # Scenario walkthrough
│
└── scripts/
    ├── setup-vault.sh          # Vault initialization
    ├── setup-ztwim.sh          # ZTWIM operator deployment
    └── demo-runner.sh          # Automated demo execution
```

## Prerequisites

- OpenShift 4.20+ cluster
- Cluster admin access
- HashiCorp Vault instance (can be in-cluster or external)
- ZTWIM operator installed (for scenario 2)

## Quick Start

### Scenario 1: Vulnerable Deployment
```bash
cd scenario-1-vulnerable
./attack/demonstrate-theft.sh
# Shows successful token theft and Vault access
```

### Scenario 2: Protected Deployment
```bash
cd scenario-2-protected
./attack/demonstrate-theft.sh
# Shows attack failure due to SPIFFE identity binding
```

## Key Demo Talking Points

1. **Static vs. Dynamic Identity**
   - Traditional: "You are who holds the token"
   - ZTWIM: "You are who the platform attests you to be"

2. **Token Lifecycle**
   - Static tokens: Never expire, unlimited replay window
   - SPIFFE SVIDs: Auto-rotate every 1-5 minutes

3. **Blast Radius**
   - Without ZTWIM: One compromised pod = persistent Vault access
   - With ZTWIM: Compromised pod has minutes before credentials expire

4. **Zero Trust Principles**
   - Never trust, always verify
   - Cryptographic workload identity
   - Least privilege access with time-bound credentials

## References

- [ZTWIM Official Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/zero-trust-workload-identity-manager)
- [ZTWIM + Vault OIDC Integration](https://developers.redhat.com/articles/2026/05/08/federated-identity-across-hybrid-cloud-using-zero-trust-workload-identity)
- [SPIFFE/SPIRE Project](https://spiffe.io)
