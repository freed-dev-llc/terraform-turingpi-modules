#!/bin/bash
#
# Talos Cluster Wipe Script
# Wipes all drives, shuts down nodes, and verifies power off via TuringPi BMC
#
# Usage: ./talos-wipe.sh [OPTIONS]
#
# Options:
#   -t, --talosconfig PATH    Path to talosconfig file (default: ./talosconfig)
#   -n, --nodes IPs           Comma-separated list of node IPs
#   -b, --bmc IP              TuringPi BMC IP address (or TURINGPI_ENDPOINT env)
#   -u, --user USER           BMC username (default: root, or TURINGPI_USERNAME env)
#   -p, --password PASS       BMC password (default: turing, or TURINGPI_PASSWORD env)
#   -d, --disks DEVICES       Comma-separated user disks to wipe (default: /dev/nvme0n1)
#   --no-nvme                 Skip NVMe wipe
#   --clean-terraform         Also clean terraform state files
#   --force-power-off         Force power off via BMC if graceful shutdown fails
#   --yes, -y                 Skip interactive confirmation (for automation)
#   --log FILE                Log output to file
#   --dry-run                 Show commands without executing
#   -h, --help                Show this help message
#
# Environment Variables:
#   TURINGPI_ENDPOINT   - BMC endpoint (alternative to -b flag)
#   TURINGPI_USERNAME   - BMC username (alternative to -u flag)
#   TURINGPI_PASSWORD   - BMC password (alternative to -p flag)
#
# Credential Files (checked if env vars not set):
#   ~/.secrets/turing-pi-cluster-bmc - combined BMC creds (ip:/username:/password: lines), checked first
#   ~/.secrets/turingpi-bmc-user     - BMC username (fallback)
#   ~/.secrets/turingpi-bmc-password - BMC password (fallback)

set -euo pipefail

# Default values
TALOSCONFIG="./talosconfig"
NODES=""
BMC_IP="${TURINGPI_ENDPOINT:-}"
BMC_USER="${TURINGPI_USERNAME:-}"
BMC_PASSWORD="${TURINGPI_PASSWORD:-}"
USER_DISKS="/dev/nvme0n1"
WIPE_NVME=true
CLEAN_TERRAFORM=false
FORCE_POWER_OFF=false
SKIP_CONFIRM=false
LOG_FILE=""
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_output() {
    local msg="$1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

log_info() { log_output "${GREEN}[INFO]${NC} $1"; }
log_warn() { log_output "${YELLOW}[WARN]${NC} $1"; }
log_error() { log_output "${RED}[ERROR]${NC} $1"; }
log_step() { log_output "${BLUE}[STEP]${NC} $1"; }

show_help() {
    head -32 "$0" | tail -29
    exit 0
}

# Load credentials from files if not set via env
load_credentials() {
    local secrets_dir="$HOME/.secrets"

    # BMC IP - strip protocol if present
    if [[ -n "$BMC_IP" ]]; then
        BMC_IP=$(echo "$BMC_IP" | sed 's|https\?://||' | sed 's|/.*||')
    fi

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

    # Apply defaults
    : "${BMC_USER:=root}"
    : "${BMC_PASSWORD:=turing}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--talosconfig) TALOSCONFIG="$2"; shift 2 ;;
        -n|--nodes) NODES="$2"; shift 2 ;;
        -b|--bmc) BMC_IP="$2"; shift 2 ;;
        -u|--user) BMC_USER="$2"; shift 2 ;;
        -p|--password) BMC_PASSWORD="$2"; shift 2 ;;
        -d|--disks) USER_DISKS="$2"; shift 2 ;;
        --no-nvme) WIPE_NVME=false; shift ;;
        --clean-terraform) CLEAN_TERRAFORM=true; shift ;;
        --force-power-off) FORCE_POWER_OFF=true; shift ;;
        --yes|-y) SKIP_CONFIRM=true; shift ;;
        --log) LOG_FILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) show_help ;;
        *) log_error "Unknown option: $1"; show_help ;;
    esac
done

# Load credentials from env/files
load_credentials

# Validate required arguments
if [[ -z "$NODES" ]]; then
    log_error "Node IPs required. Use -n or --nodes"
    exit 1
fi

if [[ -z "$BMC_IP" ]]; then
    log_error "BMC IP required. Use -b, --bmc, or set TURINGPI_ENDPOINT"
    exit 1
fi

if [[ ! -f "$TALOSCONFIG" ]]; then
    log_warn "Talosconfig not found: $TALOSCONFIG (will skip talosctl commands)"
fi

# Convert comma-separated nodes to array
IFS=',' read -ra NODE_ARRAY <<< "$NODES"

# Initialize log file
if [[ -n "$LOG_FILE" ]]; then
    echo "=== Talos Wipe Log - $(date) ===" > "$LOG_FILE"
fi

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_output "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# Get node slot from IP (last octet mapping)
get_slot_from_ip() {
    local ip=$1
    local last_octet
    last_octet=$(echo "$ip" | cut -d'.' -f4)
    case $last_octet in
        73) echo 1 ;;
        74) echo 2 ;;
        75) echo 3 ;;
        76) echo 4 ;;
        *) echo $((last_octet - 72)) ;;
    esac
}

# Check BMC power status for a slot
check_power_status() {
    local slot=$1
    local response
    response=$(curl -sk -u "${BMC_USER}:${BMC_PASSWORD}" \
        "https://${BMC_IP}/api/bmc?opt=get&type=power" 2>/dev/null || echo "{}")

    # The BMC returns quoted values, e.g. {"node1":"0",...}. Extract the 0/1
    # tolerating optional quotes/whitespace; empty (no match) falls through to
    # "unknown" below. (Previously matched only an unquoted digit, so every
    # check returned "unknown" and power-off was never detected — see #52.)
    local power_state
    power_state=$(echo "$response" | sed -nE "s/.*\"node${slot}\"[[:space:]]*:[[:space:]]*\"?([01])\"?.*/\1/p")

    if [[ "$power_state" == "0" ]]; then
        echo "off"
    elif [[ "$power_state" == "1" ]]; then
        echo "on"
    else
        echo "unknown"
    fi
}

# Force power off a node via BMC
force_power_off() {
    local slot=$1
    log_warn "  Force powering off slot $slot via BMC..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_output "[DRY-RUN] curl -sk -u ${BMC_USER}:*** 'https://${BMC_IP}/api/bmc?opt=set&type=power&node${slot}=0'"
        return 0
    fi

    local response
    response=$(curl -sk -u "${BMC_USER}:${BMC_PASSWORD}" \
        "https://${BMC_IP}/api/bmc?opt=set&type=power&node${slot}=0" 2>/dev/null || echo "error")

    if [[ "$response" == *"error"* || "$response" == "" ]]; then
        log_error "  Failed to force power off slot $slot"
        return 1
    fi
    return 0
}

# Wait for node to power off with retries
wait_for_power_off() {
    local slot=$1
    local max_attempts=${2:-30}
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        local status
        status=$(check_power_status "$slot")
        if [[ "$status" == "off" ]]; then
            return 0
        fi
        ((attempt++))
        sleep 2
    done
    return 1
}

# Clean terraform state files
clean_terraform_state() {
    local terraform_dir="${1:-.}"

    log_step "Cleaning Terraform state files in $terraform_dir..."

    local files_removed=0

    for pattern in "terraform.tfstate" "terraform.tfstate.backup" ".terraform.lock.hcl"; do
        if [[ -f "$terraform_dir/$pattern" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_output "[DRY-RUN] rm $terraform_dir/$pattern"
            else
                rm -f "$terraform_dir/$pattern"
            fi
            files_removed=$((files_removed + 1))
        fi
    done

    if [[ -d "$terraform_dir/.terraform" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_output "[DRY-RUN] rm -rf $terraform_dir/.terraform"
        else
            rm -rf "$terraform_dir/.terraform"
        fi
        files_removed=$((files_removed + 1))
    fi

    if [[ $files_removed -gt 0 ]]; then
        log_info "  Removed $files_removed terraform state file(s)/directories"
    else
        log_info "  No terraform state files found"
    fi
}

echo "=============================================="
echo "  Talos Cluster Wipe Workflow"
echo "=============================================="
echo ""
echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
echo -e "${RED}║       ⚠️  WARNING: DATA DESTRUCTION ⚠️       ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Nodes to wipe: ${NODE_ARRAY[*]}"
echo "BMC: $BMC_IP"
echo "Talosconfig: $TALOSCONFIG"
echo ""
echo "Data to be PERMANENTLY DESTROYED:"
echo "  • Talos system partitions (STATE, EPHEMERAL)"
[[ "$WIPE_NVME" == "true" ]] && echo -e "  ${RED}• NVMe drives: $USER_DISKS${NC}"
echo ""
echo -e "${YELLOW}Note: eMMC is system disk and cannot be wiped via talosctl reset${NC}"
echo ""
[[ "$CLEAN_TERRAFORM" == "true" ]] && echo "Terraform cleanup: enabled"
[[ "$FORCE_POWER_OFF" == "true" ]] && echo "Force power off: enabled"
[[ -n "$LOG_FILE" ]] && echo "Logging to: $LOG_FILE"
[[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
echo ""

# Confirm before proceeding (unless --yes flag or dry-run)
if [[ "$DRY_RUN" != "true" && "$SKIP_CONFIRM" != "true" ]]; then
    echo -e "${RED}This will PERMANENTLY DESTROY ALL DATA on these nodes!${NC}"
    echo ""
    read -rp "Type 'DESTROY' to confirm: " confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        log_warn "Aborted by user"
        exit 0
    fi
fi

STEP=1
echo ""

# Step: Wipe Talos system partitions
log_step "Step $STEP: Wiping Talos system partitions (STATE, EPHEMERAL)..."
STEP=$((STEP + 1))

if [[ -f "$TALOSCONFIG" ]]; then
    # Build the wipe command as an ARRAY, not a space-joined string. Passing a
    # single string to run_cmd would be exec'd as one argv[0] ("command not
    # found", exit 127) — the failure was swallowed below, so the reset silently
    # no-op'd in real mode while dry-run (which prints "$*") still looked fine.
    WIPE_ARGS=(talosctl --talosconfig "$TALOSCONFIG" reset --nodes "$NODES" --graceful=false)
    WIPE_ARGS+=(--system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL)

    # Add NVMe disks if enabled
    # Note: eMMC is system disk and cannot be wiped via talosctl reset
    if [[ "$WIPE_NVME" == "true" && -n "$USER_DISKS" ]]; then
        IFS=',' read -ra DISK_ARRAY <<< "$USER_DISKS"
        for disk in "${DISK_ARRAY[@]}"; do
            [[ -n "$disk" ]] || continue
            WIPE_ARGS+=(--user-disks-to-wipe "$disk")
        done
    fi

    # Don't reboot - we want to shutdown
    WIPE_ARGS+=(--reboot=false)

    run_cmd "${WIPE_ARGS[@]}" || {
        log_warn "Reset command returned non-zero (node may already be in maintenance mode)"
    }
else
    log_warn "Skipping talosctl reset - talosconfig not found"
fi

echo ""
log_step "Step $STEP: Shutting down nodes..."
STEP=$((STEP + 1))

for node in "${NODE_ARRAY[@]}"; do
    log_info "  Shutting down $node..."
    if [[ -f "$TALOSCONFIG" ]]; then
        run_cmd talosctl --talosconfig "$TALOSCONFIG" shutdown --nodes "$node" --force 2>/dev/null || {
            log_warn "  Shutdown command failed for $node (may already be down)"
        }
    else
        log_warn "  Cannot shutdown $node - no talosconfig"
    fi
done

echo ""
log_step "Step $STEP: Verifying power off via BMC..."
STEP=$((STEP + 1))

sleep 5  # Give nodes time to shutdown

nodes_still_on=()
for node in "${NODE_ARRAY[@]}"; do
    slot=$(get_slot_from_ip "$node")
    log_info "  Checking node $node (slot $slot)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_output "[DRY-RUN] Would check power status for slot $slot"
        continue
    fi

    if wait_for_power_off "$slot" 15; then
        log_info "  ✓ Node $node (slot $slot) is OFF"
    else
        status=$(check_power_status "$slot")
        log_warn "  ✗ Node $node (slot $slot) status: $status"
        nodes_still_on+=("$node:$slot")
    fi
done

# Force power off remaining nodes if enabled
if [[ ${#nodes_still_on[@]} -gt 0 && "$FORCE_POWER_OFF" == "true" ]]; then
    echo ""
    log_step "Step $STEP: Force powering off remaining nodes..."
    STEP=$((STEP + 1))

    for node_slot in "${nodes_still_on[@]}"; do
        node=$(echo "$node_slot" | cut -d':' -f1)
        slot=$(echo "$node_slot" | cut -d':' -f2)

        if force_power_off "$slot"; then
            sleep 3
            if [[ $(check_power_status "$slot") == "off" ]]; then
                log_info "  ✓ Node $node (slot $slot) force powered OFF"
                # Remove from nodes_still_on
                nodes_still_on=("${nodes_still_on[@]/$node_slot/}")
            else
                log_error "  ✗ Node $node (slot $slot) still ON after force power off"
            fi
        fi
    done
fi

# Clean terraform state if requested
if [[ "$CLEAN_TERRAFORM" == "true" ]]; then
    echo ""
    log_step "Step $STEP: Cleaning Terraform state..."
    STEP=$((STEP + 1))

    # Look for terraform files in common locations
    terraform_dir=$(dirname "$TALOSCONFIG")
    if [[ -f "$terraform_dir/main.tf" || -f "$terraform_dir/terraform.tfstate" ]]; then
        clean_terraform_state "$terraform_dir"
    elif [[ -f "./main.tf" || -f "./terraform.tfstate" ]]; then
        clean_terraform_state "."
    else
        log_warn "No terraform configuration found in current directory or talosconfig directory"
    fi
fi

# Also remove generated files
if [[ "$CLEAN_TERRAFORM" == "true" ]]; then
    for file in "kubeconfig" "talosconfig" "controlplane.yaml" "worker.yaml"; do
        if [[ -f "./$file" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_output "[DRY-RUN] rm ./$file"
            else
                rm -f "./$file"
                log_info "  Removed ./$file"
            fi
        fi
    done
fi

echo ""
echo "=============================================="

# Filter out empty elements from nodes_still_on
mapfile -t nodes_still_on < <(printf '%s\n' "${nodes_still_on[@]}" | grep -v '^$')

if [[ ${#nodes_still_on[@]} -eq 0 || "$DRY_RUN" == "true" ]]; then
    log_info "Wipe workflow complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Flash new OS image via BMC"
    echo "  2. Power on nodes"
    echo "  3. Deploy new cluster"
else
    log_warn "Some nodes may still be powered on: ${nodes_still_on[*]}"
    echo ""
    echo "To manually power off via BMC:"
    echo "  curl -sk -u $BMC_USER:*** \\"
    echo "    'https://$BMC_IP/api/bmc?opt=set&type=power&node1=0&node2=0&node3=0&node4=0'"
fi
echo "=============================================="

[[ -n "$LOG_FILE" ]] && log_info "Log saved to: $LOG_FILE"
