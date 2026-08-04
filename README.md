# ZTWIM Realistic Attack Demo

[![OpenShift](https://img.shields.io/badge/OpenShift-4.20%2B-red)](https://www.openshift.com/)
[![SPIFFE](https://img.shields.io/badge/SPIFFE-compliant-blue)](https://spiffe.io/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

**Interactive demonstration showing how ZTWIM (Zero Trust Workload Identity Manager) prevents credential theft attacks that would otherwise breach $1.2M+ in customer data.**

---

## 🎯 What This Demonstrates

**Part 1: Vulnerable Environment**
- Complete credential theft attack on production workload
- Static Vault token stolen from environment variables (90-day TTL)
- Database credentials compromised
- Customer data exfiltrated (credit cards, SSNs, $1.2M+ in accounts)
- Fraudulent transactions created
- Backdoor deployed for persistence

**Part 2: ZTWIM-Protected Environment**
- Same attack attempted against ZTWIM-protected workload
- Attack completely blocked (no static tokens to steal)
- Dynamic JWT-SVIDs with 2-minute expiry
- Side-by-side comparison: 90 days vs 2 minutes

---

## ⚡ Quick Start (30 minutes total)

```bash
# Clone the repository
git clone https://github.com/SeanRickerd/ztwim-vault-demo.git
cd ztwim-vault-demo/scripts

# 1. Setup vulnerable environment (5 minutes)
./setup-realistic-vulnerable-environment.sh

# 2. Setup ZTWIM-protected environment (2 minutes)
./setup-protected-ztwim-environment.sh

# 3. Run interactive demo (20-25 minutes)
./interactive-attack-demo.sh
# Press Enter at each blank $ prompt to advance
# Narrate using SPEAKER-NOTES.md

# 4. Cleanup (1 minute)
./cleanup-demo.sh
```

**That's it!** The demo is fully automated and repeatable.

---

## 📚 Documentation

**Essential Files:**

| File | Purpose |
|------|---------|
| **[START-HERE.md](START-HERE.md)** | Complete guide - start here! |
| **[SPEAKER-NOTES.md](SPEAKER-NOTES.md)** | What to say during the demo |
| **[DEMO-WORKFLOW.md](DEMO-WORKFLOW.md)** | Quick reference for presenters |
| **[CLEANUP-CHECKLIST.md](CLEANUP-CHECKLIST.md)** | Cleanup verification |

**Reference Files:**

| File | Purpose |
|------|---------|
| `INTERACTIVE-DEMO-README.md` | Detailed demo execution guide |
| `REALISTIC-DEMO-GUIDE.md` | Presenter guide with timing |
| `OPENSHIFT-SCC-GUIDE.md` | Troubleshooting permissions |

---

## 🎬 Demo Flow

### Setup (7 minutes before audience arrives)
1. Deploy vulnerable environment with Vault, database, and static tokens
2. Deploy ZTWIM-protected environment with dynamic credentials

### Presentation (20-25 minutes)
1. **Part 1** (15 min): Show complete breach of vulnerable environment
   - Steal credentials → Access Vault → Exfiltrate data → Commit fraud
2. **Part 2** (5-10 min): Show same attack blocked by ZTWIM
   - No static tokens → Attack fails → Show comparison table

### Cleanup (1 minute)
- Single script removes all demo resources
- Cluster returns to pre-demo state

---

## 💡 What Makes This Demo Powerful

✅ **Real commands** - No simulations, actual `oc exec`, `psql`, `curl`  
✅ **Real data** - Live PostgreSQL with 10 customers, $1.2M total  
✅ **Real impact** - Shows actual credential theft and fraud  
✅ **Interactive** - Pause at each step, control the pacing  
✅ **Dramatic** - Builds from discovery to $1.2M breach  
✅ **Before/After** - Side-by-side vulnerable vs. protected  
✅ **Repeatable** - Run on same cluster multiple times  

---

## 🛠️ Requirements

- OpenShift 4.x cluster (or Kubernetes with minor adjustments)
- `oc` CLI configured and authenticated
- Cluster-admin permissions (for SCC bindings)
- ~5 minutes of cluster time before demo

---

## 📊 Demo Statistics

- **Customer records:** 10 with PII (credit cards, SSNs)
- **Total at risk:** $1,238,652.75
- **Vulnerable token TTL:** 90 days (2,160 hours)
- **Protected token TTL:** 2 minutes (120 seconds)
- **Attack phases:** 7 (reconnaissance → persistence)
- **Time to breach:** ~5 minutes with stolen token

---

## 🎯 Key Differences Shown

| Aspect | Vulnerable | ZTWIM-Protected |
|--------|-----------|-----------------|
| Credential Type | Static token | Dynamic JWT-SVID |
| Token Lifetime | 90 days | 2 minutes |
| Storage | Environment variable | Unix socket |
| Rotation | Manual | Automatic |
| Exfiltration Risk | **CRITICAL** | **MINIMAL** |
| Attack Result | $1.2M breach | **Blocked** |

---

## 🔄 Repeatability

The demo is designed to be run multiple times on the same cluster:

```bash
# Run demo cycle as many times as needed
./setup-realistic-vulnerable-environment.sh
./setup-protected-ztwim-environment.sh
./interactive-attack-demo.sh
./cleanup-demo.sh

# Repeat immediately
./setup-realistic-vulnerable-environment.sh
...
```

Each cleanup returns the cluster to pre-demo state.

---

## 📁 Repository Structure

```
ztwim-vault-demo/
├── scripts/
│   ├── interactive-attack-demo.sh              # Main demo script
│   ├── setup-realistic-vulnerable-environment.sh
│   ├── setup-protected-ztwim-environment.sh
│   └── cleanup-demo.sh
├── START-HERE.md                               # Start here!
├── SPEAKER-NOTES.md                            # Narration guide
├── DEMO-WORKFLOW.md                            # Quick reference
├── CLEANUP-CHECKLIST.md                        # Cleanup verification
└── README.md                                   # This file
```

---

## 🤝 Contributing

This demo is maintained as an internal tool for demonstrating ZTWIM capabilities. Feedback and improvements welcome!

---

## 📝 License

Apache 2.0 - See [LICENSE](LICENSE) file for details.

---

## 🎓 Learn More

- **ZTWIM Documentation:** [Red Hat ZTWIM](https://access.redhat.com/documentation/en-us/red_hat_ztwim/)
- **SPIFFE/SPIRE:** [spiffe.io](https://spiffe.io/)
- **Zero Trust:** [NIST SP 800-207](https://www.nist.gov/publications/zero-trust-architecture)

---

**Ready to show the power of Zero Trust Workload Identity? Start with [START-HERE.md](START-HERE.md)!** 🚀
