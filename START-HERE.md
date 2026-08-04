# ZTWIM Realistic Attack Demo - START HERE

## 🚀 Three Steps to Run the Demo

```bash
cd /ztwim-vault-demo/scripts

# Step 1: Setup (7 minutes)
./setup-realistic-vulnerable-environment.sh  # 5 min - Vault + DB + vulnerable app
./setup-protected-ztwim-environment.sh       # 2 min - ZTWIM-protected app

# Step 2: Run Demo (20-25 minutes)
./interactive-attack-demo.sh
# Press Enter at each blank $ prompt
# Narrate using SPEAKER-NOTES.md

# Step 3: Cleanup (1 minute)
./cleanup-demo.sh  # Removes everything, cluster returns to pre-demo state
```

**That's it! Demo is ready to run.** 🎯

---

## Quick Start

### For Live Presentation:

```bash
# 1. Setup (before audience arrives - 7 minutes)
cd /ztwim-vault-demo/scripts

# Deploy vulnerable environment (5 min)
./setup-realistic-vulnerable-environment.sh

# Deploy ZTWIM-protected environment (2 min)
./setup-protected-ztwim-environment.sh

# 2. Run interactive demo (20-25 minutes)
./interactive-attack-demo.sh

# 3. Read speaker notes while demo runs
cat /ztwim-vault-demo/SPEAKER-NOTES.md
```

---

## What's In This Demo

This is a **realistic credential theft attack demonstration** showing:

- Real commands executed on live OpenShift cluster
- Real PostgreSQL database with customer data
- Real credential theft and data breach
- $1.2M+ in customer accounts exposed
- Fraudulent transactions created
- Complete attack chain from reconnaissance to persistence

**Interactive format:** Script pauses at each step, you press Enter to continue

---

## File Guide

### Main Files (Use These):

| File | Purpose |
|------|---------|
| **`INTERACTIVE-DEMO-README.md`** | Quick start guide for the demo |
| **`SPEAKER-NOTES.md`** | What to say during each phase |
| **`REALISTIC-DEMO-GUIDE.md`** | Detailed presenter guide with timing |
| **`DEMO-QUICK-REFERENCE.md`** | One-page cheat sheet |

### Scripts (In `scripts/` directory):

| Script | Purpose |
|--------|---------|
| **`interactive-attack-demo.sh`** | 🎯 **Main demo script - includes vulnerable & protected!** |
| **`setup-realistic-vulnerable-environment.sh`** | Setup vulnerable environment (Vault + DB + app) |
| **`setup-protected-ztwim-environment.sh`** | Setup ZTWIM-protected environment |
| **`cleanup-demo.sh`** | 🧹 **Cleanup after demo - removes all resources** |
| **`setup-ztwim.sh`** | Legacy ZTWIM setup (use protected setup instead) |
| **`test-demo-environment.sh`** | Verify environment is ready |

### Reference Files:

| File | Purpose |
|------|---------|
| `OPENSHIFT-SCC-GUIDE.md` | Troubleshooting OpenShift permissions |
| `REALISTIC-DEMO-CHANGES.md` | What changed from original demo |
| `README.md` | Original repo README |

### Archive:

Old/duplicate files moved to `archive/` directory - ignore these.

---

## Demo Flow (20-25 minutes)

### Part 1: Vulnerable Attack (15 minutes)
1. **Phase 1: Reconnaissance** (2 min) - Find the target
2. **Phase 2: Initial Compromise** (2 min) - Discover Vault token
3. **Phase 3: Vault Access** (3 min) - Steal DB creds & API keys
4. **Phase 4: Database Breach** (5 min) ⚠️ **THE BIG MOMENT** - $1.2M exposed
5. **Phase 5: Fraud** (3 min) ⚠️ **THE CRIME** - Unauthorized transaction
6. **Phase 6: Persistence** (2 min) - Deploy backdoor
7. **Summary** (1 min) - Impact assessment

### Part 2: ZTWIM Protection (5-10 minutes)
8. **Transition** - "Now let's see ZTWIM prevention..."
9. **Attack Attempt** - Same attack against protected workload
10. **Attack Fails** - No static tokens to steal
11. **Comparison** - Side-by-side: 90 days vs 2 minutes
12. **Conclusion** - Same attack completely blocked

---

## Quick Commands

```bash
# Setup
cd /ztwim-vault-demo/scripts
./setup-realistic-vulnerable-environment.sh

# Verify ready
oc get pods -n production
# Should see: customer-database and payment-processor Running

# Run demo
./interactive-attack-demo.sh

# Cleanup after
./cleanup-demo.sh
```

---

## What Makes This Demo Powerful

✅ **Real commands** - Actual `oc exec`, `psql`, `curl` - no simulations  
✅ **Real data** - Live PostgreSQL with customer records  
✅ **Real impact** - $1,238,652.75 in account balances at risk  
✅ **Interactive** - Pause at each step, you control the pace  
✅ **Dramatic** - Builds from discovery to massive breach  

---

## Files You Need

**Before demo:**
- Read: `SPEAKER-NOTES.md`
- Reference: `INTERACTIVE-DEMO-README.md`

**During demo:**
- Run: `scripts/interactive-attack-demo.sh`
- Have open: `SPEAKER-NOTES.md` (second screen)

**After demo:**
- Share: GitHub repo link
- Reference: `DEMO-QUICK-REFERENCE.md` for Q&A

---

## GitHub Repository

https://github.com/SeanRickerd/ztwim-vault-demo

---

## Success Formula

1. **Setup** before audience arrives
2. **Run** `interactive-attack-demo.sh`
3. **Follow** speaker notes for pacing
4. **Pause** at key moments (customer data, fraud)
5. **Transition** to ZTWIM prevention demo

**The emotional journey:** Curious → Concerned → Alarmed → **Horrified** → Motivated to fix

---

**Ready to make them say "oh no..." ? Let's go!** 🎯
