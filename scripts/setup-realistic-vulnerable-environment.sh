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

# Create production namespace
echo -e "${BLUE}[1/6] Creating production namespace...${NC}"
oc create namespace ${VULNERABLE_NS} 2>/dev/null || true
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Deploy PostgreSQL with customer data
echo -e "${BLUE}[2/6] Deploying customer database (PostgreSQL)...${NC}"
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
echo -e "${BLUE}[3/6] Waiting for database to be ready...${NC}"
sleep 10
oc wait --for=condition=ready pod -l app=customer-database -n ${VULNERABLE_NS} --timeout=120s
echo -e "${GREEN}✓ Database is ready${NC}"
echo ""

# Initialize database with customer data
echo -e "${BLUE}[3.5/6] Initializing database with customer data...${NC}"
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
echo -e "${BLUE}[4/6] Storing database credentials in Vault...${NC}"

# Check if Vault is running
VAULT_POD=$(oc get pod -n ${VAULT_NS} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$VAULT_POD" ]]; then
    echo -e "${RED}ERROR: Vault not found in namespace ${VAULT_NS}${NC}"
    echo -e "${YELLOW}Please run ./setup-vault.sh first${NC}"
    exit 1
fi

VAULT_ADDR="http://vault.${VAULT_NS}.svc.cluster.local:8200"

# Store database credentials in Vault
oc exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv put secret/database/production \
  host="customer-database.${VULNERABLE_NS}.svc.cluster.local" \
  port="5432" \
  username="customerdb" \
  password="SuperSecret123!" \
  database="customers" \
  connection_string="postgresql://customerdb:SuperSecret123!@customer-database.${VULNERABLE_NS}.svc.cluster.local:5432/customers"

# Also store API keys and other sensitive data
oc exec -n ${VAULT_NS} ${VAULT_POD} -- vault kv put secret/api-keys/production \
  stripe_secret_key="sk_test_FAKE_1234567890abcdefghijk" \
  aws_access_key="AKIAIOSFODNN7EXAMPLE" \
  aws_secret_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" \
  sendgrid_api_key="SG.FAKE1234567890abcdefghijklmnop"

echo -e "${GREEN}✓ Database credentials stored in Vault${NC}"
echo ""

# Create vulnerable application with static Vault token
echo -e "${BLUE}[5/6] Deploying vulnerable payment processing application...${NC}"

# Create a 90-day Vault token
VAULT_TOKEN=$(oc exec -n ${VAULT_NS} ${VAULT_POD} -- vault token create \
  -policy=default \
  -ttl=2160h \
  -format=json | jq -r '.auth.client_token')

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
echo -e "${BLUE}[6/6] Waiting for application to be ready...${NC}"
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
