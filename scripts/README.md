# ZTWIM Vault Demo - Scripts Directory

## Quick Start

### Run the Complete Demo
```bash
# 1. Setup vulnerable environment for Scenario 1
./setup-vulnerable-vault.sh

# 2. Test environment is ready
./test-demo-environment.sh

# 3. Run Scenario 1 attack (vulnerable app)
./demo-scenario-1-attack.sh

# 4. Run Scenario 2 with the existing demo runner
./demo-runner.sh
```

## New Scripts (OpenShift Compatible)

### `demo-scenario-1-attack.sh`
**Complete attack simulation against vulnerable app with static Vault tokens**
- Shows credential theft from pod
- Demonstrates external access with stolen token
- Displays actual PII data breach
- Color-coded output for presentations

**Usage:**
```bash
./demo-scenario-1-attack.sh
```

### `setup-vulnerable-vault.sh`
**Sets up realistic vulnerable configuration for attack demos**
- Creates 90-day static Vault token
- Stores PII data (credit cards, SSNs, passwords)
- Deploys vulnerable payment processor app

**Usage:**
```bash
./setup-vulnerable-vault.sh
```

### `test-demo-environment.sh`
**Validates entire demo environment**
- Tests Vault connectivity
- Checks vulnerable app deployment
- Verifies static token configuration
- Confirms protected app status
- Tests ZTWIM operator

**Usage:**
```bash
./test-demo-environment.sh
```

### `fix-demo-deployment-openshift.sh`
**Auto-fixes OpenShift SCC issues for failed deployments**
- Creates ServiceAccount with hostmount-anyuid SCC
- Removes conflicting security contexts
- Patches deployment automatically
- Waits for successful rollout

**Usage:**
```bash
./fix-demo-deployment-openshift.sh <namespace> <deployment> <serviceaccount>

# Examples:
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
./fix-demo-deployment-openshift.sh ztwim-vault-demo vault-client vault-client
```

### `openshift-scc-patches.sh`
**Pre-deployment SCC setup utility**
- Creates ServiceAccount with proper SCCs before deployment
- Prevents pod creation failures
- Use this BEFORE deploying workloads

**Usage:**
```bash
./openshift-scc-patches.sh <namespace> <serviceaccount>

# Example:
./openshift-scc-patches.sh payment-demo payment-service
```

## Existing Scripts (From Repository)

### `demo-runner.sh`
**Interactive demo runner (Scenarios 1 & 2)**
- Original demo script from repository
- May need SCC fixes for OpenShift

### `setup-ztwim.sh`
**Installs ZTWIM operator and components**
- Deploys SPIRE server, agent, CSI driver
- Configures OIDC discovery

### `setup-vault.sh`
**Deploys HashiCorp Vault**
- Helm-based installation
- Development mode configuration

### `deploy-vault.sh`
**Alternative Vault deployment script**

### `setup-secrets-manager.sh`
**Configures Vault JWT authentication**
- Sets up OIDC trust with ZTWIM
- Creates policies and roles

## Script Execution Order

### For First-Time Setup:
1. `setup-ztwim.sh` - Install ZTWIM operator
2. `setup-vault.sh` - Deploy Vault
3. `setup-vulnerable-vault.sh` - Configure vulnerable demo
4. `test-demo-environment.sh` - Verify everything works

### For Demos:
1. `demo-scenario-1-attack.sh` - Show vulnerability
2. `demo-runner.sh` - Show ZTWIM protection

### For Troubleshooting:
1. `test-demo-environment.sh` - Identify issues
2. `fix-demo-deployment-openshift.sh` - Fix SCC problems

## OpenShift-Specific Notes

All workloads that need to access the SPIRE agent socket (via hostPath volume) require the `hostmount-anyuid` SCC. The new scripts handle this automatically.

**Common Issues:**
- Pod stuck in "CreateContainerConfigError" → Run `fix-demo-deployment-openshift.sh`
- "unable to validate against any security context constraint" → Use `openshift-scc-patches.sh`
- "runAsNonRoot and image will run as root" → Fixed by scripts

See `../OPENSHIFT-SCC-GUIDE.md` for detailed troubleshooting.

## Documentation

- `../DEMO-QUICK-START.md` - 15-minute demo flow
- `../DEMO-FIXES-SUMMARY.md` - What was fixed and why
- `../DEMO-SCENARIO-1-README.md` - Scenario 1 details
- `../OPENSHIFT-SCC-GUIDE.md` - Complete SCC guide

## Testing

Before presenting, run:
```bash
./test-demo-environment.sh
```

Should show all green checkmarks (✓) for:
- Vault accessible
- Vulnerable app running
- Static token configured
- PII data accessible
- Protected app ready
- ZTWIM operator installed
