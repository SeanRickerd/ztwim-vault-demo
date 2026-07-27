# OpenShift SCC Guide for ZTWIM Demo

## Problem

ZTWIM workloads require access to the SPIRE agent socket via hostPath volumes, which is restricted by OpenShift's default Security Context Constraints (SCCs). Without proper SCC permissions, pods will fail to start with errors like:

```
Error creating: pods "..." is forbidden: unable to validate against any security context constraint:
  spec.volumes[0]: Invalid value: "hostPath": hostPath volumes are not allowed to be used
```

## Solution

Apply the `hostmount-anyuid` SCC to the ServiceAccount used by ZTWIM workloads.

## Quick Fix Scripts

### 1. Fix Existing Deployment (Most Common)

Use this when you already have a deployment that's failing:

```bash
./fix-demo-deployment-openshift.sh <namespace> <deployment> <serviceaccount>

# Example:
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
```

This script:
- Creates ServiceAccount with hostmount-anyuid SCC
- Removes conflicting securityContext settings
- Patches the deployment automatically

### 2. Pre-create ServiceAccount (Before Deployment)

Use this before deploying to avoid failures:

```bash
./openshift-scc-patches.sh <namespace> <serviceaccount>

# Example:
./openshift-scc-patches.sh payment-demo payment-service
```

Then ensure your deployment uses this ServiceAccount:
```yaml
spec:
  template:
    spec:
      serviceAccountName: payment-service
```

## Manual Steps (if scripts not available)

### Step 1: Create ServiceAccount with SCC

```bash
NAMESPACE="payment-demo"
SA_NAME="payment-service"

# Create ServiceAccount
oc create serviceaccount $SA_NAME -n $NAMESPACE

# Grant hostmount-anyuid SCC
oc adm policy add-scc-to-user hostmount-anyuid \
  system:serviceaccount:${NAMESPACE}:${SA_NAME}

# OR use RoleBinding (preferred for GitOps)
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SA_NAME}-hostmount-anyuid
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:hostmount-anyuid
subjects:
- kind: ServiceAccount
  name: ${SA_NAME}
  namespace: ${NAMESPACE}
EOF
```

### Step 2: Fix Deployment SecurityContext

Remove or adjust these settings in your deployment:

```yaml
spec:
  template:
    spec:
      serviceAccountName: payment-service  # ADD THIS
      securityContext:
        # REMOVE: runAsNonRoot: true
        # REMOVE: seccompProfile
      containers:
      - name: app
        securityContext:
          runAsNonRoot: false  # CHANGE from true
          # REMOVE: seccompProfile
```

### Step 3: Apply Changes

```bash
# If using kubectl/oc apply
oc apply -f deployment.yaml

# OR patch existing deployment
oc patch deployment payment-service -n payment-demo \
  --type=merge \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"payment-service"}}}}'

# Remove conflicting security contexts
oc get deployment payment-service -n payment-demo -o json | \
  jq 'del(.spec.template.spec.securityContext.runAsNonRoot) | 
      del(.spec.template.spec.securityContext.seccompProfile) |
      del(.spec.template.spec.containers[0].securityContext.seccompProfile) |
      .spec.template.spec.containers[0].securityContext.runAsNonRoot = false' | \
  oc replace -f -
```

## Common Errors and Solutions

### Error 1: ServiceAccount Not Found
```
error looking up service account payment-demo/payment-service: serviceaccount "payment-service" not found
```

**Solution:** ServiceAccount was created but deployment references wrong namespace or name.
```bash
oc get sa -n payment-demo
# Verify the name matches what deployment expects
```

### Error 2: runAsNonRoot Conflict
```
Error: container has runAsNonRoot and image will run as root
```

**Solution:** Remove `runAsNonRoot: true` or set to `false`:
```bash
oc get deployment payment-service -n payment-demo -o json | \
  jq '.spec.template.spec.containers[0].securityContext.runAsNonRoot = false' | \
  oc replace -f -
```

### Error 3: seccompProfile Conflict
```
seccomp may not be set (pod or container must set securityContext.seccompProfile)
```

**Solution:** Remove seccompProfile entirely:
```bash
oc get deployment payment-service -n payment-demo -o json | \
  jq 'del(.spec.template.spec.securityContext.seccompProfile) |
      del(.spec.template.spec.containers[0].securityContext.seccompProfile)' | \
  oc replace -f -
```

## Verification

After applying fixes, verify:

```bash
# Check pod is running
oc get pods -n payment-demo

# Verify ServiceAccount
oc get sa payment-service -n payment-demo

# Verify SCC assignment
oc adm policy who-can use scc hostmount-anyuid -n payment-demo | grep payment-service

# Check pod can access SPIRE socket
POD=$(oc get pod -n payment-demo -l app=payment-service -o jsonpath='{.items[0].metadata.name}')
oc exec $POD -n payment-demo -- ls -la /run/spire/sockets
```

## Why These SCCs Are Required

| Requirement | Reason | SCC Needed |
|------------|--------|------------|
| **hostPath volume** | Access SPIRE agent socket at `/run/spire/sockets` | `hostmount-anyuid` |
| **anyuid** | Some base images (UBI) run as root by default | `hostmount-anyuid` (includes anyuid) |

## Security Considerations

**Is this secure?**
- ✅ Yes - `hostmount-anyuid` is specifically designed for legitimate hostPath use cases
- ✅ The hostPath is read-only in workload pods
- ✅ SPIRE agent socket is isolated per-node and secured via Unix permissions
- ✅ More secure than using `privileged` SCC

**Best practices:**
1. Use dedicated ServiceAccount per workload (don't reuse `default`)
2. Apply SCC to specific ServiceAccounts, not to all users in namespace
3. Document why each workload needs these permissions
4. Use RoleBindings (not cluster-wide) for least privilege

## Integration with Updated Scripts

The `deploy-ztwim-vault-demo.sh` script has been updated to automatically:
1. Create ServiceAccounts with proper SCCs
2. Patch deployments for OpenShift compatibility
3. Handle Vault and demo workload requirements

For custom demo runners or scenarios, use the helper scripts:
```bash
# Before deploying
./openshift-scc-patches.sh <namespace> <serviceaccount>

# After deployment (if failed)
./fix-demo-deployment-openshift.sh <namespace> <deployment> <serviceaccount>
```

## References

- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [SPIRE on Kubernetes](https://spiffe.io/docs/latest/deploying/spire_agent/)
- [ZTWIM Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/security_and_compliance/zero-trust-workload-identity-manager)
