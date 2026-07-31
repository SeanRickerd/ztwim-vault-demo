# Demo Runner Fixes Summary

## Problems Fixed

### 1. Scenario 1: Vault Authentication Failure
**Problem**: Demo showed "permission denied" because no vulnerable configuration existed  
**Root Cause**: No static token or sensitive data configured in Vault

**Solution**: Created complete vulnerable environment:
- ✅ Long-lived static Vault token (90-day TTL)
- ✅ Sensitive PII data in Vault (credit cards, SSNs, passwords)
- ✅ Vulnerable app deployment using static token
- ✅ Working attack script that successfully steals data

### 2. Scenario 2: Pod Creation Failure (OpenShift SCC)
**Problem**: Pods failed to create with SCC violations  
**Root Cause**: Missing hostmount-anyuid SCC for SPIRE socket access

**Solution**: Created SCC management scripts and updated deployment process:
- ✅ ServiceAccount with hostmount-anyuid SCC
- ✅ Removed conflicting securityContext settings
- ✅ Automated fix script for existing deployments

## Files Created

### Scenario 1 (Vulnerable App Demo)
1. **`/tmp/setup-vulnerable-vault.sh`** - Sets up Vault with static tokens and PII
2. **`demo-scenario-1-attack.sh`** - Complete attack simulation script
3. **`DEMO-SCENARIO-1-README.md`** - Documentation and usage guide
4. **`/tmp/vulnerable-app-deployment.yaml`** - Vulnerable app manifest

### OpenShift SCC Fixes
1. **`openshift-scc-patches.sh`** - Pre-deployment SCC setup utility
2. **`fix-demo-deployment-openshift.sh`** - Post-deployment auto-fixer
3. **`OPENSHIFT-SCC-GUIDE.md`** - Complete SCC troubleshooting guide

### Updated Main Scripts
1. **`deploy-ztwim-vault-demo.sh`** - Now includes:
   - Vault SCC configuration (hostmount-anyuid)
   - Demo workload SCC configuration
   - 2-minute JWT TTL patch
   
## Quick Start Commands

### Run Complete Demo

```bash
# 1. Setup vulnerable Vault environment
bash /tmp/setup-vulnerable-vault.sh

# 2. Run Scenario 1 attack (shows successful breach)
./demo-scenario-1-attack.sh

# 3. Fix any OpenShift SCC issues for Scenario 2
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service

# 4. Run Scenario 2 (shows ZTWIM blocking the attack)
# <use your existing demo runner>
```

### Fix Existing Failed Deployments

```bash
# Generic fix for any deployment
./fix-demo-deployment-openshift.sh <namespace> <deployment> <serviceaccount>

# Examples:
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
./fix-demo-deployment-openshift.sh ztwim-vault-demo vault-client vault-client
```

## Scenario 1 Attack Flow (Now Working)

```
[Attacker] → Recon → Shell Access → Find Token → Exfiltrate → External Access
                                       ↓
                            VAULT_TOKEN env var
                            /vault/secrets/token file
                                       ↓
                        hvs.CAESIF... (90-day static token)
                                       ↓
                          Vault allows access ✓
                                       ↓
                     Steal PII: Cards, SSNs, Passwords ✓
```

**Result**: ⚠️ ATTACK SUCCESSFUL - All customer data compromised

## Scenario 2 Protection (Fixed Pod Creation)

```
[Attacker] → Recon → Shell Access → Find JWT → Exfiltrate → External Access
                                       ↓
                            Short-lived JWT-SVID (2-min TTL)
                                       ↓
                            eyJhbGciOi... (JWT token)
                                       ↓
                          Vault rejects: expired OR
                          Can't renew (no SPIRE attestation)
                                       ↓
                     Attack BLOCKED ✓
```

**Result**: ✅ ATTACK BLOCKED - No data compromised

## Testing Checklist

- [x] Vault accessible via route
- [x] Static token created with 90-day TTL
- [x] Sensitive PII data stored in Vault
- [x] Vulnerable app deployed and running
- [x] Attack script successfully steals data
- [x] OpenShift SCC fixes applied
- [x] Protected app can access SPIRE socket
- [x] JWT-SVID TTL set to 2 minutes

## Environment Details

**Vault**:
- Namespace: `vault`
- Route: `vault-vault.apps.rosa...`
- Root token: `root` (dev mode)
- Vulnerable token: Saved in `/tmp/demo-tokens/`

**Vulnerable App**:
- Namespace: `vulnerable-app`
- Deployment: `payment-processor`
- Token location: `/vault/secrets/token` + `VAULT_TOKEN` env var

**Protected App** (Scenario 2):
- Namespace: `payment-demo` (or your configured namespace)
- ServiceAccount: Needs `hostmount-anyuid` SCC
- JWT TTL: 2 minutes

## Next Steps

Your demo runner should now work end-to-end:
1. Scenario 1 shows successful attack with static tokens
2. Scenario 2 shows blocked attack with ZTWIM protection

The contrast clearly demonstrates why zero-trust workload identity matters!
