# ZTWIM Demo Workflow - Quick Reference

## Pre-Demo Setup (5 minutes)

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./setup-realistic-vulnerable-environment.sh
```

**Verify:**
```bash
oc get pods -n production
# Should see: customer-database and payment-processor both Running
```

---

## Running the Demo (15-20 minutes)

```bash
./interactive-attack-demo.sh
```

**How it works:**
1. Output displays
2. Blank `$ ` prompt appears
3. **You press Enter** (no typing needed)
4. Command types out character-by-character
5. Command executes showing real output
6. **You narrate** what happened (see SPEAKER-NOTES.md)

**Key moments:**
- **Vault token discovery** - "Static token, 90-day validity"
- **Database credentials** - "Complete access to production database"
- **Customer data** ⚠️ - **Slow down, let them read, pause 5 seconds**
- **$1.2M total** - **Pause 3 seconds** - "Real money at risk"
- **Fraudulent transaction** ⚠️ - "This is a crime"
- **90-day persistence** - "They can come back tomorrow"

---

## Post-Demo Cleanup (1 minute)

```bash
./cleanup-demo.sh
```

This removes:
- `production` namespace (database + payment processor)
- `vault` namespace
- All temporary files

**Environment is ready for next demo.**

---

## Troubleshooting

### Pods not ready
```bash
oc get pods -n production -w
# Wait for both to show Running
```

### Demo script errors
```bash
# Get fresh pod name
POD=$(oc get pod -n production -l app=payment-processor -o jsonpath='{.items[0].metadata.name}')
echo $POD

# Test Vault access
oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/database/production | jq .'
```

### Need to restart
```bash
./cleanup-demo.sh
./setup-realistic-vulnerable-environment.sh
```

---

## Quick Stats for Talking Points

- **Customer records:** 10 
- **Total at risk:** $1,238,652.75
- **Token validity:** 90 days (2160 hours)
- **Attack phases:** 7 (recon → fraud → persistence)
- **Time to breach:** ~5 minutes with stolen token

---

## What Gets Demonstrated

✅ **Credential theft** - Static Vault token in environment variable  
✅ **Lateral movement** - Token works from anywhere  
✅ **Data exfiltration** - Customer PII, credit cards, SSNs  
✅ **Financial fraud** - Unauthorized transactions  
✅ **Persistence** - Backdoor deployment with 90-day access  

---

## Next Steps After Demo

1. **Transition:** "Now let me show you how ZTWIM prevents ALL of this..."
2. **Run ZTWIM demo:** Show short-lived credentials (2-minute JWTs)
3. **Compare:** Side-by-side before/after

---

**Files to have open during demo:**
- Terminal running `interactive-attack-demo.sh`
- Second screen with `SPEAKER-NOTES.md`
- This workflow guide for reference
