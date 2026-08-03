# Cleanup Verification Checklist

This document verifies that `cleanup-demo.sh` returns the cluster to a completely clean pre-demo state.

## Automated Cleanup

The `cleanup-demo.sh` script removes:

### Namespaces
- ✅ `production` - Vulnerable environment
- ✅ `production-protected` - ZTWIM-protected environment
- ✅ `vault` - Shared Vault instance

### Temporary Files
- ✅ `/tmp/demo-tokens/` - Directory with token files
- ✅ `/tmp/backdoor.yaml` - Backdoor pod manifest
- ✅ `/tmp/spire-ca.crt` - SPIRE CA certificate (if created)

### Processes
- ✅ Port-forwards to vault or production namespaces

## Auto-Cleaned by Namespace Deletion

When namespaces are deleted, Kubernetes/OpenShift automatically removes:

### In `production` namespace:
- ✅ Pods: customer-database, payment-processor, backdoor-exfil
- ✅ Deployments: customer-database, payment-processor
- ✅ Services: customer-database
- ✅ ConfigMaps: db-init-script
- ✅ Secrets: postgres-secret, vault-token
- ✅ ServiceAccount: payment-processor
- ✅ RoleBinding: payment-processor-anyuid

### In `production-protected` namespace:
- ✅ Pods: payment-processor-protected
- ✅ Deployments: payment-processor-protected
- ✅ ServiceAccount: payment-processor-protected
- ✅ RoleBinding: payment-processor-protected-anyuid

### In `vault` namespace:
- ✅ StatefulSet: vault
- ✅ Pods: vault-0
- ✅ Services: vault, vault-internal
- ✅ ServiceAccount: vault
- ✅ RoleBinding: vault-anyuid

## NOT Created (No Cleanup Required)

The demo does NOT create any of these cluster-wide resources:

- ✅ No ClusterRoleBindings
- ✅ No custom SecurityContextConstraints (uses existing anyuid)
- ✅ No PersistentVolumes (uses emptyDir and memory storage)
- ✅ No PersistentVolumeClaims
- ✅ No LoadBalancers or NodePorts
- ✅ No Ingress or Routes
- ✅ No CustomResourceDefinitions
- ✅ No cluster-level configuration changes

## Verification After Cleanup

The cleanup script includes automatic verification:

```bash
./cleanup-demo.sh
```

**Output includes:**
- ✓ Namespace check (should find 0 demo namespaces)
- ✓ Temporary file check (should find 0 files)
- ✓ Port-forward check (should find 0 processes)

**Expected result:** All checks pass with ✓

## Manual Verification (Optional)

If you want to double-check manually:

```bash
# Check for demo namespaces
oc get namespace | grep -E "production|vault"
# Expected: No results

# Check for demo pods
oc get pods --all-namespaces | grep -E "production|vault"
# Expected: No results

# Check for temporary files
ls -la /tmp/demo-tokens /tmp/backdoor.yaml /tmp/spire-ca.crt
# Expected: "No such file or directory"

# Check for port-forwards
ps aux | grep "oc port-forward" | grep -E "vault|production"
# Expected: No results (except the grep command itself)
```

## Cluster State After Cleanup

After running `cleanup-demo.sh`, your cluster is in **exactly the same state** as before the demo:

- ✅ No demo namespaces
- ✅ No demo resources
- ✅ No temporary files
- ✅ No background processes
- ✅ No cluster-level changes
- ✅ Ready for the next demo

## Re-running the Demo

After cleanup, you can immediately run the demo again:

```bash
# Full demo cycle (repeatable)
./setup-realistic-vulnerable-environment.sh   # 5 min
./setup-protected-ztwim-environment.sh        # 2 min
./interactive-attack-demo.sh                  # 20-25 min
./cleanup-demo.sh                             # 1 min
```

**Total cycle time:** ~30 minutes

You can run this cycle as many times as needed on the same cluster.

---

**Last Updated:** 2026-08-03  
**Verified Clean:** ✅ Yes, cluster returns to pre-demo state
