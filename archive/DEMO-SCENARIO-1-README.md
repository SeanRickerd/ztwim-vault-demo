# Demo Scenario 1: Vulnerable App Attack

## Overview

This scenario demonstrates a **successful credential theft attack** against a traditional application using static Vault tokens. The attacker gains shell access to a pod, steals the long-lived Vault token, and uses it from outside the cluster to access sensitive customer data.

## Setup (One-Time)

Run these scripts in order to prepare the vulnerable environment:

```bash
# 1. Setup Vault with vulnerable configuration
./setup-vulnerable-vault.sh

# 2. Deploy vulnerable application
# (Already done - payment-processor deployed in vulnerable-app namespace)

# 3. Verify setup
oc get pods -n vulnerable-app
oc get route vault -n vault
```

## Running the Attack Demo

```bash
./demo-scenario-1-attack.sh
```

## What the Demo Shows

### Attack Steps (Automated):

1. **Reconnaissance** - Attacker identifies target pod
2. **Initial Access** - Gains shell access to application pod (simulated)
3. **Discovery** - Finds Vault token in environment variables and mounted secrets
4. **Exfiltration** - Copies token to external attacker infrastructure
5. **Exploitation** - Uses stolen token to access Vault from outside the cluster

### Attack Success:

```
⚠️  ATTACK SUCCESSFUL!

Attacker successfully accessed sensitive customer data:
{
  "credit_card": "4532-1234-5678-9012",
  "ssn": "123-45-6789",
  "api_key": "sk-prod-super-secret-key-12345",
  "database_password": "MySecureP@ssw0rd123!",
  "customer_name": "John Doe",
  "account_balance": "$50,000"
}
```

## Why This Attack Succeeds

❌ **Static, long-lived credentials** (90-day TTL)  
❌ **No workload identity verification**  
❌ **Token usable from ANY location** (no attestation)  
❌ **No automatic expiration** (manual rotation required)  
❌ **Credentials visible** in env vars and mounted files

## Attack Impact

- **Blast Radius**: All data accessible by the token
- **Duration**: 90 days until manual revocation
- **Detection**: Difficult - looks like legitimate app access
- **Origin**: Can be used from anywhere (not limited to cluster)

## Vulnerable Architecture

```
┌─────────────────────┐
│  Kubernetes Secret  │ ← Static token stored here
│  (vault-token)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Payment Processor  │ ← Token mounted as file + env var
│  Pod                │
└──────────┬──────────┘
           │
           │ Attacker gains shell access
           ▼
┌─────────────────────┐
│  Attacker           │ ← Steals token
│  Infrastructure     │
└──────────┬──────────┘
           │
           │ Uses stolen token
           ▼
┌─────────────────────┐
│  HashiCorp Vault    │ ← Grants access (can't distinguish attacker from app)
└─────────────────────┘
```

## Files Created

- `/tmp/demo-tokens/vulnerable-static-token.txt` - The static token
- `/tmp/demo-tokens/vault-addr.txt` - Vault address
- Vault secret: `secret/customer-data` - PII data to be stolen

## Cleanup

To remove the vulnerable environment:

```bash
oc delete namespace vulnerable-app
oc exec -n vault vault-0 -- vault token revoke $(cat /tmp/demo-tokens/vulnerable-static-token.txt)
rm -rf /tmp/demo-tokens
```

## Next: Scenario 2

After running this attack, proceed to **Scenario 2** which shows the same attack failing against a ZTWIM-protected application using short-lived JWT-SVIDs with cryptographic attestation.

The contrast demonstrates why zero-trust workload identity is essential for modern cloud-native applications.

---

**Security Note**: This is a demonstration environment only. Never use static, long-lived secrets in production!
