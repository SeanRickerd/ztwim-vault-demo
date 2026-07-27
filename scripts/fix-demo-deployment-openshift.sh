#!/usr/bin/env bash
# Fix Demo Deployments for OpenShift
# This script patches existing deployments to work with OpenShift SCCs
#
# Usage:
#   ./fix-demo-deployment-openshift.sh <namespace> <deployment-name> <serviceaccount-name>
#
# Example:
#   ./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service

set -euo pipefail

NAMESPACE="${1:-}"
DEPLOYMENT="${2:-}"
SERVICE_ACCOUNT="${3:-}"

if [[ -z "$NAMESPACE" ]] || [[ -z "$DEPLOYMENT" ]] || [[ -z "$SERVICE_ACCOUNT" ]]; then
    cat <<EOF
Usage: $0 <namespace> <deployment-name> <serviceaccount-name>

This script fixes deployments to run on OpenShift by:
  1. Creating ServiceAccount with hostmount-anyuid SCC
  2. Removing conflicting securityContext settings
  3. Patching the deployment to use the ServiceAccount

Examples:
  $0 payment-demo payment-service payment-service
  $0 ztwim-vault-demo vault-client vault-client
EOF
    exit 1
fi

echo "==> Fixing deployment '$DEPLOYMENT' in namespace '$NAMESPACE' for OpenShift"

# Step 1: Create ServiceAccount with SCC
echo "==> Creating ServiceAccount with hostmount-anyuid SCC..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
---
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

# Step 2: Patch deployment to remove conflicting security contexts
echo "==> Patching deployment to remove conflicting security contexts..."

# Get current deployment
DEPLOY_JSON=$(oc get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json)

# Remove problematic security context settings
PATCHED_JSON=$(echo "$DEPLOY_JSON" | jq '
  # Remove pod-level securityContext constraints that conflict
  del(.spec.template.spec.securityContext.runAsNonRoot) |
  del(.spec.template.spec.securityContext.seccompProfile) |

  # Remove container-level securityContext constraints that conflict
  .spec.template.spec.containers[].securityContext.runAsNonRoot = false |
  del(.spec.template.spec.containers[].securityContext.seccompProfile) |

  # Set the serviceAccountName
  .spec.template.spec.serviceAccountName = "'$SERVICE_ACCOUNT'"
')

# Apply the patched deployment
echo "$PATCHED_JSON" | oc replace -f -

# Step 3: Wait for rollout
echo "==> Waiting for deployment rollout..."
oc rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s

echo ""
echo "✓ Deployment fixed successfully!"
echo ""
echo "Deployment '$DEPLOYMENT' in namespace '$NAMESPACE' is now:"
echo "  ✓ Using ServiceAccount: $SERVICE_ACCOUNT"
echo "  ✓ Has hostmount-anyuid SCC (for SPIRE socket)"
echo "  ✓ Compatible with OpenShift security requirements"
echo ""

# Show pod status
POD=$(oc get pod -n "$NAMESPACE" -l "app=${DEPLOYMENT}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD" ]]; then
    echo "Pod status:"
    oc get pod "$POD" -n "$NAMESPACE"
fi
