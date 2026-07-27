#!/usr/bin/env bash
# OpenShift SCC Patch Script for ZTWIM Demo
# This script applies necessary Security Context Constraints for ZTWIM workloads on OpenShift
#
# Usage:
#   ./openshift-scc-patches.sh <namespace> <serviceaccount-name>
#
# Example:
#   ./openshift-scc-patches.sh payment-demo payment-service

set -euo pipefail

NAMESPACE="${1:-}"
SERVICE_ACCOUNT="${2:-}"

if [[ -z "$NAMESPACE" ]] || [[ -z "$SERVICE_ACCOUNT" ]]; then
    echo "Usage: $0 <namespace> <serviceaccount-name>"
    echo ""
    echo "Examples:"
    echo "  $0 payment-demo payment-service"
    echo "  $0 ztwim-vault-demo vault-client"
    exit 1
fi

echo "==> Applying OpenShift SCC permissions for ZTWIM workloads"
echo "    Namespace: $NAMESPACE"
echo "    ServiceAccount: $SERVICE_ACCOUNT"

# Check if we're on OpenShift
if ! oc version --client &>/dev/null; then
    echo "ERROR: oc command not found. Are you on OpenShift?"
    exit 1
fi

# Create namespace if it doesn't exist
oc create namespace "$NAMESPACE" 2>/dev/null || true

# Create ServiceAccount if it doesn't exist
if ! oc get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" &>/dev/null; then
    echo "==> Creating ServiceAccount $SERVICE_ACCOUNT"
    oc create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE"
fi

# Apply hostmount-anyuid SCC (required for SPIRE agent socket hostPath volume)
echo "==> Granting hostmount-anyuid SCC (for SPIRE socket access)"
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SERVICE_ACCOUNT}-hostmount-anyuid
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:hostmount-anyuid
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
EOF

echo "✓ SCC permissions applied successfully"
echo ""
echo "The ServiceAccount '${SERVICE_ACCOUNT}' in namespace '${NAMESPACE}' can now:"
echo "  - Mount hostPath volumes (for SPIRE agent socket)"
echo "  - Run containers with anyuid (compatible with various base images)"
echo ""
echo "When creating deployments, ensure:"
echo "  1. spec.template.spec.serviceAccountName: ${SERVICE_ACCOUNT}"
echo "  2. Remove or set securityContext.runAsNonRoot: false (if using root images)"
echo "  3. Remove seccompProfile if it conflicts with the SCC"
