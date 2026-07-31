# ZTWIM + Vault Demo - Pre-Flight Checklist

## Before the Demo

### Infrastructure Preparation

- [ ] OpenShift/Kubernetes cluster accessible
- [ ] Cluster admin credentials configured
- [ ] `kubectl`/`oc` CLI working
- [ ] `jq`, `curl`, `bash` available

### Demo Setup (Run 1 hour before)

- [ ] Clone/copy demo repository
- [ ] Run `./scripts/setup-vault.sh`
- [ ] Run `./scripts/setup-ztwim.sh`
- [ ] Verify all pods running:
  ```bash
  kubectl get pods -n vault
  kubectl get pods -n spire
  ```

### Terminal Setup

- [ ] Large font size (18pt minimum for visibility)
- [ ] Split terminal layout ready (tmux recommended)
- [ ] Shell scripts executable: `find . -name "*.sh" -exec chmod +x {} \;`
- [ ] Test run both scenarios

### Presentation Materials

- [ ] Architecture diagrams ready
- [ ] README.md open for reference
- [ ] PRESENTATION.md loaded
- [ ] COMPARISON.md for Q&A
- [ ] Backup screenshots (in case live demo fails)

### Backup Plan

- [ ] Pre-recorded video of successful demo
- [ ] Screenshots of key outputs
- [ ] Architecture diagrams as slides
- [ ] Network connectivity verified

---

## Demo Execution Checklist

### Introduction (5 minutes)

- [ ] Explain the attack scenario
- [ ] Show architecture diagram
- [ ] Set expectations for both scenarios

### Scenario 1: Vulnerable (10 minutes)

- [ ] Deploy: `kubectl apply -f scenario-1-vulnerable/deploy/`
- [ ] Wait: `kubectl wait --for=condition=ready pod -l app=payment-service -n payment-demo`
- [ ] Show pod details: `kubectl describe pod <name>`
- [ ] Highlight service account token mount
- [ ] Run attack: `./scenario-1-vulnerable/attack/demonstrate-theft.sh`
- [ ] Point out successful Vault access
- [ ] Emphasize persistence after pod deletion

**Key Message:** "Static tokens can be stolen and used indefinitely"

### Transition (2 minutes)

- [ ] Cleanup: `kubectl delete namespace payment-demo && kubectl create namespace payment-demo`
- [ ] Explain what ZTWIM changes
- [ ] Show ZTWIM architecture diagram

### Scenario 2: Protected (10 minutes)

- [ ] Deploy: `kubectl apply -f scenario-2-protected/deploy/`
- [ ] Wait: `kubectl wait --for=condition=ready pod -l app=payment-service -n payment-demo`
- [ ] Show pod details: `kubectl describe pod <name>`
- [ ] Point out SPIRE socket injection (no static token!)
- [ ] Run same attack: `./scenario-2-protected/attack/demonstrate-theft.sh`
- [ ] Highlight all failure points:
  - [ ] No static tokens found
  - [ ] JWT-SVID expires in 5 minutes
  - [ ] OIDC validation fails
  - [ ] No persistent access

**Key Message:** "ZTWIM makes stolen credentials useless"

### Deep Dive (5 minutes)

- [ ] Show SPIRE components:
  ```bash
  kubectl get pods -n spire
  kubectl get registrationentry -n spire
  ```
- [ ] Show Vault JWT config:
  ```bash
  kubectl exec -n vault deployment/vault -- vault read auth/jwt/config
  kubectl exec -n vault deployment/vault -- vault read auth/jwt/role/payment-service
  ```
- [ ] Explain OIDC discovery:
  ```bash
  kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
    curl -k https://spire-oidc.spire.svc.cluster.local/.well-known/openid-configuration
  ```

### Comparison & Summary (5 minutes)

- [ ] Show COMPARISON.md side-by-side table
- [ ] Highlight key metrics:
  - Token lifetime: 10 years → 5 minutes
  - Attack success: Yes → No
  - Persistent access: Yes → No
- [ ] Discuss ROI and compliance benefits
- [ ] Open for Q&A

---

## During the Demo

### Do's ✅

- **Narrate your actions** - Don't type silently
- **Pause after key points** - Let information sink in
- **Show, then explain** - Run commands, then interpret output
- **Use color highlighting** - Point to important lines
- **Invite questions** - After each major section

### Don'ts ❌

- **Don't rush** - Speed kills comprehension
- **Don't skip errors** - Troubleshoot live if possible
- **Don't assume knowledge** - Define SPIFFE, SVID, OIDC
- **Don't use jargon** - Or define it first
- **Don't skip the "why"** - Always explain rationale

---

## Common Questions & Answers

### Q: What if SPIRE is compromised?

**A:** SPIRE Server's private keys should be in HSM. Upstream CA integration adds another trust layer. Defense-in-depth means even SPIRE compromise doesn't give unlimited access - tokens still expire.

### Q: Performance impact?

**A:** Negligible. SVID rotation happens in background. SPIFFE SDK handles it transparently. We've seen no measurable performance impact in production.

### Q: Works with other clouds?

**A:** Yes! SPIFFE is cloud-agnostic. OIDC federation works with AWS IAM Roles Anywhere, GCP Workload Identity, Azure AD, and more.

### Q: Can I use this with VMs, not just containers?

**A:** Absolutely. SPIRE supports VM workloads via different attestors (TPM, AWS IID, etc.). The same SPIFFE IDs work across Kubernetes and VMs.

### Q: What about existing apps that don't support SPIFFE?

**A:** Use spiffe-helper or Envoy proxy with SPIRE integration. No app code changes needed - the sidecar handles SVID fetching.

---

## Troubleshooting Guide

### Issue: Pod not getting SPIFFE ID

**Check:**
```bash
kubectl describe registrationentry -n spire
kubectl get pod <name> -n payment-demo -o yaml | grep -A5 labels
```

**Fix:** Ensure selectors match pod labels

---

### Issue: Vault OIDC failing

**Check:**
```bash
kubectl get svc -n spire
kubectl logs -n spire -l app=spire-server
```

**Fix:** Verify OIDC service is running and CA cert configured

---

### Issue: Attack script hangs

**Check:**
```bash
kubectl logs -n payment-demo <pod-name>
kubectl port-forward -n vault svc/vault 8200:8200
```

**Fix:** Ensure Vault is accessible

---

### Issue: SPIRE Agent not starting

**Check:**
```bash
kubectl logs -n spire -l app=spire-agent
kubectl describe daemonset -n spire spire-agent
```

**Fix:** Check node selectors and tolerations

---

## Post-Demo Cleanup

- [ ] Stop any port-forwards
- [ ] Delete demo namespaces (optional):
  ```bash
  kubectl delete namespace payment-demo spire vault
  ```
- [ ] Collect feedback
- [ ] Note any questions you couldn't answer
- [ ] Update demo based on feedback

---

## Success Criteria

### Audience Should Understand:

- [ ] The vulnerability of static service account tokens
- [ ] How ZTWIM provides cryptographic workload identity
- [ ] Why short-lived credentials matter
- [ ] How OIDC validation prevents replay attacks
- [ ] The value proposition of zero-trust architecture

### Audience Should Be Able To:

- [ ] Explain the attack to others
- [ ] Understand why ZTWIM prevents it
- [ ] Justify ZTWIM adoption to stakeholders
- [ ] Plan a ZTWIM pilot project

---

## Follow-Up Actions

### For Attendees:

- [ ] Share demo repository link
- [ ] Provide documentation links:
  - Red Hat ZTWIM docs
  - SPIFFE/SPIRE project
  - This demo repo
- [ ] Offer to help with pilot setup
- [ ] Schedule follow-up Q&A session

### For You:

- [ ] Document any questions you couldn't answer
- [ ] Update demo based on feedback
- [ ] Share recording (if permitted)
- [ ] Create case study if demo leads to adoption

---

## Emergency Procedures

### If Live Demo Fails Completely:

1. **Stay calm** - Technical issues happen
2. **Switch to backup** - Show pre-recorded video or screenshots
3. **Explain what should happen** - Walk through expected output
4. **Offer async demo** - "I'll share a recording after fixing this"

### If Demo Partially Works:

1. **Acknowledge the issue** - "This part isn't working as expected"
2. **Explain expected behavior** - Show what should have happened
3. **Continue with working parts** - Don't dwell on failures
4. **Troubleshoot async** - "Let me investigate and follow up"

### If Questions Stump You:

1. **Be honest** - "Great question, I don't know the answer"
2. **Promise follow-up** - "I'll research this and get back to you"
3. **Involve audience** - "Does anyone here have experience with this?"
4. **Take note** - Write it down visibly

---

## Final Pre-Demo Check (15 minutes before)

- [ ] All terminals open and configured
- [ ] Demo environment working (test run)
- [ ] Presentation materials ready
- [ ] Backup plan accessible
- [ ] Water nearby (you'll be talking a lot!)
- [ ] Phone on silent
- [ ] Confidence level: High ✅

**You've got this! The demo is solid and the value is clear.**

---

## Post-Demo Self-Evaluation

Rate yourself (1-5):

- [ ] Technical execution (smooth, no major issues)
- [ ] Clarity of explanation (audience understood)
- [ ] Engagement (audience asked questions, seemed interested)
- [ ] Timing (finished within allocated time)
- [ ] Overall impact (convinced audience of value)

**Notes for next time:**

______________________________________________________________________

______________________________________________________________________

______________________________________________________________________
