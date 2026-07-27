#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
VAULT_TYPE="${VAULT_TYPE:-openbao}"  # openbao or vault
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-dev}"  # dev or production

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deploying ${VAULT_TYPE^^} for ZTWIM Demo                        ║${NC}"
echo -e "${BLUE}║  Mode: ${DEPLOYMENT_MODE}                                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create namespace
echo -e "${BLUE}Step 1: Creating namespace${NC}"
kubectl create namespace "$VAULT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace created: $VAULT_NAMESPACE${NC}"
echo ""

# Deploy based on type
if [ "$VAULT_TYPE" = "openbao" ]; then
    echo -e "${BLUE}Step 2: Deploying OpenBao${NC}"

    # Deploy OpenBao
    cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao
  namespace: $VAULT_NAMESPACE
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-config
  namespace: $VAULT_NAMESPACE
data:
  local.json: |
    {
      "backend": {
        "file": {
          "path": "/openbao/data"
        }
      },
      "default_lease_ttl": "168h",
      "max_lease_ttl": "720h",
      "listener": {
        "tcp": {
          "address": "0.0.0.0:8200",
          "tls_disable": true
        }
      },
      "ui": true,
      "log_level": "info"
    }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openbao-data
  namespace: $VAULT_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao
  namespace: $VAULT_NAMESPACE
  labels:
    app: openbao
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao
  template:
    metadata:
      labels:
        app: openbao
    spec:
      serviceAccountName: openbao
      containers:
      - name: openbao
        image: quay.io/openbao/openbao:2.0.1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8200
          name: http
          protocol: TCP
        - containerPort: 8201
          name: internal
          protocol: TCP
        env:
        - name: BAO_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: BAO_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        - name: BAO_ADDR
          value: "http://127.0.0.1:8200"
        - name: BAO_LOCAL_CONFIG
          valueFrom:
            configMapKeyRef:
              name: openbao-config
              key: local.json
        command:
        - bao
        - server
        - -dev
        - -dev-root-token-id=root
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: data
          mountPath: /openbao/data
        - name: config
          mountPath: /openbao/config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: openbao-data
      - name: config
        configMap:
          name: openbao-config
---
apiVersion: v1
kind: Service
metadata:
  name: openbao
  namespace: $VAULT_NAMESPACE
  labels:
    app: openbao
spec:
  type: ClusterIP
  ports:
  - port: 8200
    targetPort: 8200
    protocol: TCP
    name: http
  - port: 8201
    targetPort: 8201
    protocol: TCP
    name: internal
  selector:
    app: openbao
---
# Alias as "vault" for compatibility
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: $VAULT_NAMESPACE
  labels:
    app: openbao
spec:
  type: ClusterIP
  ports:
  - port: 8200
    targetPort: 8200
    protocol: TCP
    name: http
  selector:
    app: openbao
EOF

    echo -e "${GREEN}✓ OpenBao deployed${NC}"

    # Wait for OpenBao to be ready
    echo -e "${BLUE}Step 3: Waiting for OpenBao to be ready${NC}"
    kubectl wait --for=condition=ready pod -l app=openbao -n "$VAULT_NAMESPACE" --timeout=300s
    echo -e "${GREEN}✓ OpenBao is ready${NC}"

    VAULT_CMD="bao"

else
    # Deploy HashiCorp Vault
    echo -e "${BLUE}Step 2: Deploying HashiCorp Vault${NC}"

    cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: $VAULT_NAMESPACE
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: $VAULT_NAMESPACE
data:
  local.json: |
    {
      "backend": {
        "file": {
          "path": "/vault/data"
        }
      },
      "default_lease_ttl": "168h",
      "max_lease_ttl": "720h",
      "listener": {
        "tcp": {
          "address": "0.0.0.0:8200",
          "tls_disable": true
        }
      },
      "ui": true
    }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vault-data
  namespace: $VAULT_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: $VAULT_NAMESPACE
  labels:
    app: vault
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      containers:
      - name: vault
        image: hashicorp/vault:1.18
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8200
          name: http
          protocol: TCP
        - containerPort: 8201
          name: internal
          protocol: TCP
        env:
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        - name: VAULT_LOCAL_CONFIG
          valueFrom:
            configMapKeyRef:
              name: vault-config
              key: local.json
        command:
        - vault
        - server
        - -dev
        - -dev-root-token-id=root
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: data
          mountPath: /vault/data
        - name: config
          mountPath: /vault/config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: vault-data
      - name: config
        configMap:
          name: vault-config
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: $VAULT_NAMESPACE
  labels:
    app: vault
spec:
  type: ClusterIP
  ports:
  - port: 8200
    targetPort: 8200
    protocol: TCP
    name: http
  - port: 8201
    targetPort: 8201
    protocol: TCP
    name: internal
  selector:
    app: vault
EOF

    echo -e "${GREEN}✓ Vault deployed${NC}"

    # Wait for Vault to be ready
    echo -e "${BLUE}Step 3: Waiting for Vault to be ready${NC}"
    kubectl wait --for=condition=ready pod -l app=vault -n "$VAULT_NAMESPACE" --timeout=300s
    echo -e "${GREEN}✓ Vault is ready${NC}"

    VAULT_CMD="vault"
fi

echo ""

# Get pod name
POD_NAME=$(kubectl get pod -n "$VAULT_NAMESPACE" -l app=${VAULT_TYPE} -o jsonpath='{.items[0].metadata.name}')
echo -e "${BLUE}Pod: $POD_NAME${NC}"
echo ""

# Configure Vault/OpenBao
echo -e "${BLUE}Step 4: Configuring ${VAULT_TYPE^^}${NC}"

# Set up port forward in background
kubectl port-forward -n "$VAULT_NAMESPACE" "svc/${VAULT_TYPE}" 8200:8200 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

export VAULT_ADDR='http://localhost:8200'
export BAO_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
export BAO_TOKEN='root'

# Enable KV secrets engine
echo -e "${BLUE}  Enabling KV secrets engine...${NC}"
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} secrets enable -path=secret kv-v2 2>/dev/null || \
    echo "  KV secrets engine already enabled"
echo -e "${GREEN}✓ KV secrets engine enabled${NC}"

# Create demo secrets
echo -e "${BLUE}  Creating demo secrets...${NC}"
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} kv put secret/payment/database \
    username="payment_user" \
    password="demo-secret-password-123" \
    host="postgres.payment-demo.svc.cluster.local" \
    port="5432" \
    database="payments_db"

kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} kv put secret/payment/api \
    api_key="demo-api-key-xyz789" \
    api_secret="demo-api-secret-abc456"

echo -e "${GREEN}✓ Demo secrets created${NC}"

# Configure Kubernetes auth method (for Scenario 1)
echo -e "${BLUE}  Configuring Kubernetes auth method...${NC}"

# Enable Kubernetes auth
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} auth enable kubernetes 2>/dev/null || \
    echo "  Kubernetes auth already enabled"

# Get Kubernetes details
K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')

# Configure Kubernetes auth
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} write auth/kubernetes/config \
    kubernetes_host="$K8S_HOST"

# Create policy for payment service
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- sh -c "cat > /tmp/payment-policy.hcl <<'EOF'
path \"secret/data/payment/*\" {
  capabilities = [\"read\"]
}

path \"secret/metadata/payment/*\" {
  capabilities = [\"list\"]
}
EOF"

kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} policy write payment-secrets /tmp/payment-policy.hcl

# Create Kubernetes auth role
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} write auth/kubernetes/role/payment-service-role \
    bound_service_account_names=payment-service \
    bound_service_account_namespaces=payment-demo \
    policies=payment-secrets \
    ttl=24h

echo -e "${GREEN}✓ Kubernetes auth configured${NC}"

# Enable JWT auth method (for Scenario 2 - will be configured later with SPIRE)
echo -e "${BLUE}  Enabling JWT auth method (for ZTWIM)...${NC}"
kubectl exec -n "$VAULT_NAMESPACE" "$POD_NAME" -- ${VAULT_CMD} auth enable jwt 2>/dev/null || \
    echo "  JWT auth already enabled"
echo -e "${GREEN}✓ JWT auth method enabled${NC}"

# Kill port-forward
kill $PF_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${VAULT_TYPE^^} Deployment Complete!                                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}Deployment Details:${NC}"
echo "  Type: ${VAULT_TYPE^^}"
echo "  Namespace: $VAULT_NAMESPACE"
echo "  Mode: ${DEPLOYMENT_MODE}"
echo "  Service: ${VAULT_TYPE}.${VAULT_NAMESPACE}.svc.cluster.local:8200"
echo "  Root Token: root"
echo "  Pod: $POD_NAME"
echo ""

echo -e "${BLUE}Configured Components:${NC}"
echo "  ✓ KV Secrets Engine (secret/)"
echo "  ✓ Kubernetes Auth Method (for Scenario 1)"
echo "  ✓ JWT Auth Method (for Scenario 2 - ZTWIM)"
echo "  ✓ Demo Secrets (secret/payment/*)"
echo "  ✓ Payment Policy (payment-secrets)"
echo ""

echo -e "${BLUE}Access ${VAULT_TYPE^^}:${NC}"
echo "  # Port-forward:"
echo "  kubectl port-forward -n $VAULT_NAMESPACE svc/${VAULT_TYPE} 8200:8200"
echo ""
echo "  # Then access UI:"
echo "  http://localhost:8200"
echo "  Token: root"
echo ""
echo "  # Or use CLI:"
echo "  export VAULT_ADDR='http://localhost:8200'"
echo "  export VAULT_TOKEN='root'"
echo "  ${VAULT_CMD} kv get secret/payment/database"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. For Scenario 1 (vulnerable): Ready to use"
echo "  2. For Scenario 2 (protected): Run ./setup-ztwim.sh to configure JWT/OIDC"
echo ""

echo -e "${GREEN}${VAULT_TYPE^^} is ready for the demo!${NC}"
