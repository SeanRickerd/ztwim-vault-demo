# Interactive Attack Demo - Quick Start

## What This Is

An interactive, presenter-friendly demo that shows **real commands and real output** from a live credential theft attack. The script pauses at each step, waiting for you to press Enter, giving you time to explain what's happening to your audience.

## Key Features

✅ **Real commands** - No simulations, actual `oc exec`, `psql`, `curl` commands  
✅ **Real output** - Live data from PostgreSQL, Vault, and OpenShift  
✅ **Interactive pacing** - Press Enter to advance, take your time explaining  
✅ **Dramatic progression** - Builds from discovery to $1.2M breach to fraud  
✅ **Presenter-friendly** - Colors, clear sections, easy to follow  

---

## Quick Start

### 1. Setup (Before your presentation)

```bash
cd /home/srickerd/ztwim-vault-demo/scripts

# Deploy the vulnerable environment
./setup-realistic-vulnerable-environment.sh

# Verify it's ready
oc get pods -n production
# Should see: customer-database and payment-processor both Running
```

**Time:** 5 minutes

---

### 2. Run the Demo

```bash
cd /home/srickerd/ztwim-vault-demo/scripts

# Start the interactive demo
./interactive-attack-demo.sh
```

**What happens:**
- Script shows a command
- You press Enter
- Script runs the command and shows real output
- You explain what's happening
- Repeat

**Duration:** 15-20 minutes (depending on your explanations)

---

### 3. Read Your Speaker Notes

Open this in a second terminal or print it out:

```bash
cat /home/srickerd/ztwim-vault-demo/SPEAKER-NOTES.md
```

This has:
- What to say at each phase
- Pacing tips (when to slow down, when to pause)
- How to handle questions
- Emotional beats for maximum impact

---

## Demo Flow

### Phase 1: Reconnaissance (2 min)
**What they see:**
```bash
$ oc get pods -n production
$ oc get deployment payment-processor -n production
```

**What you say:** "Attacker does reconnaissance, identifies the payment processor"

---

### Phase 2: Initial Compromise (2 min)
**What they see:**
```bash
$ oc exec... printenv | grep -i vault
VAULT_TOKEN=hvs.CAES...
VAULT_ADDR=http://vault...
```

**What you say:** "RCE vulnerability, shell access, discovers Vault token in environment"

---

### Phase 3: Vault Access (3 min)
**What they see:**
```bash
$ curl... /v1/secret/data/database/production
{
  "host": "customer-database...",
  "password": "SuperSecret123!",
  "username": "customerdb",
  ...
}

$ curl... /v1/secret/data/api-keys/production
{
  "stripe_secret_key": "sk_live_...",
  "aws_access_key": "AKIAI...",
  ...
}
```

**What you say:** "Using stolen token, accesses database creds and API keys from Vault"

---

### Phase 4: Database Breach (5 min) ⚠️ **THE BIG MOMENT**
**What they see:**
```bash
$ psql... SELECT customer_name, account_balance, credit_card, ssn FROM customers...

  customer_name  | account_balance | credit_card         | ssn
-----------------+-----------------+---------------------+-------------
 Jennifer Taylor |       267890.00 | 4532-7777-8888-9999 | 678-90-1234
 Emily Rodriguez |       198500.00 | 4024-1111-2222-3333 | 456-78-9012
 ...

$ psql... SELECT SUM(account_balance)...
   total_at_risk   
-------------------
      1238652.75
```

**What you say:** "Real customer data. Real money. $1.2 million exposed."

**⚠️ PAUSE HERE - Let this sink in**

---

### Phase 5: Fraud (3 min) ⚠️ **THE CRIME**
**What they see:**
```bash
$ psql... INSERT INTO transactions... 'UNAUTHORIZED - Attacker controlled'...
 id | customer_id |  amount   | transaction_type | description
----+-------------+-----------+------------------+-------------
  1 |           1 | -50000.00 | withdrawal       | UNAUTHORIZED...
```

**What you say:** "Not just data theft. Financial fraud. A crime."

---

### Phase 6: Persistence (2 min)
**What they see:**
```bash
$ oc apply -f [backdoor pod]
pod/backdoor-exfil created

$ oc get pod backdoor-exfil -n production
NAME             READY   STATUS    RESTARTS   AGE
backdoor-exfil   1/1     Running   0          5s
```

**What you say:** "Backdoor deployed. 90 days of access. Even if you patch tonight, they come back tomorrow."

---

### Final Impact Summary (3 min)
**What they see:**
```
ATTACK TIMELINE COMPLETE:
  ✓ Phase 1: Reconnaissance
  ✓ Phase 2: Shell access
  ✓ Phase 3: Vault token stolen
  ...
  ✓ Phase 8: Backdoor deployed

BUSINESS IMPACT:
  ✗ Financial Loss: $1.2M+
  ✗ Compliance: GDPR, PCI-DSS, SOX
  ✗ Reputation: Customer trust destroyed
  ...

ATTACKER CAPABILITIES:
  ✗ Access valid for: 90 DAYS
  ✗ Can operate from: Anywhere
  ...
```

**What you say:** "Complete breach. And the attacker has 90 days. Now let me show you how ZTWIM prevents ALL of this..."

---

## Files You Have

| File | Purpose |
|------|---------|
| `interactive-attack-demo.sh` | The main demo script (run this) |
| `SPEAKER-NOTES.md` | What to say at each step |
| `INTERACTIVE-DEMO-README.md` | This file - quick reference |
| `setup-realistic-vulnerable-environment.sh` | Setup script (run before demo) |

---

## The "Oh No" Moments

Design your pacing around these key emotional beats:

1. **Token discovery** - "Oh, it's in plain text..."
2. **Database credentials** - "Oh, they got everything..."
3. **Customer data display** ⚠️ - **"OH NO, real people, real money!"**
4. **Fraudulent transaction** ⚠️ - **"OH NO, that's a crime!"**
5. **90-day persistence** - "Oh god, 90 days..."

The audience should go from curious → concerned → alarmed → horrified → motivated

---

## Technical Requirements

- OpenShift cluster with cluster-admin access
- Terminal with ANSI color support
- ~100 column width (for table display)
- Second screen/laptop for speaker notes (optional but helpful)

---

## Cleanup After Demo

```bash
# Remove demo resources
oc delete namespace production

# Clean up tokens
rm -rf /tmp/demo-tokens

# Keep Vault for next demo (or delete it)
oc delete namespace vault
```

---

## Pro Tips

### Before Starting:
- [ ] Test the demo once privately
- [ ] Have speaker notes open on second screen
- [ ] Verify database has data: `oc exec -n production <pod> -- psql... -c 'SELECT COUNT(*) FROM customers;'`
- [ ] Terminal font size readable from back of room
- [ ] Water nearby (you'll be talking a lot)

### During Demo:
- **Slow down** when customer data appears (let them read it)
- **Pause** after saying "$1.2 million" (let it land)
- **Emphasize** "This is a crime" (not just data theft)
- **Make eye contact** during key moments (not looking at screen)

### If Something Breaks:
- Stay calm: "Let me check that pod status..."
- Have screenshots ready as backup
- Skip to next phase if needed
- Focus on the narrative, not the commands

---

## Success Indicators

You know the demo worked when:

✅ Someone gasps or says "oh no" during Phase 4  
✅ Questions about ZTWIM implementation timeline  
✅ Requests for demo code/GitHub repo  
✅ Security team taking notes  
✅ "How soon can we do this?" questions  
✅ Budget/ROI questions (they're sold, now they're buying)  

---

## Next Steps After Demo

When they ask (and they will):

**"Can I get the code?"**
→ "Yes, it's on GitHub: https://github.com/SeanRickerd/ztwim-vault-demo"

**"How do we implement ZTWIM?"**
→ "Start with one app, prove the value, then expand. I can help you set up a POC."

**"What's the cost?"**
→ "ZTWIM is included with OpenShift. No additional licensing."

**"How long to migrate?"**
→ "Depends on app count, but you can start tomorrow with a pilot."

---

## The Bottom Line

**Old approach:** "Here's a PowerPoint about credential theft"

**Your approach:** "Here's $1.2M of customer funds being stolen in real-time. Watch."

**Impact:** 🚀🚀🚀

---

**You're ready! Run the demo, follow the speaker notes, and make them feel the breach.** 🎯
