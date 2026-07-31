# Interactive Attack Demo - Speaker Notes

## Overview

This demo looks like a **real terminal session**. You see commands, press Enter, they execute and show output. Natural, not scripted.

**Duration:** 15-20 minutes

---

## How It Works

- Screen shows: `$ command-to-run`
- You: Press Enter (silently, no prompt shown)
- Screen: Executes and shows real output
- You: Explain what just happened

**It looks exactly like you're typing commands manually.**

---

## Running the Demo

```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./interactive-attack-demo.sh
```

Press Enter when you see `$` prompts or when comments appear.

---

## Phase-by-Phase Speaker Notes

### Opening Screen

**What appears:**
```
================================================================================
                    PRODUCTION DATABASE BREACH DEMO
                     Live Attack on OpenShift Cluster
================================================================================

Scenario: Financial services company using Kubernetes and Vault
Target: Production payment processing system

Press Enter to begin reconnaissance...
```

**What to say:**

> "I'm going to show you a realistic credential theft attack. This is running live on an OpenShift cluster with a real database containing customer data."

> "The scenario: A financial services company. They're using Kubernetes, Vault for secrets management. They think they're following best practices."

> "Let's see what happens when an attacker gets in."

**[Press Enter]**

---

### Phase 1: Reconnaissance

**Screen shows:**
```
# Reconnaissance: What's running in production?

$ oc get pods -n production
```

**What to say:**

> "Attacker starts with reconnaissance. What's running in production?"

**[Press Enter - pods listed]**

> "There's the customer database and the payment processor."

**Screen shows:**
```
$ oc get deployment payment-processor -n production
```

**[Press Enter - deployment shown]**

> "That's the target - the payment processor. This handles financial transactions."

**[Press Enter to continue]**

---

### Phase 2: Initial Compromise

**Screen shows:**
```
# Attacker exploits RCE vulnerability, gains shell access to pod

$ export POD=payment-processor-xxxxx
```

**What to say:**

> "The attacker exploits an RCE vulnerability. Could be Log4Shell, a dependency issue, whatever. They get shell access to the pod."

**[Press Enter - pod name set]**

**Screen shows:**
```
$ echo "Compromised pod: $POD"
```

**[Press Enter]**

> "Now they have code execution inside the production payment processor."

**Screen shows:**
```
# First thing attacker does: search for credentials in environment

$ oc exec -n production $POD -- printenv | grep -i vault
```

**What to say:**

> "First thing they do: check environment variables for secrets. Watch this..."

**[Press Enter - credentials displayed]**

```
VAULT_TOKEN=hvs.CAES...
VAULT_ADDR=http://vault...
```

> "There it is. A Vault token. Right there in an environment variable."

> **[Pause for effect]**

> "This is how the app authenticates to Vault. It's a static token. Valid for 90 days. And it works from anywhere."

**[Press Enter to continue]**

---

### Phase 3: Vault Access

**Screen shows:**
```
# Attacker uses stolen token to access Vault (from their own infrastructure)

$ oc exec -n production $POD -- sh -c 'curl -sf -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/database/production | jq .data.data'
```

**What to say:**

> "Now they use that stolen token to authenticate to Vault. And remember - this token works from anywhere. They don't even need to be in the pod anymore."

> "They're operating from their own command and control server now. Could be anywhere in the world."

**[Press Enter - database credentials displayed]**

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

> "Complete database credentials. Connection string, password, everything."

**[Press Enter to continue]**

**Screen shows:**
```
$ oc exec... /v1/secret/data/api-keys/production
```

**[Press Enter - API keys displayed]**

```json
{
  "aws_access_key": "AKIAI...",
  "aws_secret_key": "wJalr...",
  "sendgrid_api_key": "SG....",
  "stripe_secret_key": "sk_test_..."
}
```

> "And the production API keys. Stripe for payments. AWS for infrastructure. SendGrid for email."

> "Complete system compromise at this point."

**[Press Enter to continue]**

---

### Phase 4: Database Breach - **THE BIG MOMENT**

**Screen shows:**
```
# Attacker connects to production database using stolen credentials

$ oc exec... psql... -c '\dt'
```

**What to say:**

> "Now they connect directly to the production database. Using the credentials they just stole from Vault."

**[Press Enter - tables listed]**

```
            List of relations
 Schema |    Name      | Type  |   Owner    
--------+--------------+-------+------------
 public | customers    | table | customerdb
 public | transactions | table | customerdb
```

> "There's the customers table."

**Screen shows:**
```
$ oc exec... 'SELECT COUNT(*) as total_customers FROM customers;'
```

**[Press Enter]**

```
 total_customers 
-----------------
              10
```

> "Ten customers. Let's see what data is in there..."

**Screen shows:**
```
# Exfiltrating customer PII - Top 5 accounts by balance

$ oc exec... 'SELECT customer_name, email, account_balance, credit_card, ssn FROM customers ORDER BY account_balance DESC LIMIT 5;'
```

**What to say:**

> "Exfiltrating the top accounts..."

**[Press Enter - THIS IS THE MOMENT]**

```
  customer_name  |          email           | account_balance |    credit_card      |     ssn     
-----------------+--------------------------+-----------------+---------------------+-------------
 Jennifer Taylor | jtaylor@example.com      |       267890.00 | 4532-7777-8888-9999 | 678-90-1234
 Emily Rodriguez | emily.r@example.com      |       198500.00 | 4024-1111-2222-3333 | 456-78-9012
 Maria Garcia    | mgarcia@example.com      |       178950.50 | 4532-8888-9999-0000 | 012-34-5678
 Lisa Wong       | lwong@example.com        |       156780.25 | 5425-9876-5432-1098 | 890-12-3456
 John Anderson   | john.anderson@example.com|       125430.50 | 4532-1234-5678-9012 | 123-45-6789
```

> **[Slow down - let them read it]**

> "Look at this. Real customer data."

> "Credit card numbers. Social Security numbers. Account balances."

> **[Read from screen]:**
> "Jennifer Taylor - $267,890 in her account."
> "Emily Rodriguez - $198,500."
> "Maria Garcia - $178,950."

> "These are real people. Real money."

**[Pause - let this land]**

**[Press Enter to continue]**

**Screen shows:**
```
$ oc exec... | xargs echo 'Total money at risk: $'
```

**[Press Enter]**

```
Total money at risk: $ 1238652.75
```

> "Over one-point-two **million dollars** in customer accounts. Completely exposed."

**[Pause again]**

**[Press Enter to continue]**

---

### Phase 5: Data Manipulation - **THE CRIME**

**Screen shows:**
```
# Attacker has WRITE access - creating fraudulent transaction

$ oc exec... INSERT INTO transactions... 'UNAUTHORIZED - Attacker controlled transfer'...
```

**What to say:**

> "But they're not done. They have write access to this database."

> "Watch what they can do..."

**[Press Enter - transaction created]**

```
 id | customer_id |  amount   | transaction_type |              description               
----+-------------+-----------+------------------+---------------------------------------
  1 |           1 | -50000.00 | withdrawal       | UNAUTHORIZED - Attacker controlled...
```

> "Fifty thousand dollars. Unauthorized withdrawal. From John Anderson's account."

> **[Pause]**

> "This is no longer just data theft."

> "**This is financial fraud. This is a crime.**"

**[Press Enter to continue]**

**Screen shows:**
```
$ oc exec... 'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 3;'
```

**[Press Enter]**

> "There it is in the transaction log. It looks like a legitimate withdrawal. But it's completely unauthorized."

**[Press Enter to continue]**

---

### Phase 6: Persistence

**Screen shows:**
```
# Deploying backdoor pod for persistent access

$ oc apply -f /tmp/backdoor.yaml
```

**What to say:**

> "Finally, they want to make sure they can come back. Even if someone patches the original vulnerability."

> "They're deploying a backdoor. It's going to look like a monitoring pod..."

**[Press Enter - pod created]**

```
pod/backdoor-exfil created
```

**Screen shows:**
```
$ oc get pod backdoor-exfil -n production
```

**[Press Enter - pod status shown]**

```
NAME             READY   STATUS    RESTARTS   AGE
backdoor-exfil   1/1     Running   0          5s
```

> "It's running. It has the stolen Vault token. It has database access."

> "Even if we patch the payment processor tonight, they can use this backdoor tomorrow. For the next **90 days**."

**[Press Enter to see summary]**

---

### Final Summary

**Screen shows:**
```
================================================================================
                           ATTACK COMPLETE
================================================================================
```

**What to say:**

> "Let's look at what just happened."

**[Read through the timeline]**

> "Complete attack chain. From reconnaissance to persistent backdoor."

**[Business Impact section]**

> "Business impact:"

> "Financial loss - potentially the full $1.2 million."

> "Compliance violations - GDPR for the PII exposure. PCI-DSS for the credit cards. SOX for the fraudulent transactions."

> "Customer trust - destroyed. When this gets out, people will close their accounts."

> "Legal liability - class action lawsuits are coming."

**[Attacker Capabilities section]**

> "And here's the nightmare: the attacker has **90 days** of access."

> "They can operate from anywhere in the world."

> "Their traffic looks like legitimate app access. Hard to detect."

> "They have a backdoor. They have the credentials. They can come back whenever they want."

**[Why Did This Succeed section]**

> "So why did this attack work?"

> "One: Static credentials. That Vault token is valid for 90 days."

> "Two: It was in an environment variable. Takes ten seconds to find."

> "Three: No workload identity verification. Vault can't tell if this is the real payment processor or an attacker in Brazil."

> "Four: The token works from anywhere. No location verification. No attestation."

> "Five: One credential equals access to everything. The entire secret store."

> "Six: No automatic rotation. No time-based expiration beyond those 90 days."

**[Final message]**

> "This is not a hypothetical scenario. We've seen variations of this attack hundreds of times. Different details, same pattern."

> "Capital One breach - stolen credentials. Uber breach - stolen credentials. SolarWinds - stolen credentials."

> "It's the same story every time."

**[Pause]**

> "Now let me show you how ZTWIM prevents this entire attack chain..."

---

## Pacing Guide

### Go Fast:
- Phase 1 (reconnaissance)
- Command execution (just press Enter)
- Parts they already understand

### Go Slow:
- **Phase 4 when customer data appears** - Let them read it
- **Phase 5 when fraud happens** - This is the crime moment
- **Final summary** - Make sure they get the numbers

### Pause:
- After customer data displays (5 seconds)
- After saying "$1.2 million" (3 seconds)
- After "This is a crime" (3 seconds)
- After explaining 90-day access (3 seconds)

---

## Key Phrases

Use these exact phrases for maximum impact:

- "**Real customer data. Real money.**"
- "**This is financial fraud. This is a crime.**"
- "**90 days of access.**"
- "**One-point-two million dollars.**"
- "**It works from anywhere in the world.**"

---

## Handling Technical Issues

### If a command fails:
- Stay calm: "Let me check that pod status..."
- Run: `oc get pods -n production`
- Skip to next phase if needed: "The pattern is clear, let me show you the next step..."

### If database is slow:
- Fill time: "This is connecting to the actual production database..."
- Or skip ahead: "Let me show you what the attacker would see..."

### If you lose your place:
- The comments in the output tell you what phase you're in
- Just keep pressing Enter - the script guides you

---

## Success Indicators

You know it worked when:

✅ Someone gasps or says "oh no" during Phase 4  
✅ Silence during the customer data display (they're reading it)  
✅ Questions about ZTWIM immediately after  
✅ "How soon can we implement this?"  
✅ Security team members taking photos of the screen  

---

## The Emotional Journey

This demo creates a specific arc:

1. **Curious** - "Let's see what happens"
2. **Concerned** - "They got the token..."
3. **Alarmed** - "They're in the database..."
4. **Horrified** - "Those are REAL account balances!" ⚠️
5. **Despair** - "And they can commit fraud... for 90 days..."
6. **Motivated** - "We NEED to fix this"

The transition to ZTWIM should feel like **relief** and **hope**.

---

## Remember

- You're just pressing Enter
- The script makes it look like a real terminal session
- Your job is to narrate what's happening
- Let the data speak for itself
- **The horror is in the numbers: $1.2M, 90 days, 10 customers**

**You're not running a script. You're showing them a breach in progress.** 🎯
