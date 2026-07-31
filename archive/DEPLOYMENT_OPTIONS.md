# Secrets Manager Deployment Options

This demo supports multiple secrets management backends. Choose the one that fits your needs.

## Supported Backends

### 1. OpenBao (Recommended)

**What is OpenBao?**
- Open-source fork of HashiCorp Vault
- 100% API-compatible with Vault
- True open-source (MPL 2.0 license)
- Community-governed via Linux Foundation
- No licensing restrictions

**Why OpenBao?**
- ✅ Fully compatible with Vault APIs and tools
- ✅ True open-source, community-driven
- ✅ No vendor lock-in
- ✅ Active development and community support
- ✅ Works with all Vault tutorials and documentation

**When to use:**
- New deployments
- Open-source preference
- Want to avoid potential licensing changes
- Community-driven governance preferred

**Deployment:**
```bash
export VAULT_TYPE="openbao"
./scripts/deploy-vault.sh
```

---

### 2. HashiCorp Vault

**What is Vault?**
- Industry-standard secrets management
- Enterprise features available
- Extensive ecosystem
- Commercial support from HashiCorp

**Why Vault?**
- ✅ Industry standard
- ✅ Extensive documentation
- ✅ Large ecosystem
- ✅ Enterprise support available
- ✅ Advanced features (HSM, DR replication, etc.)

**When to use:**
- Existing Vault deployments
- Enterprise support required
- Advanced features needed (Enterprise)
- HashiCorp partnership

**Deployment:**
```bash
export VAULT_TYPE="vault"
./scripts/deploy-vault.sh
```

---

## Quick Deployment

### Auto-Detect (Easiest)

The demo can auto-detect the best option for your environment:

```bash
./scripts/setup-secrets-manager.sh
```

This will:
1. Check if OpenBao image is available
2. Use OpenBao if available, otherwise Vault
3. Deploy and configure automatically

### Manual Selection

```bash
# OpenBao
export VAULT_TYPE="openbao"
./scripts/deploy-vault.sh

# OR HashiCorp Vault
export VAULT_TYPE="vault"
./scripts/deploy-vault.sh
```

---

## Feature Comparison

| Feature | OpenBao | Vault CE | Vault Enterprise |
|---------|---------|----------|------------------|
| **Secrets Management** | ✅ | ✅ | ✅ |
| **KV Secrets Engine** | ✅ | ✅ | ✅ |
| **JWT/OIDC Auth** | ✅ | ✅ | ✅ |
| **Kubernetes Auth** | ✅ | ✅ | ✅ |
| **SPIFFE/SPIRE Integration** | ✅ | ✅ | ✅ |
| **License** | MPL 2.0 | BSL 1.1 | Commercial |
| **Cost** | Free | Free | Paid |
| **Community Governance** | ✅ | ❌ | ❌ |
| **HSM Support** | ✅ | ❌ | ✅ |
| **DR Replication** | 🔄 | ❌ | ✅ |
| **Performance Replication** | 🔄 | ❌ | ✅ |
| **Namespaces** | 🔄 | ❌ | ✅ |
| **Sentinel Policies** | ❌ | ❌ | ✅ |

Legend:
- ✅ Available
- ❌ Not available
- 🔄 In development

---

## CLI Tools

### OpenBao

**Native command:**
```bash
bao <command>
```

**Vault compatibility:**
```bash
# OpenBao provides 'vault' command for compatibility
vault <command>
```

**Environment variables:**
```bash
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'

# OR for compatibility
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
```

### Vault

**Command:**
```bash
vault <command>
```

**Environment variables:**
```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
```

---

## API Compatibility

Both OpenBao and Vault use the same API endpoints:

```bash
# Create secret (works with both)
curl -X POST \
  -H "X-Vault-Token: root" \
  -d '{"data": {"password": "secret123"}}' \
  http://localhost:8200/v1/secret/data/myapp/config

# Read secret (works with both)
curl -H "X-Vault-Token: root" \
  http://localhost:8200/v1/secret/data/myapp/config

# JWT authentication (works with both)
curl -X POST \
  -d '{"jwt": "<token>", "role": "my-role"}' \
  http://localhost:8200/v1/auth/jwt/login
```

---

## Migration Between OpenBao and Vault

Since OpenBao and Vault are API-compatible, you can easily migrate:

### Vault to OpenBao

```bash
# 1. Backup Vault data
vault operator raft snapshot save backup.snap

# 2. Deploy OpenBao
export VAULT_TYPE="openbao"
./scripts/deploy-vault.sh

# 3. Restore to OpenBao
bao operator raft snapshot restore backup.snap

# 4. Unseal and verify
bao operator unseal
bao kv list secret/
```

### OpenBao to Vault

```bash
# 1. Backup OpenBao data
bao operator raft snapshot save backup.snap

# 2. Deploy Vault
export VAULT_TYPE="vault"
./scripts/deploy-vault.sh

# 3. Restore to Vault
vault operator raft snapshot restore backup.snap

# 4. Unseal and verify
vault operator unseal
vault kv list secret/
```

---

## Demo Compatibility

This ZTWIM demo works identically with both:

| Demo Component | OpenBao | Vault |
|----------------|---------|-------|
| Scenario 1 (vulnerable) | ✅ | ✅ |
| Scenario 2 (protected) | ✅ | ✅ |
| Kubernetes Auth | ✅ | ✅ |
| JWT/OIDC Auth | ✅ | ✅ |
| SPIRE Integration | ✅ | ✅ |
| Attack Scripts | ✅ | ✅ |
| Setup Scripts | ✅ | ✅ |

**No code changes needed** - the demo detects which backend is deployed and uses the correct CLI commands.

---

## Production Considerations

### For Production Deployments

**OpenBao:**
```bash
# Use Helm chart
helm repo add openbao https://openbao.github.io/openbao-helm
helm install openbao openbao/openbao \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3

# Or use operator
kubectl apply -f https://github.com/openbao/openbao-operator/releases/latest/download/install.yaml
```

**Vault:**
```bash
# Use Helm chart
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3

# Or use operator (Enterprise)
kubectl apply -f https://github.com/hashicorp/vault-k8s/releases/latest/download/vault-operator.yaml
```

### High Availability

Both support:
- Integrated storage (Raft)
- External storage (Consul, etcd)
- Auto-unsealing (Cloud KMS)
- TLS/mTLS

Example HA configuration:
```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
```

---

## Troubleshooting

### OpenBao Image Pull Issues

If OpenBao image fails to pull:
```bash
# Try different registry
kubectl set image deployment/openbao \
  openbao=docker.io/openbao/openbao:2.0.1 \
  -n vault

# Or use Vault instead
export VAULT_TYPE="vault"
./scripts/deploy-vault.sh
```

### Command Not Found

If `bao` command not found in scripts:
```bash
# OpenBao provides vault compatibility
alias bao=vault

# Or install OpenBao CLI
curl -fsSL https://openbao.org/install.sh | sh
```

### API Compatibility Issues

Both use Vault API spec:
```bash
# If you encounter issues, check API version
curl http://localhost:8200/v1/sys/health

# OpenBao response includes:
# "version": "2.0.1"

# Vault response includes:
# "version": "1.18.0"
```

---

## Resources

### OpenBao

- **Website:** https://openbao.org
- **GitHub:** https://github.com/openbao/openbao
- **Docs:** https://openbao.org/docs
- **Community:** https://github.com/openbao/openbao/discussions
- **Slack:** https://openbao.org/community

### Vault

- **Website:** https://www.vaultproject.io
- **GitHub:** https://github.com/hashicorp/vault
- **Docs:** https://developer.hashicorp.com/vault
- **Community:** https://discuss.hashicorp.com/c/vault
- **Learn:** https://learn.hashicorp.com/vault

---

## Recommendation for This Demo

**Use OpenBao** unless you:
- Already have Vault deployed
- Need specific Vault Enterprise features
- Have existing HashiCorp support contracts

The demo works identically with both, but OpenBao provides:
- True open-source governance
- No licensing concerns
- Community-driven development
- 100% Vault compatibility

---

## Quick Reference

### Deployment Commands

```bash
# Auto-detect
./scripts/setup-secrets-manager.sh

# OpenBao explicit
export VAULT_TYPE="openbao"
./scripts/deploy-vault.sh

# Vault explicit
export VAULT_TYPE="vault"
./scripts/deploy-vault.sh
```

### Access

```bash
# Port-forward (both)
kubectl port-forward -n vault svc/openbao 8200:8200
# OR
kubectl port-forward -n vault svc/vault 8200:8200

# UI
open http://localhost:8200
# Token: root

# CLI (OpenBao)
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'
bao kv get secret/payment/database

# CLI (Vault)
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
vault kv get secret/payment/database
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n vault

# Check which type is deployed
if kubectl get svc -n vault openbao >/dev/null 2>&1; then
  echo "OpenBao is deployed"
else
  echo "Vault is deployed"
fi

# Test API
curl http://localhost:8200/v1/sys/health
```

---

**Bottom Line:** Both work perfectly for this demo. Choose OpenBao for open-source benefits, or Vault if you have existing HashiCorp infrastructure.
