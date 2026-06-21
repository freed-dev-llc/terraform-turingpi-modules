#!/bin/bash
#
# Cluster Pre-flight Check Script
# Validates environment before cluster deployment
#
# Usage: ./cluster-preflight.sh [OPTIONS]
#
# Options:
#   -t, --type TYPE       Cluster type: talos or k3s (required)
#   -n, --nodes IPs       Comma-separated list of node IPs (required)
#   -b, --bmc IP          TuringPi BMC IP address (required)
#   -u, --user USER       BMC username (default: root)
#   -p, --password PASS   BMC password (default: turing)
#   -i, --ssh-key PATH    SSH private key for K3s (default: ~/.ssh/id_rsa)
#   --node-user USER      SSH login user for node checks (default: root)
#   --talosconfig PATH    Talosconfig path for Talos (default: ./talosconfig)
#   -h, --help            Show this help message

set -euo pipefail

# Default values
CLUSTER_TYPE=""
NODES=""
BMC_IP=""
BMC_USER=""
BMC_PASSWORD=""
SSH_KEY="$HOME/.ssh/id_rsa"
NODE_SSH_USER="root"
TALOSCONFIG="./talosconfig"

# Load credentials from secrets files
load_credentials() {
    local secrets_dir="$HOME/.secrets"

    # Try turing-pi-cluster-bmc format first (contains ip, username, password)
    if [[ -f "$secrets_dir/turing-pi-cluster-bmc" ]]; then
        if [[ -z "$BMC_USER" ]]; then
            BMC_USER=$(grep "^username:" "$secrets_dir/turing-pi-cluster-bmc" | cut -d' ' -f2) || true
        fi
        if [[ -z "$BMC_PASSWORD" ]]; then
            BMC_PASSWORD=$(grep "^password:" "$secrets_dir/turing-pi-cluster-bmc" | cut -d' ' -f2) || true
        fi
        if [[ -z "$BMC_IP" ]]; then
            BMC_IP=$(grep "^ip:" "$secrets_dir/turing-pi-cluster-bmc" | cut -d' ' -f2) || true
        fi
    fi

    # Try individual files
    if [[ -z "$BMC_USER" && -f "$secrets_dir/turingpi-bmc-user" ]]; then
        BMC_USER=$(tr -d '\n' < "$secrets_dir/turingpi-bmc-user")
    fi
    if [[ -z "$BMC_PASSWORD" && -f "$secrets_dir/turingpi-bmc-password" ]]; then
        BMC_PASSWORD=$(tr -d '\n' < "$secrets_dir/turingpi-bmc-password")
    fi

    # Use SSH key from secrets if available
    if [[ -f "$secrets_dir/turingpi-cluster" ]]; then
        SSH_KEY="$secrets_dir/turingpi-cluster"
    elif [[ -f "$secrets_dir/turingpi-bmc" ]]; then
        SSH_KEY="$secrets_dir/turingpi-bmc"
    fi

    # Apply defaults
    : "${BMC_USER:=root}"
    : "${BMC_PASSWORD:=turing}"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

show_help() {
    head -18 "$0" | tail -15
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type) CLUSTER_TYPE="$2"; shift 2 ;;
        -n|--nodes) NODES="$2"; shift 2 ;;
        -b|--bmc) BMC_IP="$2"; shift 2 ;;
        -u|--user) BMC_USER="$2"; shift 2 ;;
        -p|--password) BMC_PASSWORD="$2"; shift 2 ;;
        -i|--ssh-key) SSH_KEY="$2"; shift 2 ;;
        --node-user) NODE_SSH_USER="$2"; shift 2 ;;
        --talosconfig) TALOSCONFIG="$2"; shift 2 ;;
        -h|--help) show_help ;;
        *) log_error "Unknown option: $1"; show_help ;;
    esac
done

# Load credentials from secrets files (command-line args override)
load_credentials

# Validate required arguments
if [[ -z "$CLUSTER_TYPE" ]]; then
    log_error "Cluster type required. Use -t talos or -t k3s"
    exit 1
fi

if [[ "$CLUSTER_TYPE" != "talos" && "$CLUSTER_TYPE" != "k3s" ]]; then
    log_error "Invalid cluster type. Use 'talos' or 'k3s'"
    exit 1
fi

if [[ -z "$NODES" ]]; then
    log_error "Node IPs required. Use -n or --nodes"
    exit 1
fi

if [[ -z "$BMC_IP" ]]; then
    log_error "BMC IP required. Use -b or --bmc"
    exit 1
fi

# Convert comma-separated nodes to array
IFS=',' read -ra NODE_ARRAY <<< "$NODES"

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

pass_check() {
    log_pass "$1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

fail_check() {
    log_fail "$1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

warn_check() {
    log_warn "$1"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
}

echo "=============================================="
echo "  Cluster Pre-flight Checks"
echo "=============================================="
echo ""
echo "Cluster Type: $CLUSTER_TYPE"
echo "Nodes: ${NODE_ARRAY[*]}"
echo "BMC: $BMC_IP"
echo ""

# =============================================================================
# Section 1: Local Environment Checks
# =============================================================================
echo "--- Local Environment ---"

# Check required tools
log_check "Checking required tools..."

if command -v terraform &>/dev/null; then
    pass_check "terraform installed ($(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1))"
else
    fail_check "terraform not found"
fi

if command -v kubectl &>/dev/null; then
    pass_check "kubectl installed ($(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo 'unknown'))"
else
    fail_check "kubectl not found"
fi

if command -v curl &>/dev/null; then
    pass_check "curl installed"
else
    fail_check "curl not found"
fi

if command -v jq &>/dev/null; then
    pass_check "jq installed"
else
    warn_check "jq not found (optional but recommended)"
fi

# Cluster-type specific tools
if [[ "$CLUSTER_TYPE" == "talos" ]]; then
    if command -v talosctl &>/dev/null; then
        pass_check "talosctl installed ($(talosctl version --client 2>/dev/null | grep 'Client:' | awk '{print $2}' || echo 'unknown'))"
    else
        fail_check "talosctl not found (required for Talos clusters)"
    fi
fi

if [[ "$CLUSTER_TYPE" == "k3s" ]]; then
    if [[ -f "$SSH_KEY" ]]; then
        pass_check "SSH key exists: $SSH_KEY"
    else
        fail_check "SSH key not found: $SSH_KEY"
    fi
fi

echo ""

# =============================================================================
# Section 2: BMC Connectivity
# =============================================================================
echo "--- BMC Connectivity ---"

log_check "Checking BMC reachability..."
if ping -c 1 -W 2 "$BMC_IP" &>/dev/null; then
    pass_check "BMC reachable at $BMC_IP"
else
    fail_check "BMC not reachable at $BMC_IP"
fi

log_check "Checking BMC API access..."
BMC_RESPONSE=$(curl -fsk -u "${BMC_USER}:${BMC_PASSWORD}" \
    "https://${BMC_IP}/api/bmc?opt=get&type=power" 2>/dev/null || echo "error")

if [[ "$BMC_RESPONSE" != "error" && "$BMC_RESPONSE" != "" ]]; then
    pass_check "BMC API accessible"

    # Check power status of nodes
    for node in "${NODE_ARRAY[@]}"; do
        last_octet=$(echo "$node" | cut -d'.' -f4)
        case $last_octet in
            73) slot=1 ;;
            74) slot=2 ;;
            75) slot=3 ;;
            76) slot=4 ;;
            *) slot=$((last_octet - 72)) ;;
        esac

        # BMC returns quoted values, e.g. {"node1":"0",...}; tolerate optional
        # quotes/whitespace (matches the wipe scripts' parser, see #52).
        power_state=$(echo "$BMC_RESPONSE" | sed -nE "s/.*\"node${slot}\"[[:space:]]*:[[:space:]]*\"?([01])\"?.*/\1/p")
        if [[ "$power_state" == "1" ]]; then
            pass_check "Node $node (slot $slot): POWERED ON"
        elif [[ "$power_state" == "0" ]]; then
            warn_check "Node $node (slot $slot): POWERED OFF"
        else
            warn_check "Node $node (slot $slot): UNKNOWN STATE"
        fi
    done
else
    fail_check "BMC API not accessible (check credentials)"
fi

echo ""

# =============================================================================
# Section 3: Node Connectivity
# =============================================================================
echo "--- Node Connectivity ---"

for node in "${NODE_ARRAY[@]}"; do
    log_check "Checking node $node..."

    if ping -c 1 -W 2 "$node" &>/dev/null; then
        pass_check "Node $node is reachable"

        if [[ "$CLUSTER_TYPE" == "k3s" ]]; then
            # Check SSH connectivity for K3s
            if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                "${NODE_SSH_USER}@${node}" "echo 'SSH OK'" &>/dev/null; then
                pass_check "SSH connection to $node successful"

                # Check for required packages
                if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                    "${NODE_SSH_USER}@${node}" "which iscsiadm" &>/dev/null; then
                    pass_check "open-iscsi installed on $node"
                else
                    warn_check "open-iscsi NOT installed on $node (required for Longhorn)"
                fi
            else
                fail_check "SSH connection to $node failed"
            fi
        fi

        if [[ "$CLUSTER_TYPE" == "talos" ]]; then
            # Check Talos API connectivity
            if [[ -f "$TALOSCONFIG" ]]; then
                if talosctl --talosconfig "$TALOSCONFIG" --nodes "$node" \
                    version &>/dev/null 2>&1; then
                    pass_check "Talos API accessible on $node"
                else
                    warn_check "Talos API not responding on $node (may be normal if not yet deployed)"
                fi
            fi
        fi
    else
        warn_check "Node $node is not reachable (may be powered off)"
    fi
done

echo ""

# =============================================================================
# Section 4: Network Checks
# =============================================================================
echo "--- Network Checks ---"

log_check "Checking DNS resolution..."
if host google.com &>/dev/null || nslookup google.com &>/dev/null 2>&1; then
    pass_check "DNS resolution working"
else
    warn_check "DNS resolution may have issues"
fi

log_check "Checking internet connectivity..."
if curl -s --connect-timeout 5 https://registry.terraform.io &>/dev/null; then
    pass_check "Terraform Registry reachable"
else
    warn_check "Terraform Registry not reachable"
fi

if [[ "$CLUSTER_TYPE" == "talos" ]]; then
    if curl -s --connect-timeout 5 https://factory.talos.dev &>/dev/null; then
        pass_check "Talos Image Factory reachable"
    else
        warn_check "Talos Image Factory not reachable"
    fi
fi

echo ""

# =============================================================================
# Section 5: Terraform State
# =============================================================================
echo "--- Terraform State ---"

if [[ -f "terraform.tfstate" ]]; then
    warn_check "Existing terraform.tfstate found - may need cleanup before fresh deployment"
else
    pass_check "No existing terraform.tfstate (clean deployment)"
fi

if [[ -d ".terraform" ]]; then
    pass_check "Terraform initialized (.terraform exists)"
else
    warn_check "Terraform not initialized (run 'terraform init')"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=============================================="
echo "  Pre-flight Check Summary"
echo "=============================================="
echo ""
echo -e "${GREEN}Passed:${NC}  $CHECKS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNED"
echo -e "${RED}Failed:${NC}  $CHECKS_FAILED"
echo ""

if [[ $CHECKS_FAILED -gt 0 ]]; then
    log_error "Pre-flight checks failed. Please resolve issues before deployment."
    exit 1
elif [[ $CHECKS_WARNED -gt 0 ]]; then
    log_warn "Pre-flight checks passed with warnings. Review before proceeding."
    exit 0
else
    log_info "All pre-flight checks passed. Ready for deployment!"
    exit 0
fi
