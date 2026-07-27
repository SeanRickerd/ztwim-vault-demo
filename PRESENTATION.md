# ZTWIM 1.1 + Vault Integration - Demo Presentation Guide

## Presentation Flow (30-40 minutes)

### Part 1: Introduction (5 minutes)

**Opening Statement:**
> "Today we'll demonstrate how ZTWIM 1.1 (Zero Trust Workload Identity Manager) integrated with HashiCorp Vault prevents a common but critical attack: service account token theft and replay."

**Key Points:**
- Traditional Kubernetes auth uses long-lived static tokens
- These tokens can be stolen and used indefinitely
- ZTWIM replaces static tokens with cryptographic workload identities
- Vault OIDC integration validates these identities

**Slide: Attack Scenario**
```
Attacker → Compromise Pod → Steal Token → Replay from External System → Access Secrets
```

---

### Part 2: Scenario 1 - Vulnerable Deployment (10 minutes)

**Setup Explanation:**
> "First, let's see how traditional Kubernetes service account authentication works and why it's vulnerable."

**Architecture Diagram Points:**
- Pod has service account token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`
- Token is a long-lived JWT (can last years)
- Vault uses Kubernetes auth method to validate the token
- No binding to pod's runtime identity

**Demo Steps:**

1. **Show the Deployment**
   ```bash
   kubectl get pods -n payment-demo
   kubectl describe pod <payment-service-pod> | grep -A5 Volumes
   ```
   Point out: "See the service account token mounted as a volume"

2. **Simulate Pod Compromise**
   ```bash
   kubectl exec -it <payment-service-pod> -n payment-demo -- /bin/bash
   ```
   Say: "We're now inside the compromised pod as an attacker"

3. **Steal the Token**
   ```bash
   cat /var/run/secrets/kubernetes.io/serviceaccount/token
   ```
   Say: "This token is readable by any process in the pod"

4. **Run Attack Script**
   ```bash
   cd scenario-1-vulnerable/attack
   ./demonstrate-theft.sh
   ```

**Key Observations:**
- ✗ Token successfully stolen
- ✗ Token replayed from external system
- ✗ Vault access obtained
- ✗ Secrets retrieved
- ✗ Access persists after pod deletion

**Pause for Questions**

---

### Part 3: Understanding ZTWIM (5 minutes)

**Concept Introduction:**
> "ZTWIM is built on SPIFFE/SPIRE, which provides cryptographic workload identities."

**Key Concepts:**

1. **SPIFFE ID**
   - Unique identifier: `spiffe://cluster.local/ns/payment-demo/sa/payment-service`
   - Embedded in cryptographically-signed credentials

2. **SVID (SPIFFE Verifiable Identity Document)**
   - X.509-SVID: mTLS certificate
   - JWT-SVID: Short-lived JWT for API authentication
   - Expires in minutes (default: 5 minutes)

3. **Workload Attestation**
   - SPIRE Agent verifies workload's runtime identity
   - Checks: namespace, service account, node, container ID
   - Cannot be forged or impersonated

4. **Workload API**
   - Unix domain socket in pod
   - Workloads request SVIDs dynamically
   - No static credentials in filesystem

**Architecture Diagram:**
```
Pod → SPIRE Agent (DaemonSet) → SPIRE Server → Issues SVID
                                      ↓
                                 OIDC Discovery
                                      ↓
                                    Vault
                              (validates via OIDC)
```

---

### Part 4: Scenario 2 - Protected Deployment (15 minutes)

**Setup Explanation:**
> "Now let's see the same attack against a ZTWIM-protected deployment."

**Configuration Highlights:**

1. **SPIRE Server Configuration**
   ```yaml
   oidc:
     enabled: true  # Enables OIDC discovery for Vault
   jwt:
     ttl: 5m  # Short-lived tokens
   ```

2. **Registration Entry**
   ```yaml
   spiffeId: spiffe://cluster.local/ns/payment-demo/sa/payment-service
   selectors:
     - type: k8s
       value: ns:payment-demo
     - type: k8s
       value: sa:payment-service
   ```
   Say: "This binds the SPIFFE ID to specific pod attributes"

3. **Vault JWT Auth**
   ```bash
   vault write auth/jwt/config \
     oidc_discovery_url="https://spire-oidc.spire.svc.cluster.local"
   
   vault write auth/jwt/role/payment-service \
     bound_subject="spiffe://cluster.local/ns/payment-demo/sa/payment-service"
   ```
   Say: "Vault trusts SPIRE as an OIDC provider and validates SPIFFE IDs"

**Demo Steps:**

1. **Show the Protected Deployment**
   ```bash
   kubectl get pods -n payment-demo
   kubectl exec -it <payment-service-pod> -- ls -la /var/run/secrets/
   ```
   Point out: "No static tokens in the filesystem!"

2. **Show SPIRE Workload API**
   ```bash
   kubectl exec -it <payment-service-pod> -- ls -la /run/spire/sockets/
   ```
   Say: "Credentials are obtained dynamically via this Unix socket"

3. **Run Attack Script**
   ```bash
   cd scenario-2-protected/attack
   ./demonstrate-theft.sh
   ```

**Key Observations:**
- ✓ No static tokens to steal
- ✓ Even if JWT-SVID is extracted from memory:
  - Expires in 5 minutes
  - Cannot be replayed (OIDC signature validation)
  - Bound to original workload identity
- ✓ Attack fails completely
- ✓ No persistent access

**Comparison Table:**
Show side-by-side comparison from demo output

---

### Part 5: Deep Dive - How ZTWIM Prevents the Attack (5 minutes)

**Multi-Layer Defense:**

1. **Layer 1: No Static Secrets**
   - Credentials not stored in filesystem
   - Must be requested via Workload API
   - Attacker can't just read a file

2. **Layer 2: Short-Lived Credentials**
   - JWT-SVID expires in 5 minutes
   - Exfiltrated credential becomes useless quickly
   - Attacker has very narrow window

3. **Layer 3: Cryptographic Binding**
   - SPIFFE ID embedded in JWT-SVID
   - Cryptographically signed by SPIRE
   - Cannot be forged without SPIRE's private key (HSM-protected)

4. **Layer 4: Workload Attestation**
   - SPIRE Agent verifies pod's runtime identity
   - Checks namespace, service account, node
   - External system cannot pass attestation

5. **Layer 5: OIDC Validation**
   - Vault validates JWT signature via OIDC discovery
   - Fetches signing keys from SPIRE's JWKS endpoint
   - Verifies issuer, audience, expiration, claims
   - External replay fails validation

**Diagram: Attack Timeline**
```
Without ZTWIM:
T+0:   Compromise pod
T+1m:  Steal token
T+2m:  Exfiltrate token
T+3m:  Authenticate to Vault ✗ SUCCESS
T+1yr: Still authenticated ✗ PERSISTENT ACCESS

With ZTWIM:
T+0:   Compromise pod
T+1m:  Attempt to steal token (none found)
T+2m:  Extract JWT-SVID from memory
T+3m:  Attempt Vault auth ✓ FAILS (OIDC validation)
T+5m:  JWT-SVID expires
T+6m:  No access maintained ✓ ATTACK MITIGATED
```

---

### Part 6: Q&A and Advanced Topics (5-10 minutes)

**Common Questions:**

**Q: What if the attacker compromises the SPIRE Agent on the same node?**
A: SPIRE Agent has limited privileges. It can only issue SVIDs for workloads it has attested. Compromising one agent doesn't give access to other nodes' workloads. For additional security, SPIRE Server can be configured with upstream authorities and TPM-based node attestation.

**Q: What about the performance impact of 5-minute credential rotation?**
A: The SPIFFE SDK handles rotation automatically in the background. Applications don't need to manage it. Performance impact is negligible - it's an asynchronous background operation.

**Q: Can this work with other secret management systems besides Vault?**
A: Yes! ZTWIM/SPIRE supports OIDC federation, which works with any OIDC-compliant system. This includes AWS IAM Roles Anywhere, Google Cloud Workload Identity, Azure AD, and more.

**Q: How does this compare to Kubernetes projected service account tokens?**
A: Projected tokens are an improvement (bound audiences, expiration), but they're still Kubernetes-specific. SPIFFE provides a universal workload identity standard that works across platforms (Kubernetes, VMs, serverless). SPIFFE also offers X.509-SVIDs for mTLS.

**Q: What's the operational overhead?**
A: On OpenShift, ZTWIM is operator-managed. Once configured, it's fully automated:
- SPIRE Agents run as DaemonSet (one per node)
- Registration entries can be created via CRDs
- Automatic SVID rotation
- OIDC discovery handles key rotation
- Minimal ops burden after initial setup

**Advanced Topics:**

1. **SPIRE Server Federation**
   - Multiple SPIRE servers can federate
   - Cross-cluster workload identity
   - Useful for hybrid/multi-cloud

2. **Upstream Authorities**
   - SPIRE can use external CAs (AWS PCA, Google CA Service)
   - Provides additional trust anchor

3. **Nested SPIFFE**
   - SPIRE Agents can attest other SPIRE Agents
   - Hierarchical trust domains

---

### Part 7: Summary and Next Steps (2 minutes)

**Key Takeaways:**

✓ **Static secrets are a critical vulnerability**
  - Long-lived, easy to steal, unlimited replay

✓ **ZTWIM provides cryptographic workload identity**
  - Dynamic, short-lived, bound to runtime context

✓ **Vault OIDC integration adds defense-in-depth**
  - Signature validation, claims verification, expiration checks

✓ **Zero-trust principles in action**
  - Never trust, always verify
  - Least privilege with time-bound credentials

**Next Steps:**

1. **Pilot ZTWIM in Dev/Test**
   - Start with non-critical workloads
   - Validate integration with your secret management

2. **Define Registration Strategy**
   - Decide on SPIFFE ID naming conventions
   - Automate registration entry creation

3. **Update Applications**
   - Integrate SPIFFE SDK (available in Go, Java, Python, etc.)
   - Replace static secret retrieval with Workload API calls

4. **Plan Production Rollout**
   - Configure SPIRE HA (multiple servers)
   - Consider upstream CA integration
   - Set up monitoring and alerting

**Resources:**
- [Red Hat ZTWIM Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/zero-trust-workload-identity-manager)
- [SPIFFE/SPIRE Project](https://spiffe.io)
- [This Demo Repository](../README.md)

---

## Demo Tips

### Before the Presentation

- [ ] Pre-deploy infrastructure (Vault, ZTWIM)
- [ ] Test both scenarios end-to-end
- [ ] Prepare terminal windows (split screen or tmux)
- [ ] Have architecture diagrams ready
- [ ] Test timing (ensure demo fits in allocated time)

### During the Demo

- **Keep terminals visible** - Use large font sizes
- **Narrate actions** - Don't just type silently
- **Highlight key output** - Point out critical lines
- **Pause for questions** - After each major section
- **Have a backup plan** - Screenshots if live demo fails

### Terminal Setup

Recommended tmux layout:
```
┌─────────────────────────────────────┬──────────────────┐
│                                     │                  │
│  Terminal 1: Commands               │  Terminal 3:     │
│  (kubectl, attack scripts)          │  Logs/Watch      │
│                                     │  (pod logs)      │
├─────────────────────────────────────┤                  │
│                                     │                  │
│  Terminal 2: Vault/SPIRE            │                  │
│  (vault commands, spire-server)     │                  │
│                                     │                  │
└─────────────────────────────────────┴──────────────────┘
```

### Troubleshooting

**Issue: SPIRE Agent not starting**
- Check node selector/tolerations
- Verify SPIRE Server is healthy
- Check agent logs: `kubectl logs -n spire -l app=spire-agent`

**Issue: Vault OIDC discovery failing**
- Verify SPIRE OIDC service is running
- Check CA certificate configuration
- Test OIDC endpoint manually with curl

**Issue: JWT-SVID not being issued**
- Verify registration entry matches workload
- Check selectors (namespace, service account)
- Look at SPIRE Server logs

---

## Customization Ideas

### For Security-Focused Audiences
- Emphasize cryptographic properties
- Show SPIFFE spec compliance
- Discuss threat model in detail
- Demonstrate OIDC discovery internals

### For DevOps Audiences
- Focus on operational simplicity
- Highlight automation (operators, CRDs)
- Discuss CI/CD integration
- Show monitoring/observability

### For Compliance Audiences
- Map to zero-trust frameworks (NIST 800-207)
- Discuss audit trails and logging
- Show credential lifecycle management
- Demonstrate least-privilege enforcement

### Extended Demo Ideas
1. **Multi-cluster federation** - Show cross-cluster identity
2. **mTLS with X.509-SVIDs** - Service-to-service authentication
3. **Integration with service mesh** - SPIRE + Istio
4. **Database authentication** - SPIFFE-based DB access
5. **CI/CD pipelines** - Secretless deployments

