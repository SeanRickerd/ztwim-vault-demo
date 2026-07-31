# Demo Runner - Updated for OpenShift & Working Attack Scenarios

## Changes Made

### ✅ **Integrated Working Scenario 1**
- Now calls `demo-scenario-1-attack.sh` for Scenario 1
- Shows actual successful attack with stolen PII data
- Uses the vulnerable environment setup from `setup-vulnerable-vault.sh`

### ✅ **Fixed Scenario 2 for OpenShift**
- Automatically applies OpenShift SCC permissions (`openshift-scc-patches.sh`)
- Auto-fixes failed deployments with `fix-demo-deployment-openshift.sh`
- Creates proper ServiceAccount with hostmount-anyuid SCC
- Deploys realistic protected app that demonstrates ZTWIM protection

### ✅ **Added Test Environment Option**
- New menu option (5) to test the environment
- Runs `test-demo-environment.sh` to verify all components
- Shows green checkmarks for working components

### ✅ **Improved Setup Flow**
- Setup (option 4) now includes:
  1. Vault deployment
  2. ZTWIM deployment
  3. Vulnerable environment configuration
- All scripts are called from the scripts directory

### ✅ **Better Error Handling**
- Checks for script existence before calling
- Auto-fixes SCC issues if pods don't start
- Provides helpful error messages

### ✅ **Updated Comparison Table**
- Changed token lifetime from "~10 years" to "90 days" (realistic)
- Changed JWT-SVID lifetime from "~5 minutes" to "2 minutes" (actual demo config)
- Updated attack results to show "SUCCESS ⚠️" vs "BLOCKED ✓"

## New Menu Structure

```
Select demo scenario:

  1) Full Demo (Both Scenarios)
  2) Scenario 1: Vulnerable Deployment (Static Vault Token)
  3) Scenario 2: Protected Deployment (ZTWIM JWT-SVID)
  4) Setup Only (Deploy Infrastructure)
  5) Test Environment                    ← NEW
  6) Cleanup (Remove All Resources)
  q) Quit
```

## How It Works Now

### **Option 1: Full Demo**
1. Runs Scenario 1 (attack succeeds with real PII theft)
2. Clears screen and transitions
3. Runs Scenario 2 (attack blocked by ZTWIM)
4. Shows side-by-side comparison table
5. Displays key takeaways and business impact

### **Option 2: Scenario 1 Only**
- Checks if vulnerable environment exists
- Calls `setup-vulnerable-vault.sh` if needed
- Runs `demo-scenario-1-attack.sh` attack simulation
- Shows successful credential theft and PII access

### **Option 3: Scenario 2 Only**
- Creates payment-demo namespace
- Applies OpenShift SCC permissions automatically
- Deploys protected app with ZTWIM integration
- Simulates attack attempt (fails)
- Explains why ZTWIM blocked it

### **Option 4: Setup Infrastructure**
- Runs setup-vault.sh
- Runs setup-ztwim.sh
- Runs setup-vulnerable-vault.sh
- Prepares complete environment

### **Option 5: Test Environment** *(NEW)*
- Runs test-demo-environment.sh
- Verifies all components are working
- Shows status of Vault, vulnerable app, protected app, ZTWIM

### **Option 6: Cleanup**
- Removes vulnerable-app namespace
- Removes payment-demo namespace
- Revokes stolen Vault token
- Cleans up /tmp/demo-tokens
- Keeps Vault and ZTWIM for reuse

## Prerequisites

Before running the demo, ensure these scripts exist in the scripts directory:

**Required:**
- ✅ `demo-scenario-1-attack.sh` - Scenario 1 attack simulation
- ✅ `setup-vulnerable-vault.sh` - Vulnerable environment setup
- ✅ `test-demo-environment.sh` - Environment testing
- ✅ `fix-demo-deployment-openshift.sh` - SCC auto-fixer
- ✅ `openshift-scc-patches.sh` - SCC setup utility

**Optional (from original repo):**
- `setup-vault.sh` - Vault deployment
- `setup-ztwim.sh` - ZTWIM deployment

## Usage

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./demo-runner.sh
```

### First Time Setup
1. Choose option **4** (Setup Only)
2. Wait for infrastructure deployment
3. Choose option **5** (Test Environment) to verify
4. Choose option **1** (Full Demo) to run

### Quick Demo (If Already Set Up)
1. Choose option **5** (Test Environment) to verify
2. Choose option **1** (Full Demo)

### Individual Scenarios
- Option **2** for just the attack (Scenario 1)
- Option **3** for just the protection (Scenario 2)

## What Gets Deployed

### Scenario 1 (Vulnerable):
- **Namespace:** `vulnerable-app`
- **Deployment:** `payment-processor`
- **Vault Token:** 90-day static token in Kubernetes Secret
- **PII Data:** Credit cards, SSNs, passwords in Vault

### Scenario 2 (Protected):
- **Namespace:** `payment-demo`
- **Deployment:** `payment-service`
- **ServiceAccount:** `payment-service` (with hostmount-anyuid SCC)
- **Identity:** JWT-SVID via SPIRE (2-minute TTL)

## Demo Flow Timing

**Full Demo:** ~10-15 minutes
- Scenario 1: ~5 minutes (attack succeeds)
- Transition: ~1 minute
- Scenario 2: ~4 minutes (attack blocked)
- Comparison: ~2 minutes

**Individual Scenarios:** ~5 minutes each

## Key Messages

### Scenario 1 Takeaway:
> "Static tokens create a 90-day blast radius. Once stolen, attackers have persistent access to your secrets from anywhere."

### Scenario 2 Takeaway:
> "ZTWIM reduces that blast radius to 2 minutes. Even if credentials are stolen, they expire quickly and can't be renewed without cryptographic attestation."

### Business Impact:
> "97%+ reduction in breach window, zero static secrets, automatic credential rotation, and compliance-ready dynamic secrets."

## Troubleshooting

### If Scenario 1 attack fails:
```bash
# Re-run setup
cd /home/srickerd/ztwim-vault-demo/scripts
./setup-vulnerable-vault.sh
```

### If Scenario 2 pods won't start:
The demo runner automatically calls `fix-demo-deployment-openshift.sh`, but you can also run it manually:
```bash
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
```

### If infrastructure is missing:
Choose option **4** (Setup Only) from the menu

## Files Modified

- `scripts/demo-runner.sh` - Main demo orchestration (completely rewritten)

## Files Required (All Present)

- `scripts/demo-scenario-1-attack.sh`
- `scripts/setup-vulnerable-vault.sh`
- `scripts/test-demo-environment.sh`
- `scripts/fix-demo-deployment-openshift.sh`
- `scripts/openshift-scc-patches.sh`

All required files are already in place at `/home/srickerd/ztwim-vault-demo/scripts/`
