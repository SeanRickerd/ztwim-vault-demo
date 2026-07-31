# ZTWIM Vault Demo - Presenter's Guide

## Overview
This is a 15-minute live demonstration showing the dramatic difference between traditional static secrets and ZTWIM-based zero-trust workload identity.

---

## Pre-Demo Checklist

**5 minutes before starting:**

```bash
# 1. Navigate to demo directory
cd /home/srickerd/ztwim-vault-demo/scripts

# 2. Test environment (should show all green ✓)
./test-demo-environment.sh

# 3. If anything is red, run setup:
./demo-runner.sh
# Choose option 4 (Setup Only)
```

**Terminal Setup:**
- Font size: Large enough for audience to read
- Color support: Ensure terminal supports ANSI colors
- Encoding: UTF-8 for box drawing characters
- Window size: At least 100 columns wide

---

## Demo Script (15 minutes)

### Introduction (2 minutes)

**[Open with a question to the audience]**

> "How many of you have Kubernetes Secrets in your production clusters? Keep your hands up if those secrets have been there for more than a month. More than 90 days? A year?"

**[Pause for effect]**

> "Congratulations - every one of those long-lived secrets is a potential 90-day blast radius waiting to happen. Let me show you what that looks like..."

**[Set the stage]**

> "Today I'm going to show you two scenarios. In Scenario 1, we have a traditional cloud-native app using static Vault tokens - the way most of us do it today. In Scenario 2, we'll see the exact same attack attempt against an app protected by Red Hat's Zero Trust Workload Identity Manager, or ZTWIM."

---

### Scenario 1: The Attack Succeeds (5 minutes)

**Command:**
```bash
./demo-runner.sh
# Choose option 2 (Scenario 1 only)
```

**Talking Points While It Runs:**

**[Step 1-2: Reconnaissance & Shell Access]**
> "Here's our vulnerable payment processing app. It's using a Vault token stored in a Kubernetes Secret - standard practice for many organizations."

> "The attacker gains shell access to the pod. This could be through a vulnerability, supply chain attack, or even just misconfigured RBAC permissions."

**[Step 3: Finding Static Token]**
> "Watch this - the attacker searches environment variables and finds the Vault token. It's right there in plain text."

> "This is a 90-day token. That means once stolen, the attacker has 90 days of persistent access."

**[Step 4: Token Exfiltration]**
> "The attacker copies the token to their own infrastructure. Now they can access Vault from anywhere - their laptop, a compromised server, even their home network."

**[Step 5: External Authentication]**
> "From outside the cluster entirely, the attacker authenticates to Vault using the stolen token. Vault has no way to know this isn't the legitimate app."

**[Step 6: Data Theft - THE BIG REVEAL]**
> "And here's the payoff. Watch what happens when they access the secret data..."

**[When the PII appears on screen]**
> "There it is. Credit card numbers. Social Security numbers. Database passwords. API keys. Everything."

> "This isn't a hypothetical attack - this is exactly what happens in real breaches. And remember, the attacker can keep doing this for 90 days before that token expires."

**[Pause for impact]**

> "That's the problem we're trying to solve. Now let me show you how ZTWIM prevents this exact same attack."

---

### Transition (1 minute)

**[Clear the screen]**

```bash
# Press Enter to return to menu
# Choose option 3 (Scenario 2 only)
```

**[While it starts deploying]**

> "In Scenario 2, we're running the same payment service, but this time it's protected by ZTWIM - Red Hat's implementation of the SPIFFE/SPIRE standard for workload identity."

> "The attacker is going to try the exact same techniques. Let's see what happens..."

---

### Scenario 2: The Attack Fails (5 minutes)

**Talking Points While It Runs:**

**[Step 1-2: Reconnaissance & Shell Access]**
> "Same starting point - the attacker gains shell access to the pod. This is identical to Scenario 1."

**[Step 3: Searching for Credentials - FIRST BLOCK]**
> "But watch what happens when they search for credentials..."

> "No environment variables. No files. No Kubernetes Secrets. There are literally zero static credentials in this pod."

> "ZTWIM eliminates static secrets entirely. The app gets its credentials dynamically through cryptographic attestation."

**[Step 4: SPIRE Workload API - SECOND BLOCK]**
> "The attacker gets clever. They find the SPIRE Workload API socket and try to access it directly."

> "But SPIRE blocks them. Why? Because the Workload API requires kernel-level attestation. It verifies the caller's process ID, user ID, and control groups. Only the actual application process can access its identity - not a shell session, not a different process."

**[Step 5: Hypothetical JWT Theft - THIRD BLOCK]**
> "Let's say, hypothetically, the attacker somehow managed to steal a JWT-SVID. Notice the expiration time..."

> "Two minutes. Not 90 days - two minutes."

> "By the time they exfiltrate it and try to use it externally, it's already expired."

**[Step 6: External Use Fails - FOURTH BLOCK]**
> "Watch this - they try to authenticate to Vault from outside the cluster using the stolen JWT."

> "Token expired. Even if they were fast enough, they'd have a maximum 2-minute window instead of 90 days."

**[Step 7: Renewal Attempt - FIFTH BLOCK]**
> "Can they renew the JWT? No. Renewal requires the same SPIRE attestation. They'd need to be running on a legitimate cluster node with the correct pod identity."

> "They can't fake it. They can't replay it. They can't renew it."

**[Final Summary - IMPACT MOMENT]**
> "Watch this final comparison table..."

**[When the comparison appears]**

> "Every single attack step that succeeded in Scenario 1 is now blocked. 100% prevention."

> "But here's the real number that matters: 97% reduction in blast radius. We went from 90 days to 2 minutes. That's the difference between a headline-making breach and a non-event."

---

### Conclusion (2 minutes)

**Key Takeaways:**

> "Let me summarize what we just saw with three key points:"

**1. Zero Static Secrets**
> "ZTWIM eliminates static secrets in pods entirely. There's nothing for an attacker to steal. The credentials are delivered dynamically through cryptographic attestation, not stored in environment variables or files."

**2. Minimal Blast Radius**
> "Even if an attacker somehow gets credentials, they expire in 2 minutes. Compare that to the 90-day tokens we saw in Scenario 1 - or worse, the tokens in some environments that never expire."

**3. No Operational Overhead**
> "And here's the best part - this all happens automatically. No manual rotation. No credential sprawl in git repos or configuration files. No compliance headaches."

**Business Impact:**
> "From a business perspective, this means:"
> - "97% reduction in breach window"
> - "Zero static secrets to manage"
> - "Compliance-ready dynamic secrets"
> - "Prevention of lateral movement after pod compromise"

**Call to Action:**
> "ZTWIM is available today as part of OpenShift. It's based on SPIFFE/SPIRE, a CNCF graduated project, so it's industry-standard and works with any secret store, not just Vault."

> "The question isn't whether you'll move to zero-trust workload identity - it's when. And the difference between doing it now versus waiting could be the difference between reading about a breach in the news and being in it."

---

## Troubleshooting During Live Demo

### If Scenario 1 fails to show PII:
```bash
# In a second terminal:
cd /home/srickerd/ztwim-vault-demo/scripts
./setup-vulnerable-vault.sh
# Then re-run Scenario 1
```

**What to say:**
> "Let me quickly reconfigure the vulnerable environment - sometimes these demo gremlins need a reset. This is actually a good reminder of why static secrets are painful to manage..."

### If Scenario 2 pods won't start:
The demo-runner auto-fixes this, but if it doesn't work:

**What to say:**
> "You're seeing one of the OpenShift Security Context Constraints in action - this is OpenShift preventing the pod from mounting the SPIRE socket. I'm going to apply the correct SCC permissions now..."

```bash
# In second terminal:
./fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
```

### If terminal colors aren't working:
```bash
export TERM=xterm-256color
```

### If box drawing characters are broken:
```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

---

## Audience Questions & Answers

### "Does this work with [other secret store besides Vault]?"
**Answer:** "Yes. ZTWIM implements SPIFFE/SPIRE, which is vendor-neutral. It works with Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager - anything that supports OIDC authentication."

### "What's the performance impact?"
**Answer:** "Minimal. The JWT-SVID is cached by the application and rotated in the background via SPIFFE Helper. There's no per-request overhead. The initial attestation happens once at pod startup."

### "Can attackers just steal the SPIRE agent socket?"
**Answer:** "Great question - that's exactly what we showed failing in Scenario 2. The socket requires kernel-level attestation. Even if you have root in the pod, the SPIRE agent verifies your process ID, UID, and cgroup membership. You can't fake those from a shell or different process."

### "What if the pod is compromised at startup before the identity is established?"
**Answer:** "The identity is established before the application starts. The SPIRE agent injects the JWT-SVID via a CSI driver before the container runs. And even if compromised, the attacker gets a 2-minute window versus 90 days."

### "How does this compare to Kubernetes Service Account tokens?"
**Answer:** "Service Account tokens are a step in the right direction, but they have longer TTLs and aren't cryptographically bound to the workload. ZTWIM provides workload-level identity with cryptographic attestation - much stronger guarantees."

### "Is this production-ready?"
**Answer:** "Absolutely. SPIFFE/SPIRE is a CNCF graduated project used by companies like Bloomberg, ByteDance, and Uber. Red Hat's ZTWIM is GA as of version 1.1 and is fully supported on OpenShift."

### "How hard is it to migrate existing apps?"
**Answer:** "For apps already using Vault or similar secret stores, it's mostly configuration changes - no code changes required. You're just changing how authentication happens. The SPIFFE Helper CSI driver handles the complexity."

---

## Quick Reference Commands

### Test Environment:
```bash
cd /home/srickerd/ztwim-vault-demo/scripts
./test-demo-environment.sh
```

### Full Demo (Both Scenarios):
```bash
./demo-runner.sh
# Choose option 1
```

### Scenario 1 Only:
```bash
./demo-runner.sh
# Choose option 2
```

### Scenario 2 Only:
```bash
./demo-runner.sh
# Choose option 3
```

### Setup from Scratch:
```bash
./demo-runner.sh
# Choose option 4 (Setup)
# Then option 5 (Test)
# Then option 1 (Full Demo)
```

### Cleanup:
```bash
./demo-runner.sh
# Choose option 6
```

---

## Timing Breakdown

| Section | Duration | Notes |
|---------|----------|-------|
| Introduction | 2 min | Set the stage, ask audience questions |
| Scenario 1 | 5 min | Let the attack run, explain each step |
| Transition | 1 min | Clear screen, set expectations for S2 |
| Scenario 2 | 5 min | Show failures, explain defenses |
| Conclusion | 2 min | Key takeaways, business impact |
| **Total** | **15 min** | Add 5 min for Q&A if time allows |

---

## PowerPoint/Slide Talking Points

If you're presenting slides before or after the demo:

### Slide: "The Problem"
- 90-day+ token lifetimes are standard in cloud-native apps
- Kubernetes Secrets are base64, not encrypted at rest by default
- Static credentials proliferate across git, CI/CD, backups
- Post-compromise persistence: attacker maintains access for months

### Slide: "The ZTWIM Solution"
- SPIFFE/SPIRE standard (CNCF graduated)
- Cryptographic workload identity (not just service account)
- 2-minute JWT-SVID expiration (configurable)
- Automatic rotation via CSI driver
- No code changes required for most apps

### Slide: "Business Impact"
- 97% reduction in breach window (90 days → 2 minutes)
- Zero static secrets to manage or rotate
- Compliance-ready (meets requirements for dynamic secrets)
- Prevents lateral movement post-compromise

---

## Success Metrics

**You know the demo was successful when:**
- Audience gasps at the PII reveal in Scenario 1
- At least one person asks "can I get the code for this?"
- Someone asks about production readiness or migration effort
- Audience makes the connection between blast radius and business risk

**Red flags during demo:**
- Audience looks confused during technical steps (slow down, explain more)
- Questions about "is this realistic?" (emphasize real breach patterns)
- Silence during conclusion (re-engage with direct question)

---

## Post-Demo Follow-Up

**Resources to share:**
- Demo code: `/home/srickerd/ztwim-vault-demo`
- SPIFFE project: https://spiffe.io
- ZTWIM documentation: Red Hat OpenShift docs
- This presenter guide: `PRESENTER-GUIDE.md`

**Next steps for interested attendees:**
1. Try the demo in their own environment
2. Review their current secret management approach
3. Identify high-risk workloads for pilot migration
4. Schedule architecture review with Red Hat

---

## Notes for Different Audiences

### **Security Architects:**
Emphasize: Cryptographic attestation, defense-in-depth, compliance benefits

### **Platform Engineers:**
Emphasize: Operational simplicity, no manual rotation, OpenShift integration

### **CISOs / Business Leaders:**
Emphasize: Blast radius reduction, breach prevention, compliance, ROI

### **Developers:**
Emphasize: No code changes, automatic credential delivery, developer experience

---

## Final Pre-Flight Check

**Right before going on stage:**

```bash
# 1. Test environment
cd /home/srickerd/ztwim-vault-demo/scripts
./test-demo-environment.sh

# 2. All green? You're ready!
# 3. Not green? Run setup:
./demo-runner.sh  # option 4

# 4. Test both scenarios quickly (run option 1 once through)
```

**Terminal settings:**
- ✓ Font size readable from back of room
- ✓ Color support enabled
- ✓ UTF-8 encoding for box characters
- ✓ 100+ column width

**Backup plan:**
- Have demo pre-recorded as video backup
- Have screenshots of key moments (PII reveal, comparison table)
- Know the talking points by heart even without the demo running

---

## You're Ready!

Remember: The most important part isn't the technical execution - it's telling the story of why this matters. Static secrets are a ticking time bomb. ZTWIM is the defusal kit.

**Break a leg!** 🎬
