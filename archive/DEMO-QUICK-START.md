# ZTWIM Demo - Quick Start Guide

## ✅ Environment Ready!

All components tested and working. Your demo is ready to run.

## 🎯 Run the Demo

### Scenario 1: Vulnerable App (Attack Succeeds)
```bash
./demo-scenario-1-attack.sh
```
**Shows**: Attacker steals static Vault token and accesses PII data

### Scenario 2: Protected App (Attack Blocked)
```bash
# Use your existing demo runner
# If pods fail to start, run:
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
```
**Shows**: Same attack fails against ZTWIM with JWT-SVIDs

## 🔧 Quick Fixes

### If Scenario 2 pods won't start:
```bash
./fix-demo-deployment-openshift.sh <namespace> <deployment> <serviceaccount>
```

### If Vault is not accessible:
```bash
oc get route vault -n vault
# Should show a route - if missing:
oc expose svc vault -n vault
```

### If attack script fails:
```bash
# Re-run setup:
bash /tmp/setup-vulnerable-vault.sh
```

## 📊 What's Deployed

| Component | Namespace | Status | Purpose |
|-----------|-----------|--------|---------|
| Vault | `vault` | ✓ Running | Secrets management |
| Vulnerable App | `vulnerable-app` | ✓ Running | Scenario 1 target |
| Protected App | `payment-demo` | ✓ Running | Scenario 2 target |
| ZTWIM Operator | `zero-trust...` | ✓ Installed | Workload identity |

## 🎬 Demo Flow

1. **Introduction** (2 min)
   - Explain the problem: Static secrets in cloud-native apps
   - Traditional approach: Long-lived tokens stored in K8s secrets

2. **Scenario 1: The Attack** (5 min)
   ```bash
   ./demo-scenario-1-attack.sh
   ```
   - Attacker gains pod access
   - Steals 90-day static Vault token
   - Uses from anywhere to steal PII
   - **Result**: Complete breach ⚠️

3. **Scenario 2: ZTWIM Protection** (5 min)
   - Same attack, different target
   - JWT-SVID with 2-minute TTL
   - No renewal without attestation
   - **Result**: Attack blocked ✓

4. **Debrief** (3 min)
   - Why ZTWIM prevents the attack
   - Benefits: Time-based expiration, cryptographic attestation, no static secrets

## 📝 Key Talking Points

**Scenario 1 - Why It Fails:**
- ❌ 90-day static token (long blast radius)
- ❌ No workload identity (any copy of token works)
- ❌ Manual rotation (requires DevOps action)
- ❌ Stored in Kubernetes Secret (visible to anyone with access)

**Scenario 2 - Why It Succeeds:**
- ✅ 2-minute JWT (minimal blast radius)
- ✅ Cryptographic attestation (can't forge)
- ✅ Automatic rotation (SPIFFE Helper)
- ✅ No static secrets (derived from platform)

## 🎯 Demo Success Metrics

At the end, audience should understand:
1. Static secrets create a **90-day blast radius** for breaches
2. ZTWIM reduces that to **2 minutes** with auto-rotation
3. Cryptographic attestation **prevents credential reuse** outside the workload
4. This works with **any secret store** (not just Vault)

## 📚 Additional Resources

- **Full documentation**: `DEMO-FIXES-SUMMARY.md`
- **OpenShift SCC guide**: `OPENSHIFT-SCC-GUIDE.md`
- **Scenario 1 details**: `DEMO-SCENARIO-1-README.md`
- **Test environment**: `./test-demo-environment.sh`

## 🆘 Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| Scenario 1 attack fails | `bash /tmp/setup-vulnerable-vault.sh` |
| Scenario 2 pods won't start | `./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service` |
| No route to Vault | `oc expose svc vault -n vault` |
| Token expired | Re-run setup script |

---

**Total Demo Time**: ~15 minutes  
**Audience**: Security architects, platform engineers, technical decision-makers  
**Wow Factor**: Live attack showing actual stolen PII data ⚠️
