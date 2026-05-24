#!/bin/bash
#
# K3s Cluster Wipe Script
# Drains nodes, wipes K3s data and drives, shuts down nodes, and verifies power off via TuringPi BMC
#
# Usage: ./k3s-wipe.sh [OPTIONS]
#
# Options:
#   -k, --kubeconfig PATH     Path to kubeconfig file (default: ./kubeconfig)
#   -n, --nodes IPs           Comma-separated list of node IPs
#   -b, --bmc IP              TuringPi BMC IP address (or TURINGPI_ENDPOINT env)
#   -u, --user USER           SSH/BMC username (default: root, or TURINGPI_USERNAME env)
#   -p, --password PASS       BMC password (default: turing, or TURINGPI_PASSWORD env)
#   -i, --ssh-key PATH        SSH private key path (default: ~/.ssh/id_rsa)
#   -d, --disks DEVICES       Comma-separated disks to wipe (default: /dev/nvme0n1)
#   --no-nvme                 Skip NVMe wipe
#   --no-emmc                 Skip eMMC wipe (eMMC wiped by default)
#   --clean-terraform         Also clean terraform state files
#   --force-power-off         Force power off via BMC if graceful shutdown fails
#   --log FILE                Log output to file
#   --dry-run                 Show commands without executing
#   -h, --help                Show this help message
#
# Environment Variables:
#   TURINGPI_ENDPOINT   - BMC endpoint (alternative to -b flag)
#   TURINGPI_USERNAME   - BMC/SSH username (alternative to -u flag)
#   TURINGPI_PASSWORD   - BMC password (alternative to -p flag)
#
# Credential Files (checked if env vars not set):
#   ~/.secrets/turing-pi-cluster-bmc - combined BMC creds (ip:/username:/password: lines), checked first
#   ~/.secrets/turingpi-bmc-user     - BMC username (fallback)
#   ~/.secrets/turingpi-bmc-password - BMC password (fallback)
#   ~/.secrets/turingpi-cluster      - SSH private key (fallback: turingpi-bmc)

set -euo pipefail

# Default values
KUBECONFIG_PATH="./kubeconfig"
NODES=""
BMC_IP="${TURINGPI_ENDPOINT:-}"
BMC_USER="${TURINGPI_USERNAME:-}"
BMC_PASSWORD="${TURINGPI_PASSWORD:-}"
SSH_KEY="$HOME/.ssh/id_rsa"
USER_DISKS="/dev/nvme0n1"
WIPE_NVME=true
WIPE_EMMC=true
CLEAN_TERRAFORM=false
FORCE_POWER_OFF=false
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
    head -35 "$0" | tail -32
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

    # Use SSH key from secrets if default doesn't exist
    if [[ ! -f "$SSH_KEY" ]]; then
        if [[ -f "$secrets_dir/turingpi-cluster" ]]; then
            SSH_KEY="$secrets_dir/turingpi-cluster"
        elif [[ -f "$secrets_dir/turingpi-bmc" ]]; then
            SSH_KEY="$secrets_dir/turingpi-bmc"
        fi
    fi

    # Apply defaults
    : "${BMC_USER:=root}"
    : "${BMC_PASSWORD:=turing}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        -n|--nodes) NODES="$2"; shift 2 ;;
        -b|--bmc) BMC_IP="$2"; shift 2 ;;
        -u|--user) BMC_USER="$2"; shift 2 ;;
        -p|--password) BMC_PASSWORD="$2"; shift 2 ;;
        -i|--ssh-key) SSH_KEY="$2"; shift 2 ;;
        -d|--disks) USER_DISKS="$2"; shift 2 ;;
        --no-nvme) WIPE_NVME=false; shift ;;
        --no-emmc) WIPE_EMMC=false; shift ;;
        --clean-terraform) CLEAN_TERRAFORM=true; shift ;;
        --force-power-off) FORCE_POWER_OFF=true; shift ;;
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

# Convert comma-separated nodes to array
IFS=',' read -ra NODE_ARRAY <<< "$NODES"

# Initialize log file
if [[ -n "$LOG_FILE" ]]; then
    echo "=== K3s Wipe Log - $(date) ===" > "$LOG_FILE"
fi

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_output "[DRY-RUN] $*"
        return 0
    else
        "$@"
    fi
}

ssh_cmd() {
    local node=$1
    shift
    local cmd="$*"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_output "[DRY-RUN] ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${BMC_USER}@${node} '$cmd'"
        return 0
    fi

    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${BMC_USER}@${node}" "$cmd" 2>/dev/null
}

# Get node slot from IP
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

# Wait for node to power off
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
            ((files_removed++))
        fi
    done

    if [[ -d "$terraform_dir/.terraform" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_output "[DRY-RUN] rm -rf $terraform_dir/.terraform"
        else
            rm -rf "$terraform_dir/.terraform"
        fi
        ((files_removed++))
    fi

    if [[ $files_removed -gt 0 ]]; then
        log_info "  Removed $files_removed terraform state file(s)/directories"
    else
        log_info "  No terraform state files found"
    fi
}

echo "=============================================="
echo "  K3s Cluster Wipe Workflow"
echo "=============================================="
echo ""
echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
echo -e "${RED}║       ⚠️  WARNING: DATA DESTRUCTION ⚠️       ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Nodes to wipe: ${NODE_ARRAY[*]}"
echo "BMC: $BMC_IP"
echo "SSH Key: $SSH_KEY"
echo ""
echo "Data to be PERMANENTLY DESTROYED:"
[[ "$WIPE_NVME" == "true" ]] && echo -e "  ${RED}• NVMe drives: $USER_DISKS${NC}"
[[ "$WIPE_EMMC" == "true" ]] && echo -e "  ${RED}• eMMC boot drives: /dev/mmcblk0${NC}"
echo "  • K3s data directories"
echo "  • Kubernetes state and configurations"
echo ""
[[ "$CLEAN_TERRAFORM" == "true" ]] && echo "Terraform cleanup: enabled"
[[ "$FORCE_POWER_OFF" == "true" ]] && echo "Force power off: enabled"
[[ -n "$LOG_FILE" ]] && echo "Logging to: $LOG_FILE"
[[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
echo ""

# Confirm before proceeding
if [[ "$DRY_RUN" != "true" ]]; then
    echo -e "${RED}This will PERMANENTLY DESTROY ALL DATA on these nodes!${NC}"
    if [[ "$WIPE_EMMC" == "true" ]]; then
        echo -e "${RED}Nodes will be UNBOOTABLE until re-flashed via BMC!${NC}"
    fi
    echo ""
    read -rp "Type 'DESTROY' to confirm: " confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        log_warn "Aborted by user"
        exit 0
    fi
fi

STEP=1
echo ""

# Step: Drain nodes from Kubernetes cluster
log_step "Step $STEP: Draining nodes from Kubernetes cluster..."
STEP=$((STEP + 1))

if [[ -f "$KUBECONFIG_PATH" ]]; then
    for node_ip in "${NODE_ARRAY[@]}"; do
        # Get node name from IP
        node_name=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes -o wide 2>/dev/null | \
            grep "$node_ip" | awk '{print $1}' || echo "")

        if [[ -n "$node_name" ]]; then
            log_info "  Draining node $node_name ($node_ip)..."
            run_cmd kubectl --kubeconfig="$KUBECONFIG_PATH" drain "$node_name" \
                --ignore-daemonsets --delete-emptydir-data --force --timeout=60s 2>/dev/null || {
                log_warn "  Drain failed or timed out for $node_name (continuing...)"
            }
        else
            log_warn "  Could not find node name for $node_ip (may already be removed)"
        fi
    done
else
    log_warn "Kubeconfig not found at $KUBECONFIG_PATH, skipping drain step"
fi

echo ""
log_step "Step $STEP: Stopping K3s service on all nodes..."
STEP=$((STEP + 1))

for node in "${NODE_ARRAY[@]}"; do
    log_info "  Stopping K3s on $node..."
    ssh_cmd "$node" "systemctl stop k3s k3s-agent 2>/dev/null; killall -9 containerd-shim-runc-v2 2>/dev/null" || {
        log_warn "  Failed to stop K3s on $node (may not be running)"
    }
done

echo ""
log_step "Step $STEP: Wiping K3s data directories..."
STEP=$((STEP + 1))

for node in "${NODE_ARRAY[@]}"; do
    log_info "  Wiping K3s data on $node..."
    # Stop any remaining containers
    ssh_cmd "$node" "crictl rm -f \$(crictl ps -aq) 2>/dev/null" || true
    # Unmount any remaining mounts
    ssh_cmd "$node" "umount -R /var/lib/kubelet 2>/dev/null" || true
    ssh_cmd "$node" "umount -R /run/k3s 2>/dev/null" || true
    # Remove K3s data
    ssh_cmd "$node" "rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /var/lib/cni /etc/cni /run/k3s 2>/dev/null" || {
        log_warn "  Failed to wipe K3s data on $node"
    }
    # Clean up iptables rules
    ssh_cmd "$node" "iptables -F && iptables -t nat -F && iptables -t mangle -F 2>/dev/null" || true
done

if [[ "$WIPE_NVME" == "true" && -n "$USER_DISKS" ]]; then
    echo ""
    log_step "Step $STEP: Wiping user disks (NVMe)..."
    STEP=$((STEP + 1))

    IFS=',' read -ra DISK_ARRAY <<< "$USER_DISKS"
    for node in "${NODE_ARRAY[@]}"; do
        for disk in "${DISK_ARRAY[@]}"; do
            # Check if disk exists
            if ssh_cmd "$node" "test -b $disk" 2>/dev/null; then
                log_info "  Wiping $disk on $node..."
                # Unmount any partitions
                ssh_cmd "$node" "umount ${disk}* 2>/dev/null" || true
                # Wipe partition table and first 100MB
                ssh_cmd "$node" "wipefs -a $disk 2>/dev/null; dd if=/dev/zero of=$disk bs=1M count=100 2>/dev/null" || {
                    log_warn "  Failed to wipe $disk on $node"
                }
            else
                log_warn "  Disk $disk not found on $node (skipping)"
            fi
        done
    done
fi

if [[ "$WIPE_EMMC" == "true" ]]; then
    echo ""
    log_step "Step $STEP: Wiping eMMC boot drive (/dev/mmcblk0)..."
    STEP=$((STEP + 1))

    for node in "${NODE_ARRAY[@]}"; do
        log_info "  Wiping eMMC on $node..."
        # Wipe partition table and first 100MB
        ssh_cmd "$node" "wipefs -a /dev/mmcblk0 2>/dev/null; dd if=/dev/zero of=/dev/mmcblk0 bs=1M count=100 2>/dev/null" || {
            log_warn "  Failed to wipe eMMC on $node"
        }
    done
fi

echo ""
log_step "Step $STEP: Shutting down nodes..."
STEP=$((STEP + 1))

for node in "${NODE_ARRAY[@]}"; do
    log_info "  Shutting down $node..."
    ssh_cmd "$node" "shutdown -h now" || {
        log_warn "  Shutdown command failed for $node (may already be down)"
    }
done

echo ""
log_step "Step $STEP: Verifying power off via BMC..."
STEP=$((STEP + 1))

sleep 10  # Give nodes time to shutdown

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
    kubeconfig_dir=$(dirname "$KUBECONFIG_PATH")
    if [[ -f "$kubeconfig_dir/main.tf" || -f "$kubeconfig_dir/terraform.tfstate" ]]; then
        clean_terraform_state "$kubeconfig_dir"
    elif [[ -f "./main.tf" || -f "./terraform.tfstate" ]]; then
        clean_terraform_state "."
    else
        log_warn "No terraform configuration found in current directory or kubeconfig directory"
    fi

    # Also remove generated files
    for file in "kubeconfig" "k3s-token"; do
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
    echo "  1. Flash new OS image via BMC (if needed)"
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
