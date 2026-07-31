# ZTWIM Realistic Demo - Quick Reference Card

## Pre-Demo (15 min before)

```bash
# 1. Navigate to demo directory
cd /home/srickerd/ztwim-vault-demo/scripts

# 2. Deploy realistic vulnerable environment
./setup-realistic-vulnerable-environment.sh

# 3. Verify setup succeeded
oc get pods -n production
# Should see: customer-database and payment-processor Running

# 4. Test attack script (optional)
./demo-realistic-attack.sh
# Press Ctrl+C after Phase 1 to stop early test
```

---

## Demo Flow (20 minutes)

### Part 1: The Breach (12 min)

**Run:**
```bash
./demo-realistic-attack.sh
```

**Key Moments:**

| Phase | Duration | What Happens | Talking Point |
|-------|----------|--------------|---------------|
| 1 | 1 min | RCE → Shell access | "Vulnerabilities happen" |
| 2 | 1 min | Token theft | "90-day token in env var" |
| 3 | 2 min | DB creds from Vault | "Operating from anywhere" |
| 4 | 2 min | **Customer data** | **"$1.2M exposed"** ⚠️ |
| 5 | 1 min | API keys stolen | "Stripe, AWS, SendGrid" |
| 6 | 2 min | **Fraudulent transaction** | **"This is a crime"** ⚠️ |
| 7 | 2 min | Backdoor deployment | "90 days of access" |
| Summary | 1 min | Impact review | "Complete breach" |

### Part 2: ZTWIM Protection (5 min)

**Run:**
```bash
./demo-scenario-2-attack.sh
```

**Key Message:**
- Steps 1-2: Same (can't prevent all vulns)
- Steps 3-7: **ALL BLOCKED** ✅
- 97% reduction in breach window

### Part 3: Wrap Up (3 min)

**Key Takeaways:**
1. From $1.2M breach → $0 impact
2. From 90 days → 2 minutes
3. Defense-in-depth that actually works

---

## The "Oh No" Moments

### Moment 1: Customer Data (Phase 4)
```
TOP 5 CUSTOMER ACCOUNTS EXFILTRATED:
{
  "customer_name": "Jennifer Taylor",
  "account_balance": "267890.00",
  "credit_card": "4532-7777-8888-9999",
  "ssn": "678-90-1234"
}
```

**Pause here. Let it sink in.**

### Moment 2: Fraud Transaction (Phase 6)
```
id |  amount   | transaction_type | description          
---+-----------+------------------+----------------------
 1 | -50000.00 | withdrawal       | UNAUTHORIZED - Attacker...
```

**Say:** "This is no longer data theft. This is financial fraud."

---

## If Something Breaks

### Database not ready?
```bash
oc get pods -n production -w
# Wait for customer-database to show Running
```

### Script fails mid-attack?
```bash
# Check environment
cat /tmp/demo-tokens/vault-addr.txt

# Re-run setup if needed
./setup-realistic-vulnerable-environment.sh
```

### Demo pod missing?
```bash
oc get pods -n production
# Should see payment-processor-xxxxx
```

---

## Cleanup After Demo

```bash
# Remove all demo resources
oc delete namespace production

# Clean tokens
rm -rf /tmp/demo-tokens
```

---

## Key Statistics to Memorize

- **$1,238,652.75** - Total customer account value at risk
- **10 customers** - Number of PII records exposed
- **90 days** - Static token lifetime
- **2 minutes** - JWT-SVID lifetime with ZTWIM
- **97%** - Reduction in breach window
- **7 phases** - Complete attack chain
- **100%** - Attack vectors blocked by ZTWIM

---

## Talking Points Cheat Sheet

### Why It Matters
> "One compromised pod. One stolen token. $1.2 million breach. This is based on actual incidents."

### The Theft
> "The token is in an environment variable. They copy it out. It works from anywhere. For 90 days."

### The Data
> "These are real customer accounts. Real money. This is Jennifer Taylor's $267,890 account."

### The Fraud
> "$50,000 unauthorized withdrawal. This isn't just a leak anymore. This is a crime."

### The Persistence
> "They deploy a backdoor. Even if you patch tonight, they come back tomorrow. For 90 days."

### ZTWIM Solution
> "No static secrets. 2-minute expiration. Workload attestation. The entire attack chain is broken."

### Business Impact
> "97% reduction in breach window. Zero static secrets to manage. Compliance-ready dynamic credentials."

---

## Emergency Backup (If Demo Fails)

**Have ready:**
1. Screenshots of customer data output
2. Screenshot of fraudulent transaction
3. Screenshot of ZTWIM blocking attacks

**Fallback script:**
> "Let me walk you through what would happen..." 
> [Use screenshots and explain the flow]

---

## Opening Hook Options

### Option 1: Question
> "How many of you have Kubernetes Secrets in production? Keep your hands up if they've been there for more than 90 days. Congratulations - you have the same vulnerability I'm about to demonstrate."

### Option 2: Story
> "Last year, a financial services company lost $1.2 million in a breach that started with one stolen token. I'm going to show you exactly how it happened."

### Option 3: Direct
> "I'm going to steal $1.2 million in customer funds, commit fraud, and deploy a backdoor. Then I'll show you how to prevent all of it. 20 minutes."

---

## Closing Options

### Option 1: Call to Action
> "ZTWIM is available now on OpenShift. The question is: will you implement it before or after your breach?"

### Option 2: Comparison
> "You just saw the difference between 'We follow best practices' and 'We implement zero-trust.' One costs $1.2 million. One costs nothing."

### Option 3: Practical
> "This demo environment is on GitHub. You can run it in your cluster tomorrow. Start with one app. Prove the value. Then expand."

---

## Time Markers

- **T-15 min:** Start setup
- **T-5 min:** Verify setup complete
- **T-0 min:** Start presentation
- **T+2 min:** Into attack demo
- **T+14 min:** Start ZTWIM demo
- **T+19 min:** Wrap-up
- **T+20 min:** Q&A

---

## Success Checklist

Before going on stage:

- [ ] OpenShift cluster accessible
- [ ] Vault deployed and healthy
- [ ] Setup script completed successfully
- [ ] Can see customer-database pod Running
- [ ] Can see payment-processor pod Running
- [ ] Terminal font size readable
- [ ] Color support enabled
- [ ] Backup screenshots ready
- [ ] Water nearby
- [ ] Deep breath taken

---

## Post-Demo Follow-Up

**If they're interested:**

1. Share GitHub repo: https://github.com/SeanRickerd/ztwim-vault-demo
2. Offer to run it in their environment
3. Connect them to Red Hat ZTWIM team
4. Schedule architecture discussion
5. Provide ROI calculation template

**Immediate asks you'll get:**
- "Can I get the code?" → Yes, GitHub
- "How do we implement this?" → Start with one app
- "What's the cost?" → Included with OpenShift
- "How long to migrate?" → Depends on app count, but can start tomorrow

---

**Good luck! Make them feel the breach, then show them the solution.** 🎯
