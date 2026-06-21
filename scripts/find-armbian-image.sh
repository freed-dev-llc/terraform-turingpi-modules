#!/bin/bash
#
# Find Armbian Image for Turing RK1
# Queries GitHub releases for the latest Armbian community image
#
# Usage: ./find-armbian-image.sh [OPTIONS]
#
# Options:
#   -v, --variant VARIANT   Image variant: minimal, cli, desktop (default: minimal)
#   -r, --release RELEASE   Debian release: trixie, bookworm (default: trixie)
#   --kernel FLAVOR         Kernel flavor: vendor, current, edge, any (default: vendor)
#   -l, --list              List all available images
#   -d, --download          Download the image
#   -o, --output DIR        Download directory (default: current dir)
#   --autoconfig FILE       Generate autoconfig file for first boot setup
#   --root-password PASS    Root password for autoconfig (default: 1234)
#   --hostname NAME         Hostname for autoconfig
#   --timezone TZ           Timezone for autoconfig (default: UTC)
#   --ssh-key FILE          SSH public key file to add for passwordless access
#   --static-ip IP          Static IP address (use with --gateway, --netmask, --dns)
#   --gateway IP            Gateway IP (required with --static-ip)
#   --netmask MASK          Netmask (default: 255.255.255.0)
#   --dns IP                DNS server IP (default: same as gateway)
#   -h, --help              Show this help message

set -euo pipefail

# Default values
VARIANT="minimal"
RELEASE="trixie"
KERNEL="vendor"
LIST_MODE=false
DOWNLOAD=false
OUTPUT_DIR="."
AUTOCONFIG_FILE=""
ROOT_PASSWORD="1234"
HOSTNAME=""
TIMEZONE="UTC"
SSH_KEY_FILE=""
STATIC_IP=""
GATEWAY=""
NETMASK="255.255.255.0"
DNS=""

# GitHub API
REPO="armbian/community"
API_URL="https://api.github.com/repos/${REPO}/releases"

show_help() {
    awk '/^# Usage:/{p=1} p{ if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--variant) VARIANT="$2"; shift 2 ;;
        -r|--release) RELEASE="$2"; shift 2 ;;
        --kernel) KERNEL="$2"; shift 2 ;;
        -l|--list) LIST_MODE=true; shift ;;
        -d|--download) DOWNLOAD=true; shift ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        --autoconfig) AUTOCONFIG_FILE="$2"; shift 2 ;;
        --root-password) ROOT_PASSWORD="$2"; shift 2 ;;
        --hostname) HOSTNAME="$2"; shift 2 ;;
        --timezone) TIMEZONE="$2"; shift 2 ;;
        --ssh-key) SSH_KEY_FILE="$2"; shift 2 ;;
        --static-ip) STATIC_IP="$2"; shift 2 ;;
        --gateway) GATEWAY="$2"; shift 2 ;;
        --netmask) NETMASK="$2"; shift 2 ;;
        --dns) DNS="$2"; shift 2 ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1" >&2; echo "Use -h for help." >&2; exit 1 ;;
    esac
done

# Expand a leading ~ in the SSH key path (not done automatically when the value
# comes from an =arg or a quoted string).
SSH_KEY_FILE="${SSH_KEY_FILE/#\~/$HOME}"

# Generate autoconfig if requested
if [[ -n "$AUTOCONFIG_FILE" ]]; then
    echo "Generating Armbian autoconfig: $AUTOCONFIG_FILE"
    cat > "$AUTOCONFIG_FILE" << EOF
# Armbian first run configuration
# Place this file at /boot/armbian_first_run.txt on the SD card/eMMC
# See: https://docs.armbian.com/User-Guide_Autoconfig/

# Root password (required for unattended setup)
FR_net_change_defaults=1
FR_general_delete_firstrun_file_after_completion=1

# User credentials
PRESET_ROOT_PASSWORD="${ROOT_PASSWORD}"

# Skip user creation prompt
PRESET_USER_NAME=""

# Locale and timezone
PRESET_LOCALE="en_US.UTF-8"
PRESET_TIMEZONE="${TIMEZONE}"
EOF
    # File holds the root password in cleartext — restrict to owner-only.
    chmod 600 "$AUTOCONFIG_FILE"

    if [[ -n "$HOSTNAME" ]]; then
        {
            echo ""
            echo "# Hostname (set after first boot via hostnamectl)"
            echo "# PRESET_HOSTNAME=\"${HOSTNAME}\""
            echo ""
            echo "# Note: Hostname is best set via SSH after boot:"
            echo "#   hostnamectl set-hostname ${HOSTNAME}"
        } >> "$AUTOCONFIG_FILE"
    fi

    # Add SSH key if provided
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            echo "Error: SSH key file not found: $SSH_KEY_FILE" >&2
            exit 1
        fi
        SSH_PUBKEY=$(cat "$SSH_KEY_FILE")
        cat >> "$AUTOCONFIG_FILE" << SSHEOF

# SSH Key Setup (runs on first boot)
# This script runs after first boot to set up SSH key authentication
FR_general_run_user_script=1
cat > /root/first_run_script.sh << 'SCRIPT'
#!/bin/bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${SSH_PUBKEY}" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
SCRIPT
chmod +x /root/first_run_script.sh
SSHEOF
        echo "  SSH key added from: $SSH_KEY_FILE"
    fi

    # Add static IP configuration if provided
    if [[ -n "$STATIC_IP" ]]; then
        if [[ -z "$GATEWAY" ]]; then
            echo "Error: --gateway is required when using --static-ip"
            exit 1
        fi
        # Default DNS to gateway if not specified
        if [[ -z "$DNS" ]]; then
            DNS="$GATEWAY"
        fi
        cat >> "$AUTOCONFIG_FILE" << IPEOF

# Static IP Configuration
# Disables DHCP and sets static network configuration
# (FR_net_change_defaults=1 is set above and must stay 1 for this to apply)
FR_net_static_enabled=1
FR_net_static_ip="${STATIC_IP}"
FR_net_static_gateway="${GATEWAY}"
FR_net_static_netmask="${NETMASK}"
FR_net_static_dns="${DNS}"
IPEOF
    fi

    echo ""
    echo "Autoconfig file created: $AUTOCONFIG_FILE"
    echo ""
    echo "Contents configured:"
    echo "  - Root password: ${ROOT_PASSWORD}"
    echo "  - Timezone: ${TIMEZONE}"
    if [[ -n "$HOSTNAME" ]]; then
        echo "  - Hostname hint: ${HOSTNAME}"
    fi
    if [[ -n "$SSH_KEY_FILE" ]]; then
        echo "  - SSH key: ${SSH_KEY_FILE}"
    fi
    if [[ -n "$STATIC_IP" ]]; then
        echo "  - Static IP: ${STATIC_IP} (gateway: ${GATEWAY})"
    fi
    echo ""
    echo "To use with existing installation:"
    echo "  1. Mount the eMMC/SD card on your workstation"
    echo "  2. Copy to /boot/armbian_first_run.txt"
    echo "  3. Boot the node - autoconfig runs on first boot"
    echo ""
    echo "For BMC flash with autoconfig:"
    echo "  1. Flash the image to the node"
    echo "  2. SSH to the node (root:1234 initially)"
    echo "  3. Copy autoconfig: scp $AUTOCONFIG_FILE root@NODE:/boot/armbian_first_run.txt"
    echo "  4. Reboot: ssh root@NODE reboot"
    echo ""

    # Exit if only autoconfig was requested (no image search)
    if [[ "$LIST_MODE" == "false" && "$DOWNLOAD" == "false" ]]; then
        exit 0
    fi
fi

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "Error: curl is required but not installed"
    exit 1
fi

echo "Searching for Armbian Turing RK1 images..."
echo ""

# Fetch releases to a temp file. Capturing into a shell variable and piping
# back through `echo` mangles control characters embedded in release bodies,
# which makes jq fail to parse the JSON ("control characters ... must be
# escaped") and silently return no results. Reading from a file avoids that.
RELEASES_JSON=$(mktemp)
trap 'rm -f "$RELEASES_JSON"' EXIT
if ! curl -sL "${API_URL}?per_page=30" -o "$RELEASES_JSON" || [[ ! -s "$RELEASES_JSON" ]]; then
    echo "Error: Failed to fetch releases from GitHub"
    exit 1
fi

# Find Turing RK1 images
if [[ "$LIST_MODE" == "true" ]]; then
    echo "Available Turing RK1 images:"
    echo "----------------------------"

    jq -r '
        .[].assets[]
        | select(.name | test("Turing-rk1.*\\.img\\.xz$"))
        | "\(.name)\n  URL: \(.browser_download_url)\n  Size: \(.size / 1048576 | floor)MB\n"
    ' "$RELEASES_JSON" || echo "No Turing RK1 images found in recent releases"

    exit 0
fi

# Find matching image. Pin the kernel flavor (vendor/current/edge) so e.g. the
# vendor RK1 image is selected deterministically; "any" matches any flavor.
if [[ "$KERNEL" == "any" ]]; then
    PATTERN="Turing-rk1_${RELEASE}.*${VARIANT}\\.img\\.xz$"
else
    PATTERN="Turing-rk1_${RELEASE}_${KERNEL}.*${VARIANT}\\.img\\.xz$"
fi
IMAGE_INFO=$(jq -r --arg pat "$PATTERN" '
    [.[].assets[]
    | select(.name | test($pat; "i"))]
    | sort_by(.created_at) | reverse | .[0] // empty
    | {name: .name, url: .browser_download_url, size: .size}
' "$RELEASES_JSON")

if [[ -z "$IMAGE_INFO" || "$IMAGE_INFO" == "null" ]]; then
    echo "No matching image found for:"
    echo "  Variant: $VARIANT"
    echo "  Release: $RELEASE"
    echo "  Kernel:  $KERNEL"
    echo ""
    echo "Try: $0 --list  (or --kernel any to match any flavor)"
    exit 1
fi

IMAGE_NAME=$(echo "$IMAGE_INFO" | jq -r '.name')
IMAGE_URL=$(echo "$IMAGE_INFO" | jq -r '.url')
IMAGE_SIZE=$(echo "$IMAGE_INFO" | jq -r '.size / 1048576 | floor')

echo "Found: $IMAGE_NAME"
echo "Size:  ${IMAGE_SIZE}MB"
echo "URL:   $IMAGE_URL"
echo ""

if [[ "$DOWNLOAD" == "true" ]]; then
    echo "Downloading to ${OUTPUT_DIR}/${IMAGE_NAME}..."
    mkdir -p "$OUTPUT_DIR"
    # -f so an HTTP error (e.g. 404) fails instead of silently writing the error
    # page to the image file, which would later be flashed to a node.
    if ! curl -fL --retry 3 -o "${OUTPUT_DIR}/${IMAGE_NAME}" "$IMAGE_URL"; then
        echo "Error: download failed for $IMAGE_URL" >&2
        rm -f "${OUTPUT_DIR}/${IMAGE_NAME}"
        exit 1
    fi
    # Verify archive integrity — a truncated download or error page is not valid xz.
    if [[ "$IMAGE_NAME" == *.xz ]] && command -v xz &>/dev/null; then
        if ! xz -t "${OUTPUT_DIR}/${IMAGE_NAME}" 2>/dev/null; then
            echo "Error: downloaded file failed integrity check (corrupt or not an xz archive): ${OUTPUT_DIR}/${IMAGE_NAME}" >&2
            rm -f "${OUTPUT_DIR}/${IMAGE_NAME}"
            exit 1
        fi
    fi
    echo ""
    echo "Download complete: ${OUTPUT_DIR}/${IMAGE_NAME}"
else
    echo "To download: $0 -v $VARIANT -r $RELEASE --download"
    echo ""
    echo "Or use directly with BMC flash API:"
    echo "  curl -sk -u USER:PASS \"https://BMC_IP/api/bmc?opt=set&type=flash&node=N&file=${IMAGE_URL}\""
fi
