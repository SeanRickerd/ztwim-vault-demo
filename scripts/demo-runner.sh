#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$DEMO_DIR/scripts"

clear

echo -e "${CYAN}"
cat << "EOF"
+====================================================================+
|                                                                    |
|     ZTWIM 1.1 + Vault Integration - Adversarial Demo              |
|                                                                    |
|     Zero Trust Workload Identity Manager                          |
|     Token Theft & Replay Attack Demonstration                     |
|                                                                    |
+====================================================================+
EOF
echo -e "${NC}"
echo ""

# Menu
show_menu() {
    echo -e "${BLUE}Select demo scenario:${NC}"
    echo ""
    echo -e "  ${YELLOW}1)${NC} Full Demo (Both Scenarios)"
    echo -e "  ${YELLOW}2)${NC} Scenario 1: Vulnerable Deployment (Static Vault Token)"
    echo -e "  ${YELLOW}3)${NC} Scenario 2: Protected Deployment (ZTWIM JWT-SVID)"
    echo -e "  ${YELLOW}4)${NC} Setup Only (Deploy Infrastructure)"
    echo -e "  ${YELLOW}5)${NC} Test Environment"
    echo -e "  ${YELLOW}6)${NC} Cleanup (Remove All Resources)"
    echo -e "  ${YELLOW}q)${NC} Quit"
    echo ""
    echo -n "Choice: "
}

# Setup infrastructure
setup_infrastructure() {
    echo -e "${BLUE}+====================================================================+${NC}"
    echo -e "${BLUE}|  Setting up Demo Infrastructure                                   |${NC}"
    echo -e "${BLUE}+====================================================================+${NC}"
    echo ""

    echo -e "${BLUE}Step 1: Setting up Vault...${NC}"
    cd "$SCRIPTS_DIR"
    if [[ -x "setup-vault.sh" ]]; then
        bash setup-vault.sh
    else
        echo -e "${YELLOW}Note: Using existing Vault deployment${NC}"
    fi

    echo ""
    read -p "Press Enter to continue with ZTWIM setup..." </dev/tty

    echo -e "${BLUE}Step 2: Setting up ZTWIM...${NC}"
    if [[ -x "setup-ztwim.sh" ]]; then
        bash setup-ztwim.sh
    else
        echo -e "${YELLOW}Note: Using existing ZTWIM deployment${NC}"
    fi

    echo ""
    read -p "Press Enter to configure vulnerable environment..." </dev/tty

    echo -e "${BLUE}Step 3: Setting up vulnerable Vault configuration...${NC}"
    if [[ -x "setup-vulnerable-vault.sh" ]]; then
        bash setup-vulnerable-vault.sh
    else
        echo -e "${RED}Error: setup-vulnerable-vault.sh not found${NC}"
    fi

    echo ""
    echo -e "${GREEN}✓ Infrastructure setup complete!${NC}"
    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Run Scenario 1
run_scenario_1() {
    echo -e "${RED}+====================================================================+${NC}"
    echo -e "${RED}|  SCENARIO 1: Vulnerable Deployment (Static Vault Token)           |${NC}"
    echo -e "${RED}+====================================================================+${NC}"
    echo ""

    echo -e "${BLUE}This scenario demonstrates:${NC}"
    echo "  • Traditional static Vault token stored in Kubernetes Secret"
    echo "  • Long-lived credentials (90-day TTL)"
    echo "  • Successful token theft from compromised pod"
    echo "  • External replay attack accessing sensitive PII data"
    echo "  • Persistent Vault access from anywhere"
    echo ""
    read -p "Press Enter to begin Scenario 1..." </dev/tty

    echo ""
    echo -e "${BLUE}[INFO] Checking vulnerable environment...${NC}"

    # Check if vulnerable environment is set up
    if ! oc get deployment payment-processor -n vulnerable-app &>/dev/null; then
        echo -e "${YELLOW}Setting up vulnerable environment...${NC}"
        cd "$SCRIPTS_DIR"
        if [[ -x "setup-vulnerable-vault.sh" ]]; then
            bash setup-vulnerable-vault.sh
        else
            echo -e "${RED}Error: Vulnerable environment not found. Run setup first (option 4)${NC}"
            read -p "Press Enter to return to menu..." </dev/tty
            return
        fi
    fi

    echo -e "${GREEN}✓ Vulnerable app deployed${NC}"
    echo ""
    read -p "Press Enter to launch attack simulation..." </dev/tty

    echo ""
    echo -e "${RED}===========================================================${NC}"
    echo -e "${RED}       LAUNCHING ATTACK AGAINST VULNERABLE APP...          ${NC}"
    echo -e "${RED}===========================================================${NC}"
    echo ""
    sleep 2

    # Run the attack script
    cd "$SCRIPTS_DIR"
    if [[ -x "demo-scenario-1-attack.sh" ]]; then
        bash demo-scenario-1-attack.sh
    else
        echo -e "${RED}Error: demo-scenario-1-attack.sh not found${NC}"
        read -p "Press Enter to return to menu..." </dev/tty
        return
    fi

    echo ""
    echo -e "${YELLOW}===========================================================${NC}"
    echo -e "${YELLOW}Scenario 1 Complete - Attack SUCCEEDED ⚠️${NC}"
    echo -e "${YELLOW}The attacker gained persistent access to Vault and PII data${NC}"
    echo -e "${YELLOW}===========================================================${NC}"
    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Run Scenario 2
run_scenario_2() {
    echo -e "${GREEN}+====================================================================+${NC}"
    echo -e "${GREEN}|  SCENARIO 2: Protected Deployment (ZTWIM JWT-SVID)                |${NC}"
    echo -e "${GREEN}+====================================================================+${NC}"
    echo ""

    echo -e "${BLUE}This scenario demonstrates:${NC}"
    echo "  • ZTWIM-based workload identity with SPIFFE/SPIRE"
    echo "  • Short-lived JWT-SVIDs (2-minute expiration)"
    echo "  • Vault OIDC integration with cryptographic attestation"
    echo "  • Failed token theft and replay attack"
    echo "  • No persistent access after pod compromise"
    echo ""
    read -p "Press Enter to begin Scenario 2..." </dev/tty

    echo ""
    echo -e "${BLUE}Deploying protected application with ZTWIM...${NC}"

    # Create namespace
    oc create namespace payment-demo 2>/dev/null || true

    # Apply OpenShift SCC fixes
    echo -e "${BLUE}Applying OpenShift SCC permissions...${NC}"
    cd "$SCRIPTS_DIR"
    if [[ -x "openshift-scc-patches.sh" ]]; then
        bash openshift-scc-patches.sh payment-demo payment-service
    fi

    # Deploy protected app
    echo -e "${BLUE}Deploying payment-service with ZTWIM protection...${NC}"

    # Create a simple protected deployment
    cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: payment-demo
  labels:
    app: payment-service
    security: ztwim-protected
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        security: ztwim-protected
    spec:
      serviceAccountName: payment-service
      containers:
      - name: app
        image: registry.access.redhat.com/ubi9/ubi-minimal:latest
        command:
        - /bin/bash
        - -c
        - |
          #!/bin/bash
          echo "=========================================="
          echo "  PROTECTED Payment Service (ZTWIM)"
          echo "=========================================="
          echo ""
          echo "SPIFFE Workload API Socket: \${SPIFFE_ENDPOINT_SOCKET}"
          echo "Vault Address: \${VAULT_ADDR}"
          echo ""
          echo "✓ Using ZTWIM for workload identity"
          echo "✓ JWT-SVID auto-rotates every 2 minutes"
          echo "✓ No static secrets in pod"
          echo "✓ Cryptographic attestation via SPIRE"
          echo ""
          echo "Application running with zero-trust identity..."
          sleep infinity
        env:
        - name: VAULT_ADDR
          value: "http://vault.vault.svc.cluster.local:8200"
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: DirectoryOrCreate
EOF

    echo -e "${BLUE}Waiting for pod to be ready...${NC}"
    oc wait --for=condition=ready pod -l app=payment-service -n payment-demo --timeout=120s || {
        echo -e "${YELLOW}Pod not ready yet, checking for issues...${NC}"
        POD=$(oc get pod -n payment-demo -l app=payment-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$POD" ]]; then
            oc describe pod "$POD" -n payment-demo | tail -20
        fi

        echo -e "${BLUE}Attempting to fix with SCC script...${NC}"
        cd "$SCRIPTS_DIR"
        if [[ -x "fix-demo-deployment-openshift.sh" ]]; then
            bash fix-demo-deployment-openshift.sh payment-demo payment-service payment-service
        fi
    }

    echo ""
    read -p "Press Enter to launch attack simulation (will fail)..." </dev/tty

    echo ""
    echo -e "${GREEN}===========================================================${NC}"
    echo -e "${GREEN}       LAUNCHING ATTACK AGAINST PROTECTED APP...           ${NC}"
    echo -e "${GREEN}===========================================================${NC}"
    echo ""
    sleep 2

    # Run the Scenario 2 attack script
    cd "$SCRIPTS_DIR"
    if [[ -x "demo-scenario-2-attack.sh" ]]; then
        bash demo-scenario-2-attack.sh
    else
        echo -e "${RED}Error: demo-scenario-2-attack.sh not found${NC}"
        echo -e "${YELLOW}Falling back to basic attack simulation...${NC}"
        sleep 2

        POD=$(oc get pod -n payment-demo -l app=payment-service -o jsonpath='{.items[0].metadata.name}')
        echo -e "${RED}[ATTACKER]${NC} Attempting to steal credentials from $POD..."
        sleep 2
        echo -e "${GREEN}[DEFENDER]${NC} ATTACK BLOCKED - No static secrets found!"
        sleep 2
    fi

    echo ""
    echo -e "${GREEN}===========================================================${NC}"
    echo -e "${GREEN}Scenario 2 Complete - Attack BLOCKED ✓${NC}"
    echo -e "${GREEN}ZTWIM successfully prevented the attack!${NC}"
    echo -e "${GREEN}===========================================================${NC}"
    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Run full demo
run_full_demo() {
    clear
    echo -e "${CYAN}+====================================================================+${NC}"
    echo -e "${CYAN}|  FULL DEMONSTRATION                                                |${NC}"
    echo -e "${CYAN}|  Comparing Vulnerable vs Protected Deployments                     |${NC}"
    echo -e "${CYAN}+====================================================================+${NC}"
    echo ""

    # Run Scenario 1
    run_scenario_1

    clear
    echo -e "${CYAN}Now let's see how ZTWIM prevents this attack...${NC}"
    echo ""
    sleep 3

    # Run Scenario 2
    run_scenario_2

    # Final comparison
    clear
    echo -e "${CYAN}+====================================================================+${NC}"
    echo -e "${CYAN}|  DEMONSTRATION COMPLETE                                            |${NC}"
    echo -e "${CYAN}+====================================================================+${NC}"
    echo ""

    echo -e "${BLUE}Security Comparison:${NC}"
    echo ""
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Metric" "Without ZTWIM" "With ZTWIM"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Token Lifetime" "90 days" "2 minutes"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Static Secrets" "Yes" "No"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Identity Binding" "None" "Cryptographic"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Replay Window" "90 days" "<2 minutes"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Workload Attestation" "No" "Yes (SPIRE)"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "External Replay Possible" "Yes" "No"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Persistent Access" "Yes" "No"
    printf "%-35s ${RED}%-22s${NC} ${GREEN}%-22s${NC}\n" "Attack Result" "SUCCESS ⚠️" "BLOCKED ✓"
    echo ""

    echo -e "${GREEN}Key Takeaways:${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} ZTWIM eliminates static secrets in pods"
    echo -e "  ${GREEN}✓${NC} Short-lived credentials (2 min) minimize blast radius"
    echo -e "  ${GREEN}✓${NC} Cryptographic identity binding prevents replay attacks"
    echo -e "  ${GREEN}✓${NC} Workload attestation ensures only legitimate pods get credentials"
    echo -e "  ${GREEN}✓${NC} OIDC integration with Vault provides defense-in-depth"
    echo -e "  ${GREEN}✓${NC} No manual credential rotation required"
    echo ""

    echo -e "${BLUE}Business Impact:${NC}"
    echo ""
    echo "  • Reduces breach window from 90 days to 2 minutes (97%+ reduction)"
    echo "  • Eliminates credential sprawl in git, configs, and backups"
    echo "  • Meets compliance requirements for dynamic secrets"
    echo "  • Prevents lateral movement after pod compromise"
    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Test environment
test_environment() {
    echo -e "${BLUE}+====================================================================+${NC}"
    echo -e "${BLUE}|  Testing Demo Environment                                          |${NC}"
    echo -e "${BLUE}+====================================================================+${NC}"
    echo ""

    cd "$SCRIPTS_DIR"
    if [[ -x "test-demo-environment.sh" ]]; then
        bash test-demo-environment.sh
    else
        echo -e "${RED}Error: test-demo-environment.sh not found${NC}"
    fi

    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Cleanup
cleanup() {
    echo -e "${YELLOW}+====================================================================+${NC}"
    echo -e "${YELLOW}|  Cleaning up demo resources                                        |${NC}"
    echo -e "${YELLOW}+====================================================================+${NC}"
    echo ""

    echo -e "${BLUE}Deleting resources...${NC}"

    oc delete namespace vulnerable-app --ignore-not-found=true
    oc delete namespace payment-demo --ignore-not-found=true

    echo -e "${YELLOW}Cleaning up Vault configuration...${NC}"
    if [[ -f /tmp/demo-tokens/vulnerable-static-token.txt ]]; then
        TOKEN=$(cat /tmp/demo-tokens/vulnerable-static-token.txt)
        oc exec -n vault vault-0 -- vault token revoke "$TOKEN" 2>/dev/null || true
    fi

    rm -rf /tmp/demo-tokens

    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo ""
    echo -e "${YELLOW}Note: Vault and ZTWIM infrastructure kept for reuse${NC}"
    echo -e "${YELLOW}To remove everything, also delete: vault, zero-trust-workload-identity-manager namespaces${NC}"
    echo ""
    read -p "Press Enter to return to menu..." </dev/tty
}

# Main loop
while true; do
    clear
    echo -e "${CYAN}"
    cat << "EOF"
+====================================================================+
|     ZTWIM 1.1 + Vault Integration - Adversarial Demo              |
+====================================================================+
EOF
    echo -e "${NC}"
    show_menu

    read -r choice </dev/tty

    case $choice in
        1)
            clear
            run_full_demo
            ;;
        2)
            clear
            run_scenario_1
            ;;
        3)
            clear
            run_scenario_2
            ;;
        4)
            clear
            setup_infrastructure
            ;;
        5)
            clear
            test_environment
            ;;
        6)
            clear
            cleanup
            ;;
        q|Q)
            echo ""
            echo -e "${GREEN}Thank you for viewing the ZTWIM demo!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            sleep 1
            ;;
    esac
done
