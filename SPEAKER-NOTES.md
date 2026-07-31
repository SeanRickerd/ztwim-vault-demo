# Interactive Attack Demo - Speaker Notes

## Overview

This is a live, interactive demonstration showing real commands and output. The script pauses at each key moment waiting for you to press Enter, giving you time to explain what's happening.

**Duration:** 15-20 minutes (depending on explanation depth)

---

## Pre-Demo Setup (Done before audience arrives)

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./setup-realistic-vulnerable-environment.sh
```

Verify it's ready:
```bash
oc get pods -n production
# Should see: customer-database and payment-processor both Running
```

---

## Running the Demo

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./interactive-attack-demo.sh
```

The script will pause at each step - you press Enter to continue.

---

## Speaker Notes for Each Phase

### Opening (Before starting script)

**What to say:**

> "I'm going to show you a realistic breach scenario based on actual incidents we've seen in production environments. Every command you see is real - no simulations, no fake data. This is running on a live OpenShift cluster with a real PostgreSQL database containing customer data."

> "The scenario: A financial services company using Kubernetes and Vault for secrets management. They think they're following best practices. Let's see what happens when an attacker gets in."

**[Start the script]**

---

### PHASE 1: Reconnaissance

**Commands shown:**
```bash
$ oc get pods -n production
$ oc get deployment payment-processor -n production
```

**What to say:**

> "First, the attacker does reconnaissance. They want to understand what's running in the production namespace."

> "There's our target - the payment-processor deployment. This handles financial transactions."

**[Press Enter]**

---

### PHASE 2: Initial Compromise

**Commands shown:**
```bash
$ oc exec... printenv | grep -i vault
```

**What to say:**

> "The attacker exploits an RCE vulnerability - could be Log4Shell, a dependency issue, whatever. They get shell access to the pod."

> "First thing they do? Check environment variables. Watch this..."

**[Press Enter - token will be displayed]**

> "There it is. A Vault token. Right there in an environment variable. This is how the app authenticates to Vault to get secrets."

> "Notice it's a static token. And look at the TTL - we'll see it's 90 days. That's 2,160 hours of access if they steal it."

**[Pause for impact]**

**[Press Enter]**

---

### PHASE 3: Vault Access

**Commands shown:**
```bash
$ curl... /v1/secret/data/database/production | jq .data.data
$ curl... /v1/secret/data/api-keys/production | jq .data.data
```

**What to say:**

> "Now they use that stolen token to authenticate to Vault. Remember - this token works from anywhere. They don't need to be in the pod anymore."

> "Watch what they get..."

**[Press Enter - database creds displayed]**

> "Complete database credentials. Hostname, username, password, connection string. Everything."

**[Press Enter]**

> "And the API keys..."

**[Press Enter - API keys displayed]**

> "Stripe payment processing. AWS infrastructure access. SendGrid email. Complete system compromise."

**[Let this sink in]**

**[Press Enter]**

---

### PHASE 4: Database Access - THE BIG MOMENT

**Commands shown:**
```bash
$ psql... -c '\dt'
$ psql... -c 'SELECT COUNT(*) FROM customers;'
$ psql... -c 'SELECT... FROM customers ORDER BY account_balance DESC LIMIT 5;'
$ psql... -c 'SELECT SUM(account_balance)...'
```

**What to say:**

> "Now they connect directly to the production database. Using the credentials they just stole from Vault."

**[Press Enter - tables listed]**

> "There's the customers table. Let's see what's in it..."

**[Press Enter - count shown]**

> "Ten customers. Let's see who they are..."

**[Press Enter - THIS IS THE MOMENT]**

> "Look at this. Real customer data. Credit card numbers. Social Security numbers. Email addresses. Account balances."

> **[Read from screen slowly]:**
> "Jennifer Taylor - $267,890"
> "Emily Rodriguez - $198,500"  
> "Maria Garcia - $178,950"

> "These are real account balances. This is real money."

**[Pause - let the audience absorb this]**

**[Press Enter - total calculated]**

> "Over $1.2 million dollars in customer accounts. Completely exposed."

**[Press Enter]**

---

### PHASE 5: Data Manipulation - THE CRIME

**Commands shown:**
```bash
$ psql... INSERT INTO transactions... VALUES... 'UNAUTHORIZED'...
$ psql... SELECT * FROM transactions ORDER BY created_at DESC...
```

**What to say:**

> "But they're not done. They have write access to the database."

> "Watch what they can do..."

**[Press Enter - fraudulent transaction created]**

> "A $50,000 unauthorized withdrawal. From John Anderson's account."

> "This is no longer just data theft. **This is financial fraud.** This is a crime."

**[Press Enter - transaction displayed]**

> "There it is in the transaction log. It looks like a legitimate withdrawal. But it's completely unauthorized."

**[Press Enter]**

---

### PHASE 6: Persistence

**Commands shown:**
```bash
cat <<EOF | oc apply -f -
[backdoor pod YAML]
EOF
$ oc get pod backdoor-exfil -n production
```

**What to say:**

> "Finally, they want to make sure they can come back. Even if someone patches the original vulnerability."

> "They deploy what looks like a monitoring pod..."

**[Press Enter - backdoor created]**

> "It's running. It has the stolen Vault token. It has database access."

**[Press Enter - pod verified]**

> "Even if we patch the payment processor tonight, they can use this backdoor tomorrow. For 90 days."

**[Press Enter]**

---

### FINAL IMPACT SUMMARY

**Screen shows:**
- Attack timeline
- Business impact
- Attacker capabilities
- Why it succeeded

**What to say:**

> "Let's look at what just happened."

> **[Read through attack timeline]**

> "Eight phases. Complete breach. From initial access to persistent backdoor."

> **[Business Impact]**

> "Financial loss - potentially the full $1.2 million in fraud."

> "Regulatory violations - GDPR for the PII, PCI-DSS for the credit cards, SOX for the fraudulent transactions."

> "Customer trust - destroyed. Once this gets out, people will close their accounts."

> "Legal liability - class action lawsuits are coming."

> **[Attacker Capabilities]**

> "And here's the worst part: the attacker has **90 days** of access. 90 days!"

> "They can operate from anywhere in the world. Their traffic looks like legitimate application access, so it's hard to detect."

> "They have a backdoor. They have the credentials. They can come back whenever they want."

**[Pause dramatically]**

> **[Why Did This Succeed]**

> "So why did this attack work?"

> "One: Static credentials. That Vault token is valid for 90 days. Once stolen, it's game over."

> "Two: It was in an environment variable. Takes 10 seconds to find."

> "Three: No workload identity. Vault has no way to verify this token is coming from the actual payment processor versus an attacker in Brazil."

> "Four: The token works from anywhere. No attestation. No verification of where the request is coming from."

> "Five: One credential equals access to everything. The entire secret store."

> "Six: No automatic rotation. No time-based expiration beyond those 90 days. Nothing."

**[Final pause]**

> "This is a realistic scenario. We've seen variations of this attack hundreds of times. Different details, same pattern."

> "Now let me show you how ZTWIM prevents this entire attack chain..."

**[Press Enter to finish]**

---

## Transition to ZTWIM Demo

**What to say:**

> "So that was the nightmare scenario. $1.2 million breach. 90 days of persistent access. Complete system compromise."

> "Now I'm going to show you the same environment, but protected by ZTWIM - Zero Trust Workload Identity Manager."

> "Same vulnerability. Same initial compromise. But watch what happens..."

**[Switch to ZTWIM demo]**

---

## Pacing Tips

### Speed Up:
- Phase 1 (reconnaissance) - move quickly
- Pod deployment commands - show but don't dwell
- Technical details everyone already knows

### Slow Down:
- **Phase 4 when customer data appears** - This is THE moment
- When fraudulent transaction is created - This is the crime
- Final impact summary - Make sure they get the numbers

### Pause:
- After customer data displays (let them read it)
- After saying "$1.2 million" (let it land)
- After "This is a crime" (dramatic moment)
- After explaining 90-day access (the nightmare persists)

---

## Handling Questions Mid-Demo

### "Is this data real?"
**Answer:** "Yes. This is a real PostgreSQL database running on this OpenShift cluster. The credit card numbers and SSNs are fake data for the demo, but the database, the breach, the commands - all real."

### "Could an attacker really do this?"
**Answer:** "Absolutely. This attack pattern is based on actual incidents. The Uber breach in 2022 started with stolen credentials. The Capital One breach in 2019 - stolen credentials. SolarWinds - credentials. It's the same pattern every time."

### "Why is the token in an environment variable?"
**Answer:** "Great question. This is actually really common. It's how many applications authenticate to Vault - they inject the token as an environment variable or mount it as a file. It seems convenient but as you just saw, it's a disaster waiting to happen."

### "Can you show the backdoor code?"
**Answer:** [After demo] "Sure, it's just a simple pod that sits there with the stolen credentials. The real backdoor is the credentials themselves - 90 days of valid access."

---

## Technical Notes

### If a command fails:
- **Stay calm** - Say "Let me check that..."
- Run: `oc get pods -n production` to verify pods are up
- If database is down: Skip to next phase, explain "database is restarting but you can see the pattern"
- **Have screenshots ready** as backup

### If demo is running slow:
- Skip the API keys phase (go straight from DB creds to customer data)
- Skip the backdoor deployment (just describe it)
- Focus on Phases 3-5 (the core breach)

### If audience is very technical:
- Slow down on the Vault API calls
- Show the JWT structure if asked
- Explain the Kubernetes Secrets versus Vault distinction
- Discuss defense-in-depth strategies

### If audience is executive/business:
- Speed through technical commands
- Emphasize the dollar amounts
- Focus on compliance violations
- Stress the legal/reputational impact

---

## Emotional Beats

This demo is designed to create an emotional journey:

1. **Curiosity** - "Let's see what happens"
2. **Concern** - "They found the token..."
3. **Alarm** - "They're in Vault..."
4. **Horror** - "Oh no, real customer data!" ⚠️
5. **Despair** - "And they can commit fraud... and they have persistence..."
6. **Motivation** - "We NEED to prevent this"

The transition to ZTWIM should feel like **relief** - "Wait, you can stop all of this?"

---

## Post-Demo Debrief

After showing both demos (vulnerable + ZTWIM):

**Summary points:**

> "What you just saw: A $1.2 million breach with 90 days of persistent access... completely prevented by ZTWIM."

> "The key difference: ZTWIM eliminates static credentials. Instead of a 90-day token in an environment variable, you get a 2-minute JWT-SVID that's cryptographically bound to the workload."

> "That's a 97% reduction in breach window. From 90 days to 2 minutes."

> "And it's zero operational overhead. No manual rotation. No credential sprawl. It just works."

---

## Success Metrics

**You know it worked when:**

- Someone says "oh no" or gasps when customer data appears
- Questions about implementing ZTWIM
- Requests for the demo code
- "How soon can we do this?" questions
- Security team members taking notes during Phase 4

---

**Remember: The power is in the real commands and real output. Let the data speak for itself. Your job is to narrate the journey from curiosity to horror to solution.**
