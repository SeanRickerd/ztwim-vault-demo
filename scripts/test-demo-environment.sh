#!/bin/bash
# Test Demo Environment - Verify all components are working

echo "=== Testing Demo Environment ==="
echo ""

# Test 1: Vault
echo "Test 1: Vault accessible..."
if oc get route vault -n vault >/dev/null 2>&1; then
    echo "✓ Vault route exists"
    VAULT_ADDR="http://$(oc get route vault -n vault -o jsonpath='{.spec.host}')"
    if curl -sf "$VAULT_ADDR/v1/sys/health?standbycode=200&sealedcode=200&uninitcode=200" >/dev/null; then
        echo "✓ Vault is accessible"
    else
        echo "✗ Vault not responding"
    fi
else
    echo "✗ Vault route not found"
fi

# Test 2: Vulnerable app
echo ""
echo "Test 2: Vulnerable app deployed..."
if oc get deployment payment-processor -n vulnerable-app >/dev/null 2>&1; then
    echo "✓ Vulnerable app deployment exists"
    if oc get pod -n vulnerable-app -l app=payment-processor | grep -q Running; then
        echo "✓ Vulnerable app pod running"
    else
        echo "✗ Vulnerable app pod not running"
    fi
else
    echo "✗ Vulnerable app not deployed"
fi

# Test 3: Static token
echo ""
echo "Test 3: Static token configured..."
if [[ -f /tmp/demo-tokens/vulnerable-static-token.txt ]]; then
    echo "✓ Static token file exists"
    TOKEN=$(cat /tmp/demo-tokens/vulnerable-static-token.txt)
    if [[ ${#TOKEN} -gt 50 ]]; then
        echo "✓ Token looks valid (${#TOKEN} chars)"
    fi
else
    echo "✗ Static token not found"
fi

# Test 4: Vault secrets
echo ""
echo "Test 4: Vault contains PII data..."
if [[ -f /tmp/demo-tokens/vulnerable-static-token.txt ]]; then
    TOKEN=$(cat /tmp/demo-tokens/vulnerable-static-token.txt)
    VAULT_ADDR="http://$(oc get route vault -n vault -o jsonpath='{.spec.host}')"
    if curl -sf -H "X-Vault-Token: $TOKEN" "$VAULT_ADDR/v1/secret/data/customer-data" | grep -q "credit_card"; then
        echo "✓ PII data accessible with static token"
    else
        echo "✗ Cannot access PII data"
    fi
else
    echo "⚠ Skipping (no token)"
fi

# Test 5: Protected app (Scenario 2)
echo ""
echo "Test 5: Protected app (payment-demo)..."
if oc get namespace payment-demo >/dev/null 2>&1; then
    echo "✓ payment-demo namespace exists"
    if oc get deployment payment-service -n payment-demo >/dev/null 2>&1; then
        echo "✓ payment-service deployment exists"
        if oc get pod -n payment-demo -l app=payment-service | grep -q Running; then
            echo "✓ payment-service pod running"
        else
            echo "⚠ payment-service pod not running yet"
        fi
    else
        echo "⚠ payment-service not deployed yet"
    fi
else
    echo "⚠ payment-demo namespace not created yet (normal if not run Scenario 2)"
fi

# Test 6: ZTWIM operator
echo ""
echo "Test 6: ZTWIM operator..."
if oc get csv -n zero-trust-workload-identity-manager | grep -q Succeeded; then
    echo "✓ ZTWIM operator installed"
else
    echo "✗ ZTWIM operator not ready"
fi

echo ""
echo "=== Test Summary ==="
echo ""
echo "Ready for demos:"
echo "  Scenario 1: ./demo-scenario-1-attack.sh"
echo "  Scenario 2: <use your demo runner>"
echo ""
echo "If any tests failed, check DEMO-FIXES-SUMMARY.md"
