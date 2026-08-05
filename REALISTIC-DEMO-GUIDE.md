# ZTWIM Realistic Attack Demo - Presenter Guide

## Overview

This is an enhanced, highly realistic demonstration showing the complete business impact of a credential theft attack, followed by ZTWIM's complete prevention of the same attack chain.

### Key Difference from Original Demo

**Original Demo:**
- Shows stolen token accessing generic "customer data"
- Abstract, doesn't feel real
- Limited emotional impact

**Realistic Demo:**
- Complete 7-phase attack showing actual business impact
- Real PostgreSQL database with customer records
- $1.2M+ in exposed account balances
- Fraudulent transactions
- API key compromise
- Backdoor deployment
- Makes viewers think "this could happen to us"

---

## Setup (15 minutes before presentation)

### Prerequisites
- Fresh OpenShift cluster with cluster-admin access
- HashiCorp Vault deployed
- Terminal with good font size and color support

### Setup Command

```bash
cd ztwim-vault-demo/scripts

# Deploy complete vulnerable environment
./setup-realistic-vulnerable-environment.sh

# This creates:
# - Production namespace
# - PostgreSQL database with 10 customer records
# - $1,238,652.75 in total account balances
# - Vulnerable payment processor with static Vault token
# - Database credentials stored in Vault
# - API keys (Stripe, AWS, SendGrid) in Vault
```

**Expected output:**
```
✓ Namespace created
✓ Customer database deployed
✓ Database is ready
✓ Database credentials stored in Vault
✓ Payment processor deployed
✓ Application is ready

Environment Details:
  Namespace: production
  Database: PostgreSQL with 10 customer records
  Total Account Balances: $1,238,652.75
  Vulnerable App: payment-processor
  Static Token TTL: 90 days (2160 hours)

What's at risk:
  • 10 customer records with PII (credit cards, SSNs)
  • $1.2M+ in customer account balances
  • Production database credentials in Vault
  • API keys (Stripe, AWS, SendGrid)
```

---

## Demo Script (20 minutes)

### Introduction (2 minutes)

**[Open with context]**

> "I want to show you something that happened to a major financial services company last year. They had all the right tools - Kubernetes, Vault for secrets, security scanning. But they made one critical mistake: static, long-lived credentials."

> "I'm going to walk you through exactly what the attackers did, step by step. This is based on a real breach. And then I'll show you how zero-trust workload identity could have stopped it completely."

**[Set the stage]**

> "Here's our scenario: A payment processing company with a production database containing customer financial data. They're using Vault to manage secrets - following best practices, or so they thought."

---

### The Attack (12 minutes)

Run the realistic attack demo:

```bash
./demo-realistic-attack.sh
```

**Talking points for each phase:**

#### Phase 1: Initial Compromise (1 min)
> "The attacker finds an RCE vulnerability in the payment processor. Could be anything - Log4Shell, a dependency vulnerability, misconfigured endpoint. They get a shell inside the pod."

> "This part is hard to prevent completely. Vulnerabilities happen. The question is: what can they do once they're in?"

#### Phase 2: Credential Theft (1 min)
> "Watch this. They run 'printenv' - just looking at environment variables."

> "There it is. A Vault token. Static. 90-day TTL. Stored right there in plain text."

> "And here's the critical part: this token works from *anywhere*. They copy it to their infrastructure."

**[Pause for effect]**

#### Phase 3: Lateral Movement - Database Access (2 min)
> "Now they're operating from their command and control server. Could be anywhere in the world."

> "They authenticate to Vault with the stolen token. Vault has no way to know this isn't the legitimate app."

> "And look what they get: complete database credentials. Host, password, connection string. Everything."

**[Let the credentials display sink in]**

#### Phase 4: Data Exfiltration (2 min)
> "Now they connect directly to the production database. Watch this..."

**[When customer data appears]**

> "There it is. Real customer data. Credit cards. Social Security numbers. Account balances."

> "Look at these numbers. Jennifer Taylor - $267,890. Emily Rodriguez - $198,500. Lisa Wong - $156,780."

> "This is $1.2 million in customer accounts. Completely exposed."

**[Pause - let the impact land]**

> "And remember - this is PRODUCTION data. These could be real customers."

#### Phase 5: API Key Compromise (1 min)
> "But they're not done. They go back to Vault and grab the API keys."

> "Stripe payment processing key - they can now process payments, issue refunds, do whatever they want with the payment system."

> "AWS credentials - access to cloud infrastructure."

> "SendGrid - they can send emails *as the company*."

#### Phase 6: Data Manipulation (2 min)
> "Here's where it gets worse. They have database write access."

> "Watch - they're creating a fraudulent transaction. $50,000 withdrawal. From John Anderson's account."

**[When fraudulent transaction appears]**

> "This is now a FINANCIAL CRIME. Not just data theft - active fraud."

#### Phase 7: Persistence (2 min)
> "And finally, they ensure they can come back."

> "They deploy a backdoor pod. Looks like a monitoring tool. Even if someone patches the original vulnerability, they still have access."

> "The token is good for 90 days. They can come back whenever they want."

#### Impact Summary (1 min)
**[Read through the impact summary]**

> "$1.2 million exposed. GDPR violations. PCI-DSS violations. Customer trust destroyed. Lawsuits incoming."

> "And the attacker has 90 days of persistent access. They can operate from anywhere. Hard to detect because it looks like legitimate application access."

**[Dramatic pause]**

> "This is the nightmare scenario. One compromised pod. One stolen token. Complete breach."

---

### Transition (1 minute)

> "So that was terrifying. Let me show you how ZTWIM prevents this entire attack chain."

> "Same vulnerability. Same initial compromise. But watch what happens with zero-trust workload identity..."

---

### ZTWIM Protection (5 minutes)

Run the ZTWIM protected scenario:

```bash
./demo-scenario-2-attack.sh
```

**Key talking points:**

1. **No Static Credentials (Step 3 fails)**
   > "The attacker searches for credentials. Nothing. No environment variables. No files. ZTWIM eliminated static secrets entirely."

2. **Workload API Protection (Step 4 fails)**
   > "They try to access the SPIRE Workload API. Blocked. It requires kernel-level attestation. Only the actual application process can get credentials."

3. **Short-Lived Credentials (Step 5 fails)**
   > "Even hypothetically, if they somehow got a JWT-SVID, it expires in 2 minutes. Not 90 days - 2 minutes."

4. **No External Replay (Step 6 fails)**
   > "They try to use it externally. Already expired. And even if they were fast, Vault would verify it's not coming from the actual workload."

5. **No Persistence Possible (Step 7 fails)**
   > "They can't renew credentials. They can't deploy a backdoor with access. The attack chain is completely broken."

**[Final comparison]**

> "Let's look at what just happened:"
> 
> "Phase 1 - Initial compromise: Same in both scenarios. We can't prevent all vulnerabilities."
> 
> "Phase 2 - Credential theft: BLOCKED. No credentials to steal."
> 
> "Phase 3-7 - Everything else: IMPOSSIBLE. The attack chain is broken at step 2."

---

## Conclusion (2 minutes)

> "Here's the key insight: We went from a $1.2 million breach with 90 days of persistent access..."

> "...to a compromised pod with ZERO secrets and a 2-minute window before credentials expire."

> "That's a 97% reduction in breach window. From 90 days to 2 minutes."

**Business Value:**

> "For security teams: You just saw defense-in-depth actually working. Multiple layers failed in scenario 1 - the pod was compromised - but ZTWIM stopped the lateral movement."

> "For compliance: ZTWIM eliminates static secrets entirely. That alone solves multiple audit findings."

> "For operations: This is zero overhead. No manual rotation. No credential sprawl. It just works."

**Call to Action:**

> "ZTWIM is available now on OpenShift. It's based on SPIFFE/SPIRE - a CNCF graduated project. Production ready."

> "The question isn't whether you'll move to zero-trust workload identity. It's whether you'll do it before or after a breach like the one we just saw."

---

## Emotional Impact Points

### Maximum Impact Moments

1. **When customer data appears** - Let it sit on screen. Don't rush past it.
2. **$1.2M total** - Emphasize the real money at risk.
3. **Fraudulent transaction** - This is when it becomes a crime, not just a leak.
4. **90-day persistence** - The nightmare continues for months.
5. **ZTWIM blocking everything** - The relief moment.

### Pacing

- **Slow down** during data exfiltration - let people absorb what they're seeing
- **Speed up** during technical setup steps - keep momentum
- **Pause** after showing the fraudulent transaction - let the "oh no" moment land
- **Be confident** during ZTWIM demo - this is the hero moment

---

## Handling Questions

### "Is this realistic?"

**Answer:** "Yes. This attack chain is based on actual breaches. The specific details change, but the pattern is the same: RCE → credential theft → lateral movement → data exfiltration. We saw this with SolarWinds, we saw it with the Uber breach, we see it constantly."

### "What if the attacker compromises the SPIRE server?"

**Answer:** "Great question. If they compromise the SPIRE server, they have bigger problems - they're at the control plane level. But even then, workload attestation means they can't just generate arbitrary credentials. They'd need to be running on an actual cluster node with the correct workload identity. It's defense-in-depth - much harder than stealing an environment variable."

### "What's the performance impact?"

**Answer:** "Minimal. The JWT-SVID is cached and rotated in the background. There's no per-request overhead. The initial attestation happens at pod startup. In our testing, it adds less than a second to pod startup time."

### "How hard is it to implement?"

**Answer:** "For new apps, it's configuration changes - no code required. For existing apps using Vault, you're just changing how authentication works. The SPIFFE Helper CSI driver handles the complexity. You can start with one application and gradually migrate."

### "What about cost?"

**Answer:** "ZTWIM is included with OpenShift. There's no additional licensing cost. You need to run the SPIRE server and agents, which is minimal overhead - typically less than 100MB memory per node."

---

## Technical Setup Notes

### If Database Isn't Ready

The setup script waits for the database, but if it fails:

```bash
oc get pods -n production -w
# Wait for customer-database pod to be Running
```

### If Demo Breaks Mid-Attack

Stay calm:

```bash
# Check if pod exists
oc get pods -n production

# If needed, restart from setup
./setup-realistic-vulnerable-environment.sh
```

### Clean Up After Demo

```bash
oc delete namespace production
rm -rf /tmp/demo-tokens
```

---

## Backup Plan

**If live demo fails:**

Have screenshots ready of:
1. Customer data exfiltration output
2. Fraudulent transaction
3. ZTWIM blocking the attack

**Fallback talking points:**
- Focus on the attack chain logic
- Walk through what WOULD happen
- Emphasize the business impact

---

## Success Metrics

**You know it worked when:**
- Someone says "oh no" during the data exfiltration
- Questions about timeline to implement
- Requests for the demo code
- Security team members nodding during ZTWIM demo
- Someone asks about migrating their existing apps

---

## Final Checklist

Before going on stage:

- [ ] Fresh OpenShift cluster accessible
- [ ] Vault deployed and accessible
- [ ] Terminal font size readable from back of room
- [ ] Color support enabled
- [ ] Ran setup script successfully
- [ ] Tested both attack scenarios once
- [ ] Backup screenshots ready
- [ ] Know your talking points
- [ ] Deep breath - you've got this!

---

**Remember: The power of this demo is the emotional journey. Terror → Relief. Make them feel the breach, then show them the solution.**

**Break a leg!** 🎬
