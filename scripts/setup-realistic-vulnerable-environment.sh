#!/bin/bash
# Setup realistic vulnerable environment with customer database
# This creates a complete attack scenario showing business impact

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VAULT_NS="vault"
VULNERABLE_NS="production"

echo -e "${BLUE}+====================================================================+${NC}"
echo -e "${BLUE}|  Setting Up Realistic Vulnerable Environment                      |${NC}"
echo -e "${BLUE}+====================================================================+${NC}"
echo ""

# Check and deploy Vault if needed
echo -e "${BLUE}[0/7] Checking for Vault...${NC}"

# Create vault namespace
oc create namespace ${VAULT_NS} 2>/dev/null || true

# Check if Vault StatefulSet exists
VAULT_STS=$(oc get statefulset vault -n ${VAULT_NS} -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
if [[ -n "$VAULT_STS" ]]; then
    # Check if it's running the correct image
    VAULT_IMAGE=$(oc get statefulset vault -n ${VAULT_NS} -o jsonpath='{.spec.template.spec.containers[0].image}')
    if [[ "$VAULT_IMAGE" != "docker.io/hashicorp/vault:1.18" ]]; then
        echo -e "${YELLOW}Vault found with wrong image ($VAULT_IMAGE) - redeploying...${NC}"
        oc delete statefulset vault -n ${VAULT_NS}
        sleep 5
        VAULT_CHECK=""
    else
        VAULT_CHECK=$(oc get pod -n ${VAULT_NS} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    fi
else
    VAULT_CHECK=""
fi

if [[ -z "$VAULT_CHECK" ]]; then
    echo -e "${YELLOW}Deploying Vault...${NC}"

    # Deploy Vault in dev mode
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: ${VAULT_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-anyuid
  namespace: ${VAULT_NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:anyuid
subjects:
- kind: ServiceAccount
  name: vault
  namespace: ${VAULT_NS}
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: ${VAULT_NS}
  labels:
    app.kubernetes.io/name: vault
spec:
  ports:
  - port: 8200
    targetPort: 8200
    name: http
  selector:
    app.kubernetes.io/name: vault
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: ${VAULT_NS}
  labels:
    app.kubernetes.io/name: vault
spec:
  serviceName: vault
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vault
  template:
    metadata:
      labels:
        app.kubernetes.io/name: vault
    spec:
      serviceAccountName: vault
      containers:
      - name: vault
        image: docker.io/hashicorp/vault:1.18
        ports:
        - containerPort: 8200
          name: http
        env:
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        command:
        - vault
        - server
        - -dev
        - -dev-no-store-token
EOF

    echo -e "${BLUE}Waiting for Vault to be ready...${NC}"
    oc wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n ${VAULT_NS} --timeout=120s

    # Wait a bit longer for Vault to fully initialize
    sleep 10

    # Enable KV secrets engine
    echo -e "${BLUE}Configuring Vault...${NC}"
    oc exec -n ${VAULT_NS} vault-0 -- sh -c 'VAULT_ADDR=http://127.0.0.1:8200 vault login root' >/dev/null 2>&1
    oc exec -n ${VAULT_NS} vault-0 -- sh -c 'VAULT_ADDR=http://127.0.0.1:8200 vault secrets enable -path=secret kv-v2' 2>/dev/null || true

    echo -e "${GREEN}✓ Vault deployed and ready${NC}"
else
    echo -e "${GREEN}✓ Vault already running${NC}"
    # Still need to wait for it to be ready
    echo -e "${BLUE}Waiting for Vault to be ready...${NC}"
    oc wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n ${VAULT_NS} --timeout=120s
fi
echo ""

# Create production namespace
echo -e "${BLUE}[1/7] Creating production namespace...${NC}"
oc create namespace ${VULNERABLE_NS} 2>/dev/null || true
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Deploy PostgreSQL with customer data
echo -e "${BLUE}[2/7] Deploying customer database (PostgreSQL)...${NC}"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ${VULNERABLE_NS}
type: Opaque
stringData:
  POSTGRES_USER: customerdb
  POSTGRES_PASSWORD: SuperSecret123!
  POSTGRES_DB: customers
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customer-database
  namespace: ${VULNERABLE_NS}
  labels:
    app: customer-database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: customer-database
  template:
    metadata:
      labels:
        app: customer-database
    spec:
      containers:
      - name: postgres
        image: registry.redhat.io/rhel9/postgresql-15:latest
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRESQL_USER
          value: customerdb
        - name: POSTGRESQL_PASSWORD
          value: SuperSecret123!
        - name: POSTGRESQL_DATABASE
          value: customers
        volumeMounts:
        - name: init-script
          mountPath: /opt/app-root/src/postgresql-init
      volumes:
      - name: init-script
        configMap:
          name: db-init-script
---
apiVersion: v1
kind: Service
metadata:
  name: customer-database
  namespace: ${VULNERABLE_NS}
spec:
  selector:
    app: customer-database
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-init-script
  namespace: ${VULNERABLE_NS}
data:
  init.sql: |
    CREATE TABLE customers (
      id SERIAL PRIMARY KEY,
      customer_name VARCHAR(100) NOT NULL,
      email VARCHAR(100) NOT NULL,
      account_balance DECIMAL(10,2) NOT NULL,
      credit_card VARCHAR(19) NOT NULL,
      ssn VARCHAR(11) NOT NULL,
      account_type VARCHAR(20) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    INSERT INTO customers (customer_name, email, account_balance, credit_card, ssn, account_type) VALUES
    ('John Anderson', 'john.anderson@example.com', 125430.50, '4532-1234-5678-9012', '123-45-6789', 'premium'),
    ('Sarah Martinez', 'sarah.m@example.com', 87250.00, '5425-2334-5566-7788', '234-56-7890', 'premium'),
    ('Michael Chen', 'mchen@example.com', 52800.25, '4916-3344-5566-7799', '345-67-8901', 'business'),
    ('Emily Rodriguez', 'emily.r@example.com', 198500.00, '4024-1111-2222-3333', '456-78-9012', 'premium'),
    ('David Kim', 'dkim@example.com', 33750.75, '5425-4444-5555-6666', '567-89-0123', 'standard'),
    ('Jennifer Taylor', 'jtaylor@example.com', 267890.00, '4532-7777-8888-9999', '678-90-1234', 'premium'),
    ('Robert Lee', 'rlee@example.com', 45200.50, '4916-1234-5678-9012', '789-01-2345', 'business'),
    ('Lisa Wong', 'lwong@example.com', 156780.25, '5425-9876-5432-1098', '890-12-3456', 'premium'),
    ('James Brown', 'jbrown@example.com', 92100.00, '4024-5555-6666-7777', '901-23-4567', 'business'),
    ('Maria Garcia', 'mgarcia@example.com', 178950.50, '4532-8888-9999-0000', '012-34-5678', 'premium');

    CREATE TABLE transactions (
      id SERIAL PRIMARY KEY,
      customer_id INTEGER REFERENCES customers(id),
      amount DECIMAL(10,2) NOT NULL,
      transaction_type VARCHAR(20) NOT NULL,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
EOF

echo -e "${GREEN}✓ Customer database deployed${NC}"
echo ""

# Wait for database to be ready
echo -e "${BLUE}[3/7] Waiting for database to be ready...${NC}"
sleep 10
oc wait --for=condition=ready pod -l app=customer-database -n ${VULNERABLE_NS} --timeout=120s
echo -e "${GREEN}✓ Database is ready${NC}"
echo ""

# Initialize database with customer data
echo -e "${BLUE}[4/7] Initializing database with customer data...${NC}"
DB_POD=$(oc get pod -n ${VULNERABLE_NS} -l app=customer-database -o jsonpath='{.items[0].metadata.name}')

cat <<'EOSQL' | oc exec -i -n ${VULNERABLE_NS} ${DB_POD} -- psql -U customerdb -d customers
CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  customer_name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  account_balance DECIMAL(10,2) NOT NULL,
  credit_card VARCHAR(19) NOT NULL,
  ssn VARCHAR(11) NOT NULL,
  account_type VARCHAR(20) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customers (customer_name, email, account_balance, credit_card, ssn, account_type) VALUES
('John Anderson', 'john.anderson@example.com', 125430.50, '4532-1234-5678-9012', '123-45-6789', 'premium'),
('Sarah Martinez', 'sarah.m@example.com', 87250.00, '5425-2334-5566-7788', '234-56-7890', 'premium'),
('Michael Chen', 'mchen@example.com', 52800.25, '4916-3344-5566-7799', '345-67-8901', 'business'),
('Emily Rodriguez', 'emily.r@example.com', 198500.00, '4024-1111-2222-3333', '456-78-9012', 'premium'),
('David Kim', 'dkim@example.com', 33750.75, '5425-4444-5555-6666', '567-89-0123', 'standard'),
('Jennifer Taylor', 'jtaylor@example.com', 267890.00, '4532-7777-8888-9999', '678-90-1234', 'premium'),
('Robert Lee', 'rlee@example.com', 45200.50, '4916-1234-5678-9012', '789-01-2345', 'business'),
('Lisa Wong', 'lwong@example.com', 156780.25, '5425-9876-5432-1098', '890-12-3456', 'premium'),
('James Brown', 'jbrown@example.com', 92100.00, '4024-5555-6666-7777', '901-23-4567', 'business'),
('Maria Garcia', 'mgarcia@example.com', 178950.50, '4532-8888-9999-0000', '012-34-5678', 'premium')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(id),
  amount DECIMAL(10,2) NOT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOSQL

echo -e "${GREEN}✓ Database initialized with 10 customer records${NC}"
echo ""

# Configure Vault with database credentials
echo -e "${BLUE}[5/7] Storing database credentials in Vault...${NC}"

# Get Vault pod name
VAULT_POD=$(oc get pod -n ${VAULT_NS} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

VAULT_ADDR="http://vault.${VAULT_NS}.svc.cluster.local:8200"

# Store database credentials in Vault
oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/database/production \
  host='customer-database.${VULNERABLE_NS}.svc.cluster.local' \
  port='5432' \
  username='customerdb' \
  password='SuperSecret123!' \
  database='customers' \
  connection_string='postgresql://customerdb:SuperSecret123!@customer-database.${VULNERABLE_NS}.svc.cluster.local:5432/customers'"

# Also store API keys and other sensitive data
oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/api-keys/production \
  stripe_secret_key='sk_test_FAKE_1234567890abcdefghijk' \
  aws_access_key='AKIAIOSFODNN7EXAMPLE' \
  aws_secret_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' \
  sendgrid_api_key='SG.FAKE1234567890abcdefghijklmnop'"

echo -e "${GREEN}✓ Database credentials stored in Vault${NC}"
echo ""

# Create vulnerable application with static Vault token
echo -e "${BLUE}[6/7] Deploying vulnerable payment processing application...${NC}"

# Create a 90-day Vault token
VAULT_TOKEN=$(oc exec -n ${VAULT_NS} ${VAULT_POD} -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault token create \
  -policy=default \
  -ttl=2160h \
  -format=json" | jq -r '.auth.client_token')

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: ${VULNERABLE_NS}
type: Opaque
stringData:
  VAULT_TOKEN: "${VAULT_TOKEN}"
  VAULT_ADDR: "${VAULT_ADDR}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  namespace: ${VULNERABLE_NS}
  labels:
    app: payment-processor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-processor
  template:
    metadata:
      labels:
        app: payment-processor
    spec:
      containers:
      - name: app
        image: registry.access.redhat.com/ubi9/ubi-minimal:latest
        command:
        - /bin/bash
        - -c
        - |
          #!/bin/bash
          echo "=========================================="
          echo "  Payment Processing Service (VULNERABLE)"
          echo "=========================================="
          echo ""
          echo "Environment: PRODUCTION"
          echo "Vault Address: \${VAULT_ADDR}"
          echo "Service Status: Running"
          echo ""
          echo "⚠️  Using static Vault token (90-day TTL)"
          echo "⚠️  Token stored in environment variable"
          echo ""
          # Install PostgreSQL client for database operations
          microdnf install -y postgresql && microdnf clean all
          echo "Database client installed"
          echo ""
          echo "Application ready to process payments..."
          sleep infinity
        env:
        - name: VAULT_TOKEN
          valueFrom:
            secretKeyRef:
              name: vault-token
              key: VAULT_TOKEN
        - name: VAULT_ADDR
          valueFrom:
            secretKeyRef:
              name: vault-token
              key: VAULT_ADDR
        - name: DATABASE_HOST
          value: customer-database.${VULNERABLE_NS}.svc.cluster.local
EOF

echo -e "${GREEN}✓ Payment processor deployed${NC}"
echo ""

# Save token for demo
mkdir -p /tmp/demo-tokens
echo "${VAULT_TOKEN}" > /tmp/demo-tokens/vulnerable-vault-token.txt
echo "${VAULT_ADDR}" > /tmp/demo-tokens/vault-addr.txt
echo "${VULNERABLE_NS}" > /tmp/demo-tokens/vulnerable-namespace.txt

# Wait for app to be ready
echo -e "${BLUE}[7/7] Waiting for application to be ready...${NC}"
oc wait --for=condition=ready pod -l app=payment-processor -n ${VULNERABLE_NS} --timeout=120s
echo -e "${GREEN}✓ Application is ready${NC}"
echo ""

echo -e "${GREEN}+====================================================================+${NC}"
echo -e "${GREEN}|  Vulnerable Environment Setup Complete                            |${NC}"
echo -e "${GREEN}+====================================================================+${NC}"
echo ""

echo -e "${YELLOW}Environment Details:${NC}"
echo -e "  Namespace: ${VULNERABLE_NS}"
echo -e "  Database: PostgreSQL with 10 customer records"
echo -e "  Total Account Balances: \$1,238,652.75"
echo -e "  Vulnerable App: payment-processor"
echo -e "  Static Token TTL: 90 days (2160 hours)"
echo ""

echo -e "${YELLOW}What's at risk:${NC}"
echo -e "  • 10 customer records with PII (credit cards, SSNs)"
echo -e "  • \$1.2M+ in customer account balances"
echo -e "  • Production database credentials in Vault"
echo -e "  • API keys (Stripe, AWS, SendGrid)"
echo ""

echo -e "${RED}⚠️  This environment is intentionally vulnerable for demonstration${NC}"
echo ""
