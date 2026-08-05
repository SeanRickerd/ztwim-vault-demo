# Interactive Attack Demo - Speaker Notes

## Overview

This is a **pure terminal session** with typing animation. Commands type out character-by-character like someone is manually typing them.

**Duration:** 15-20 minutes

---

## How It Works

1. **Output displays**
2. **Blank `[ATTACKER] $ ` prompt appears**
3. **You press Enter** (silently)
4. **Command types out** character-by-character
5. **Command executes** and shows real output
6. **You narrate** what just happened

**Note:** The `[ATTACKER]` prefix makes it clear these are commands run by a malicious actor.

**No commentary in the script - just commands and output. You provide all narration.**

---

## Running the Demo

```bash
cd ztwim-vault-demo/scripts
./interactive-attack-demo.sh
```

Press Enter when you see blank `$ ` prompts.

---

## Commands in Order (What You'll See)

### Opening

```
================================================================================
          PRODUCTION DATABASE BREACH - Live OpenShift Cluster
================================================================================

[ATTACKER] $ oc get pods -n production
[ATTACKER] $ oc get deployment payment-processor -n production
[ATTACKER] $ export POD=payment-processor-xxxxx
[ATTACKER] $ echo "Target pod: $POD"
```

**What to say:**
> "This is a live OpenShift cluster with a real production database. We're going to watch a complete credential theft attack unfold."

> "First, reconnaissance - what's running in production?"

---

### Phase 1: Credential Discovery

```
[ATTACKER] $ oc exec -n production $POD -- printenv | grep -i vault
```

**Output shows:**
```
VAULT_TOKEN=hvs.CAES...
VAULT_ADDR=http://vault...
```

**What to say:**
> "Attacker exploits an RCE vulnerability, gets shell access."

> "First thing they do: check environment variables."

> **[After output appears]**

> "There it is. A Vault token. Right there in an environment variable. Static. Valid for 90 days. Works from anywhere."

---

### Phase 2: Vault Access - Database Credentials

```
[ATTACKER] $ oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/database/production | jq .data.data'
```

**Output shows:**
```json
{
  "connection_string": "postgresql://customerdb:SuperSecret123!@...",
  "database": "customers",
  "host": "customer-database.production.svc.cluster.local",
  "password": "SuperSecret123!",
  "port": "5432",
  "username": "customerdb"
}
```

**What to say:**
> "Now they use the stolen token to access Vault. Remember - this works from anywhere."

> **[After output appears]**

> "Complete database credentials. Connection string, password, everything they need."

---

### Phase 3: Vault Access - API Keys

```
[ATTACKER] $ oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/api-keys/production | jq .data.data'
```

**Output shows:**
```json
{
  "aws_access_key": "AKIAI...",
  "aws_secret_key": "wJalr...",
  "sendgrid_api_key": "SG....",
  "stripe_secret_key": "sk_test_..."
}
```

**What to say:**
> "And the production API keys."

> **[After output appears]**

> "Stripe for payments. AWS for infrastructure. SendGrid for email. Complete system access."

---

### Phase 4: Database Access - Tables

```
[ATTACKER] $ oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c '\dt'
```

**Output shows:**
```
            List of relations
 Schema |    Name      | Type  |   Owner    
--------+--------------+-------+------------
 public | customers    | table | customerdb
 public | transactions | table | customerdb
```

**What to say:**
> "Now they connect directly to the production database using the stolen credentials."

> **[After output appears]**

> "There's the customers table. Let's see what's in it..."

---

### Phase 5: Customer Count

```
[ATTACKER] $ oc exec -n production $POD -- psql ... 'SELECT COUNT(*) as total_customers FROM customers;'
```

**Output shows:**
```
 total_customers 
-----------------
              10
```

**What to say:**
> "Ten customers in the database."

---

### Phase 6: Customer Data - **THE BIG MOMENT**

```
[ATTACKER] $ oc exec -n production $POD -- psql ... 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'
```

**Output shows:**
```
  customer_name  |          email           | account_balance |    credit_card      |     ssn     
-----------------+--------------------------+-----------------+---------------------+-------------
 Jennifer Taylor | jtaylor@example.com      |       267890.00 | 4532-7777-8888-9999 | 678-90-1234
 Emily Rodriguez | emily.r@example.com      |       198500.00 | 4024-1111-2222-3333 | 456-78-9012
 Maria Garcia    | mgarcia@example.com      |       178950.50 | 4532-8888-9999-0000 | 012-34-5678
 Lisa Wong       | lwong@example.com        |       156780.25 | 5425-9876-5432-1098 | 890-12-3456
 John Anderson   | john.anderson@example.com|       125430.50 | 4532-1234-5678-9012 | 123-45-6789
```

**What to say:**

> "Exfiltrating customer data..."

> **[Let the output appear]**

> **[PAUSE - Let them read it - 5 seconds]**

> "Look at this. Real customer data."

> "Credit card numbers. Social Security numbers. Account balances."

> **[Read slowly from screen]:**

> "Jennifer Taylor - two hundred sixty-seven thousand dollars."

> "Emily Rodriguez - one hundred ninety-eight thousand."

> "Maria Garcia - one hundred seventy-eight thousand."

> **[Pause]**

> "These are real people. Real money."

---

### Phase 7: Total at Risk

```
[ATTACKER] $ oc exec -n production $POD -- psql ... | xargs echo 'Total at risk: $'
```

**Output shows:**
```
Total at risk: $ 1238652.75
```

**What to say:**

> **[After output appears]**

> "Over **one point two million dollars**. Completely exposed."

> **[Pause for 3 seconds]**

---

### Phase 8: Fraudulent Transaction - **THE CRIME**

```
[ATTACKER] $ oc exec -n production $POD -- psql ... "INSERT INTO transactions ... 'UNAUTHORIZED - Attacker controlled transfer' ..."
```

**Output shows:**
```
INSERT 0 1
```

**What to say:**

> "They have write access to the database. Watch this..."

> **[After output appears]**

> "Transaction created. Let's see what they just did..."

---

### Phase 9: Transaction History

```
[ATTACKER] $ oc exec -n production $POD -- psql ... 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'
```

**Output shows:**
```
 id | customer_id |  amount   | transaction_type |              description               
----+-------------+-----------+------------------+---------------------------------------
  1 |           1 | -50000.00 | withdrawal       | UNAUTHORIZED - Attacker controlled...
```

**What to say:**

> **[After output appears]**

> "Fifty thousand dollars. Unauthorized withdrawal. From John Anderson's account."

> **[Pause]**

> "**This is no longer just data theft. This is financial fraud. This is a crime.**"

> **[Pause]**

> "And it looks like a legitimate transaction in the database."

---

### Phase 10: Backdoor Deployment

```
[ATTACKER] $ oc apply -f /tmp/backdoor.yaml
```

**Output shows:**
```
pod/backdoor-exfil created
```

**What to say:**

> "Finally, they deploy a backdoor to maintain access."

> **[After output appears]**

> "Even if we patch the vulnerability tonight..."

---

### Phase 11: Backdoor Verification

```
$ oc get pod backdoor-exfil -n production
```

**Output shows:**
```
NAME             READY   STATUS    RESTARTS   AGE
backdoor-exfil   1/1     Running   0          5s
```

**What to say:**

> **[After output appears]**

> "...they can come back tomorrow. For the next **ninety days**."

---

### Final Summary

**Screen shows:**
```
================================================================================

Attack complete:

  - Vault token stolen (90-day validity)
  - Database credentials compromised
  - API keys stolen (Stripe, AWS, SendGrid)
  - Customer data exfiltrated (10 records, $1.2M+)
  - Fraudulent transaction created ($50,000)
  - Backdoor deployed for persistence

================================================================================
```

**What to say:**

> "Let's look at what just happened."

> **[Read through the list]**

> "Vault token stolen - ninety days of access."

> "Complete database access - all credentials."

> "API keys for Stripe, AWS, SendGrid - complete system compromise."

> "Customer data - ten records, over one point two million dollars."

> "Fraudulent transaction - fifty thousand dollars. That's a crime."

> "And a backdoor for persistence."

> **[Pause]**

> "This is based on real breaches. Capital One - stolen credentials. Uber - stolen credentials. SolarWinds - stolen credentials. Same pattern every time."

> **[Final pause]**

> "Now let me show you how ZTWIM prevents this entire attack chain..."

---

## Pacing Guide

### Go Slow:
- **Customer data display** - Pause 5 seconds, let them read
- **After "$1.2 million"** - Pause 3 seconds
- **After "This is a crime"** - Pause 3 seconds
- **After "90 days"** - Pause 3 seconds

### Speed Up:
- Initial reconnaissance commands
- Commands they understand immediately
- Technical details

---

## Key Phrases (Use These Exact Words)

- "**Real customer data. Real money.**"
- "**One point two million dollars.**"
- "**This is financial fraud. This is a crime.**"
- "**Ninety days of access.**"
- "**Works from anywhere in the world.**"

---

## Emotional Journey

The demo creates this arc:

1. **Curious** - "Let's see what happens"
2. **Concerned** - "They got the token..."
3. **Alarmed** - "They're in the database..."
4. **Horrified** - "Those are REAL people!" ⚠️ **THE MOMENT**
5. **Despair** - "And they can commit fraud... for 90 days..."
6. **Motivated** - "We NEED to prevent this"

---

## Troubleshooting

### If a command fails:
- Stay calm
- Say: "Let me check that..."
- Run: `oc get pods -n production`
- Skip to next phase if needed

### If typing is too slow/fast:
Edit the script and change:
```bash
local delay="0.05"  # Make smaller for faster, bigger for slower
```

### If you lose your place:
- Look at what just executed
- Continue pressing Enter
- The script guides you through in order

---

## Success Indicators

**You know it worked when:**

✅ Silence during customer data display (they're reading)  
✅ Someone gasps or says "oh no"  
✅ Questions about ZTWIM immediately after  
✅ "When can we implement this?"  
✅ Security team taking photos of the screen  

---

**You're not running a script. You're showing them a breach in real-time.** 🎯

---

---

# PART 2: ZTWIM PROTECTION DEMO

## Transition (Critical Moment)

**Screen shows:**
```
================================================================================
                    NOW LET'S SEE ZTWIM PREVENTION
================================================================================
```

**What to say:**

> **[Pause after the vulnerable attack summary]**

> "So we've just watched a complete breach. Over one million dollars compromised. Ninety days of persistent access."

> **[Pause]**

> "Now... let me show you what happens when we protect this exact same workload with ZTWIM."

> **[Press Enter]**

> "Same cluster. Same Vault. Same database. But this time, the workload uses dynamic credentials instead of static tokens."

---

## Phase 1: Protected Pod Discovery

```
[ATTACKER] $ export PROTECTED_POD=payment-processor-protected-xxxxx
$ echo "Protected pod: $PROTECTED_POD"
```

**What to say:**

> "This is our ZTWIM-protected payment processor. It does the exact same job as the vulnerable one."

> "Let's try the same attack..."

---

## Phase 2: Credential Theft Attempt - **THE TURNING POINT**

```
$ oc exec -n production-protected $PROTECTED_POD -- printenv | grep -i vault
No static VAULT_TOKEN found
```

**What to say:**

> "First step of the attack: check environment variables for credentials..."

> **[After output appears]**

> "No static VAULT_TOKEN found."

> **[Pause - let that sink in for 3 seconds]**

> "The credential simply isn't there. ZTWIM delivers credentials through a Unix domain socket, not environment variables."

> "There's nothing to steal with printenv."

---

## Phase 3: Process Check

```
$ oc exec -n production-protected $PROTECTED_POD -- ps aux | head -5
```

**What to say:**

> "Maybe the attacker checks running processes, looks for credentials in memory..."

> **[After output appears]**

> "Still nothing. The JWT-SVID is delivered on-demand through a secure socket. It's never stored in process memory like a static token."

---

## Phase 4: Attack Failure - **THE BLOCK**

```
$ oc exec -n production-protected $PROTECTED_POD -- sh -c 'if [ -z "$VAULT_TOKEN" ]; then echo "No VAULT_TOKEN available"; echo "Cannot access Vault without dynamic credential"; exit 1; fi'
No VAULT_TOKEN available
Cannot access Vault without dynamic credential
Attack blocked: No credentials available
```

**What to say:**

> "Without a credential, the attacker can't access Vault. Let's see what happens when they try..."

> **[After output appears]**

> "Attack blocked."

> **[Pause]**

> "No database access. No API keys. No customer data. No fraud. The attack chain is broken at step one."

---

## Summary Table

**Screen shows the comparison table**

**What to say:**

> "Let's look at what's different."

> **[Read through the table - point to each row]**

> "Vulnerable environment: Static token. Ninety days. Stored in an environment variable. Manual rotation - which means it never gets rotated."

> **[Move finger down the table]**

> "ZTWIM-protected: Dynamic JWT. Two minutes. Unix socket. Automatic rotation."

> **[Point to Exfiltration Risk row]**

> "Critical risk versus minimal risk."

> **[Point to Persistence row]**

> "Ninety days of access versus two minutes."

> **[Pause]**

> "Even if somehow an attacker did steal the JWT, it expires in two minutes. Not ninety days. Two minutes."

---

## Final Impact Statement

**What to say:**

> "The same attack that just breached one point two million dollars..."

> **[Pause]**

> "...is completely blocked."

> **[Pause]**

> "Same workload. Same database. Same Vault. The only difference is ZTWIM."

> **[Let that land for 3 seconds]**

---

## Closing Transition

**What to say:**

> "This is what Zero Trust looks like in practice."

> "Not just theory. Not just a whitepaper. Real protection against real attacks."

> **[Pause]**

> "And the best part? ZTWIM is included with OpenShift. No additional licensing. No separate product to buy."

> "You can start protecting your first workload tomorrow."

---

## Q&A Preparation

**Common questions after ZTWIM demo:**

**"How long does it take to implement?"**
> "For a pilot - one workload - you can have it running in a day. Full migration depends on your app count, but you can do it incrementally. Start with your most critical services."

**"What about performance impact?"**
> "Negligible. The JWT validation happens locally. You're trading a one-time Vault lookup for periodic JWT rotation, which is actually less load on Vault."

**"Does this work with our existing apps?"**
> "Yes. Your apps already have service accounts. ZTWIM uses those to issue workload identities. Most apps just need environment variable changes - point them to use the dynamic credential instead of the static one."

**"What about non-OpenShift workloads?"**
> "ZTWIM is built on SPIFFE/SPIRE, which is open source and works anywhere. But on OpenShift, it's integrated and supported out of the box."

**"Can we see this in our environment?"**
> "Absolutely. Let's schedule a proof of concept. We'll pick one of your workloads and show you the before and after."

---

## Success Indicators

**You know Part 2 worked when:**

✅ Someone says "wow" or "that's it?" when credentials aren't found  
✅ Questions shift from "why" to "when can we start"  
✅ Security team is taking notes on the comparison table  
✅ Someone asks about rolling this out to production  
✅ "What's the timeline to get this implemented?"  

---

## Pacing Notes

- **Go slower** during the comparison table - let them read each row
- **Pause** after "Attack blocked" - that's the payoff moment
- **Speed up** through the process checks - they get the idea quickly
- **Slow down again** for final impact statement

---

**Total Demo Time: 20-25 minutes**
- Part 1 (Vulnerable): 15 minutes
- Part 2 (Protected): 5-10 minutes

The contrast is what makes this powerful. Show the pain, then show the solution. 🎯
