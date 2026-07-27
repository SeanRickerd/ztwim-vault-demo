# ZTWIM Vault Demo - START HERE! 🚀

## Quick Start (3 Steps)

```bash
# 1. Navigate to demo directory
cd /home/srickerd/ztwim-vault-demo/scripts

# 2. Test environment (should show all green ✓)
./test-demo-environment.sh

# 3. Run the demo!
./demo-runner.sh
```

Then choose option **1** (Full Demo) from the menu.

---

## What This Demo Shows

### 🎯 **The Problem**
Traditional cloud-native apps use static, long-lived secrets (tokens, passwords, API keys) stored in Kubernetes Secrets or config files. When a pod is compromised, attackers steal these credentials and use them from anywhere for months.

### ⚠️ **Scenario 1: The Attack (Without ZTWIM)**
Shows a realistic attack where:
1. Attacker gains shell access to a pod
2. Steals a 90-day static Vault token
3. Uses it from outside the cluster
4. Accesses sensitive PII data (credit cards, SSNs, passwords)
5. Maintains persistent access for 90 days

**Result:** Complete breach with actual stolen customer data displayed

### ✅ **Scenario 2: The Defense (With ZTWIM)**
Shows the same attack failing against ZTWIM:
1. Attacker gains shell access to a pod
2. No static secrets to steal
3. JWT-SVIDs expire in 2 minutes
4. Cannot renew without cryptographic attestation
5. Attack blocked - no data compromised

**Result:** Attack completely blocked by zero-trust workload identity

---

## Demo Structure

```
╔════════════════════════════════════════════════════════╗
║  ZTWIM 1.1 + Vault Integration - Adversarial Demo     ║
╚════════════════════════════════════════════════════════╝

Select demo scenario:

  1) Full Demo (Both Scenarios)              ← Start here!
  2) Scenario 1: Vulnerable Deployment (Static Vault Token)
  3) Scenario 2: Protected Deployment (ZTWIM JWT-SVID)
  4) Setup Only (Deploy Infrastructure)
  5) Test Environment
  6) Cleanup (Remove All Resources)
  q) Quit
```

---

## First Time Setup

If this is your first time running the demo:

```bash
cd /home/srickerd/ztwim-vault-demo/scripts

# Run the interactive demo
./demo-runner.sh

# Choose option 4 (Setup Only) first
# Then choose option 5 (Test Environment) to verify
# Finally choose option 1 (Full Demo)
```

---

## What You'll See

### **Scenario 1 Output (Attack Succeeds):**
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

Token valid for: 90 days
Attack origin: External (from outside cluster)
```

### **Scenario 2 Output (Attack Blocked):**
```
✓ ATTACK BLOCKED BY ZTWIM!

Why the attack failed:
  ✓ No static secrets in pod (nothing to steal)
  ✓ JWT-SVIDs expire in 2 minutes (minimal blast radius)
  ✓ SPIRE Workload API requires attestation
  ✓ Cannot replay credentials from outside the pod
  ✓ Cannot renew JWT without cryptographic proof
```

### **Final Comparison:**
```
Metric                          Without ZTWIM        With ZTWIM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Token Lifetime                  90 days              2 minutes
Static Secrets                  Yes                  No
Identity Binding                None                 Cryptographic
Replay Window                   90 days              <2 minutes
Workload Attestation            No                   Yes (SPIRE)
External Replay Possible        Yes                  No
Persistent Access               Yes                  No
Attack Result                   SUCCESS ⚠️           BLOCKED ✓
```

---

## Key Talking Points

**For Security Architects:**
- Eliminates 90-day breach window → reduces to 2 minutes (97%+ reduction)
- Cryptographic attestation prevents credential replay
- No manual rotation required
- Meets compliance requirements for dynamic secrets

**For Platform Engineers:**
- SPIFFE/SPIRE standard (CNCF graduated project)
- Works with any secret store (not just Vault)
- Integrates with existing OIDC infrastructure
- OpenShift-native with Security Context Constraints

**For Business Leaders:**
- Prevents data breaches from stolen credentials
- Reduces compliance risk
- No operational overhead for credential rotation
- Industry-standard zero-trust architecture

---

## Demo Timing

- **Full Demo:** ~10-15 minutes
- **Scenario 1 only:** ~5 minutes
- **Scenario 2 only:** ~5 minutes
- **Setup (first time):** ~10 minutes

---

## Environment Details

**What's Deployed:**

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| HashiCorp Vault | `vault` | Secrets management |
| ZTWIM Operator | `zero-trust-workload-identity-manager` | Workload identity |
| Vulnerable App | `vulnerable-app` | Scenario 1 target |
| Protected App | `payment-demo` | Scenario 2 target |

**Vault Contents:**
- Sensitive PII data at `secret/customer-data`
- 90-day static token (Scenario 1)
- OIDC JWT authentication (Scenario 2)

---

## Documentation

| File | Purpose |
|------|---------|
| `START-HERE.md` | This file - quick start guide |
| `DEMO-QUICK-START.md` | 15-minute demo flow |
| `DEMO-RUNNER-CHANGES.md` | What was updated in demo-runner.sh |
| `DEMO-FIXES-SUMMARY.md` | All problems fixed |
| `OPENSHIFT-SCC-GUIDE.md` | OpenShift troubleshooting |
| `scripts/README.md` | Scripts directory guide |

---

## Troubleshooting

### Demo won't start?
```bash
./test-demo-environment.sh
# Shows which components are missing
```

### Scenario 1 attack fails?
```bash
./setup-vulnerable-vault.sh
# Reconfigures vulnerable environment
```

### Scenario 2 pods won't start?
```bash
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
# Fixes OpenShift SCC issues
```

### Need to reset everything?
From the demo-runner menu, choose option **6** (Cleanup), then option **4** (Setup).

---

## For Black Hat / Conference Presentations

**Audience Hook:**
> "How many of you have Kubernetes Secrets in your clusters? Keep your hands up if those secrets have been there for more than a month. More than a year? Congratulations - you have a 90-day blast radius for every pod compromise. Let me show you what that looks like..."

**Demo Flow:**
1. Show Scenario 1 (5 min) - emphasize the **actual stolen data**
2. "Now let's see the same attack with zero-trust..." (1 min)
3. Show Scenario 2 (4 min) - emphasize **attack completely fails**
4. Show comparison table (2 min) - emphasize **97% reduction in breach window**

**Closing:**
> "ZTWIM reduces your blast radius from months to minutes, eliminates static secrets entirely, and requires zero operational overhead. That's the difference between a headline-making breach and a non-event."

---

## Support

All required files are present in `/home/srickerd/ztwim-vault-demo/`

**Main demo script:**
```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./demo-runner.sh
```

**Quick test:**
```bash
./test-demo-environment.sh
```

---

## Ready to Demo! 🎬

The demo is fully configured and tested. Just run:

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./demo-runner.sh
```

Choose option **1** and let the demo show the dramatic difference between vulnerable and protected deployments!

---

## ✨ NEW: Enhanced Scenario 2!

Scenario 2 now shows a **dramatic, step-by-step attack failure** with:

- **7 attack attempts** - each one visibly blocked
- **4 defense layers** - explained with visual feedback
- **Side-by-side comparison** - SUCCESS vs BLOCKED for every step
- **Color-coded output** - red (attacker), green (defender), yellow (findings)

**Impact:** Just as dramatic as Scenario 1, but shows complete protection!

See `SCENARIO-2-ENHANCED.md` for details.

