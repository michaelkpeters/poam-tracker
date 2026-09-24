#!/usr/bin/env bash
# =============================================================================
# POAM Tracker — Proxmox VE Helper Script
# Inspired by tteck/Proxmox VE Helper Scripts
# =============================================================================
set -e

APP="POAM Tracker"
var_version="1.0"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RD=$'\033[0;31m'
GN=$'\033[0;32m'
YW=$'\033[0;33m'
BL=$'\033[0;34m'
CL=$'\033[0m'

msg_info() {
    echo -e "${BL}[INFO]${CL} $1"
}

msg_ok() {
    echo -e "${GN}[OK]${CL} $1"
}

msg_error() {
    echo -e "${RD}[ERROR]${CL} $1"
}

msg_warn() {
    echo -e "${YW}[WARN]${CL} $1"
}

# ---------------------------------------------------------------------------
# Error handler: show a message before set -e kills the script
# ---------------------------------------------------------------------------
trap 'msg_error "Script failed at line $LINENO. Check output above for details."' ERR

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
clear
cat <<"EOF"
   ____  ____    ___    __  ____________
  / __ \/ __ \  /   |  /  |/  / ____/   |
 / /_/ / / / / / /| | / /|_/ / __/ / /| |
/ ____/ /_/ / / ___ |/ /  / / /___/ ___ |
/_/    \____/ /_/  |_/_/  /_/_____/_/  |_|
   Plan of Action and Milestones Tracker
EOF
echo ""

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
CTID=${CTID:-}
HN="poam-tracker"
DISK_SIZE="8"
CORES="1"
RAM="512"
SWAP="512"
BRG="vmbr0"
NET="dhcp"
GATE=""
PW=""
SSH="no"

# ---------------------------------------------------------------------------
# Prompt for container settings
# ---------------------------------------------------------------------------
echo ""
printf "${YW}Container ID (auto-detect if blank):${CL} "
read -r CTID
if [[ -z "$CTID" ]]; then
    # Find next available CTID
    CTID=$(pvesh get /cluster/nextid)
fi

printf "${YW}Container hostname [${HN}]:${CL} "
read -r input_hn
[[ -n "$input_hn" ]] && HN="$input_hn"

printf "${YW}Disk size (GB) [${DISK_SIZE}]:${CL} "
read -r input_disk
[[ -n "$input_disk" ]] && DISK_SIZE="$input_disk"

printf "${YW}CPU cores [${CORES}]:${CL} "
read -r input_cores
[[ -n "$input_cores" ]] && CORES="$input_cores"

printf "${YW}RAM (MB) [${RAM}]:${CL} "
read -r input_ram
[[ -n "$input_ram" ]] && RAM="$input_ram"

printf "${YW}Bridge [${BRG}]:${CL} "
read -r input_brg
[[ -n "$input_brg" ]] && BRG="$input_brg"

printf "${YW}Use DHCP? [Y/n]:${CL} "
read -r dhcp_ans
if [[ "${dhcp_ans,,}" == "n" ]]; then
    printf "${YW}IP address/CIDR (e.g. 192.168.1.100/24):${CL} "
    read -r NET
    printf "${YW}Gateway:${CL} "
    read -r GATE
fi

printf "${YW}Root password (leave blank for random):${CL} "
read -rs PW
echo ""
[[ -z "$PW" ]] && PW=$(openssl rand -base64 16)

echo ""
echo -e "${BL}----------------------------------------${CL}"
echo -e "${BL}  Container ID:   ${CL}$CTID"
echo -e "${BL}  Hostname:     ${CL}$HN"
echo -e "${BL}  Disk:         ${CL}${DISK_SIZE}GB"
echo -e "${BL}  CPU:          ${CL}${CORES} cores"
echo -e "${BL}  RAM:          ${CL}${RAM}MB"
echo -e "${BL}  Bridge:       ${CL}$BRG"
echo -e "${BL}  Network:      ${CL}${NET}"
echo -e "${BL}----------------------------------------${CL}"
echo ""
printf "${YW}Proceed with installation? [y/N]:${CL} "
read -r confirm
[[ "${confirm,,}" != "y" ]] && { msg_info "Aborted by user."; exit 0; }

# ---------------------------------------------------------------------------
# Detect template
# ---------------------------------------------------------------------------
msg_info "Detecting Debian 12 template..."
TEMPLATE=$(pveam available --section system | grep -m1 'debian-12-standard' | awk '{print $2}')

if [[ -z "$TEMPLATE" ]]; then
    msg_warn "Debian 12 template not found locally. Updating template list..."
    pveam update
    TEMPLATE=$(pveam available --section system | grep -m1 'debian-12-standard' | awk '{print $2}')
fi

if [[ -z "$TEMPLATE" ]]; then
    msg_error "Debian 12 template not found. Proxmox template list may be unreachable."
    msg_info "Try manually: pveam update && pveam available --section system | grep debian-12"
    exit 1
fi
msg_ok "Using template: ${TEMPLATE}"

STORAGE=$(pvesm status -content rootdir | awk 'NR==2{print $1}')
if [[ -z "$STORAGE" ]]; then
    msg_error "No storage with 'rootdir' content type found."
    msg_info "Ensure you have storage (local-lvm, ZFS, etc.) configured for container rootfs."
    exit 1
fi
msg_ok "Using storage: ${STORAGE}"

# ---------------------------------------------------------------------------
# Download template if missing
# ---------------------------------------------------------------------------
if ! pveam list "$STORAGE" | grep -q "$TEMPLATE"; then
    msg_info "Downloading template (this may take a minute)..."
    pveam download "$STORAGE" "$TEMPLATE"
    msg_ok "Template downloaded"
else
    msg_ok "Template already cached"
fi

# ---------------------------------------------------------------------------
# Create container
# ---------------------------------------------------------------------------
msg_info "Creating LXC container ${CTID}..."

NET_ARGS=""
if [[ "$NET" == "dhcp" ]]; then
    NET_ARGS="--net0 name=eth0,bridge=${BRG},ip=dhcp"
else
    NET_ARGS="--net0 name=eth0,bridge=${BRG},ip=${NET}"
    [[ -n "$GATE" ]] && NET_ARGS+=",gw=${GATE}"
fi

pct create "$CTID" "${STORAGE}:vztmpl/${TEMPLATE}" \
    --hostname "$HN" \
    --cores "$CORES" \
    --memory "$RAM" \
    --swap "$SWAP" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    $NET_ARGS \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1 \
    --password "$PW"

msg_ok "Container ${CTID} created"

# ---------------------------------------------------------------------------
# Start container and wait for network
# ---------------------------------------------------------------------------
msg_info "Starting container ${CTID}..."
pct start "$CTID"
sleep 3

msg_info "Waiting for container network..."
for i in {1..30}; do
    if pct exec "$CTID" -- bash -c "ip route get 1.1.1.1 > /dev/null 2>&1"; then
        msg_ok "Container network is up"
        break
    fi
    sleep 1
done

# ---------------------------------------------------------------------------
# Install Docker inside LXC
# ---------------------------------------------------------------------------
msg_info "Installing Docker inside LXC (this may take a few minutes)..."
pct exec "$CTID" -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
'
msg_ok "Docker installed"

# ---------------------------------------------------------------------------
# Clone repo and start app
# ---------------------------------------------------------------------------
REPO_URL="${POAM_REPO:-https://github.com/michaelkpeters/poam-tracker.git}"
msg_info "Cloning POAM Tracker repository..."
msg_info "Using: ${REPO_URL}"
pct exec "$CTID" -- bash -c "
    mkdir -p /opt && cd /opt
    git clone ${REPO_URL} poam-tracker
" || {
    msg_error "Git clone failed! The repository may not exist or GitHub is unreachable."
    msg_info "You can override the repo URL by setting POAM_REPO before running this script."
    msg_info "Example: POAM_REPO=https://github.com/YOURNAME/poam-tracker.git ./poam-tracker.sh"
    exit 1
}
msg_ok "Repository cloned"

# ---------------------------------------------------------------------------
# Configure and start
# ---------------------------------------------------------------------------
msg_info "Configuring POAM Tracker..."
pct exec "$CTID" -- bash -c '
    cd /opt/poam-tracker
    cat > .env <<EOF
SECRET_KEY=$(openssl rand -hex 32)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$(openssl rand -base64 16)
EOF
    docker compose up -d
'
msg_ok "POAM Tracker started"

# ---------------------------------------------------------------------------
# Get container IP
# ---------------------------------------------------------------------------
CT_IP=$(pct exec "$CTID" -- bash -c "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'" 2>/dev/null || echo "unknown")

# ---------------------------------------------------------------------------
# Show results
# ---------------------------------------------------------------------------
echo ""
echo -e "${GN}╔══════════════════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║         ${APP} Installation Complete!           ${GN}║${CL}"
echo -e "${GN}╠══════════════════════════════════════════════════════════════╣${CL}"
echo -e "${GN}║${CL}  Container ID:  ${YW}${CTID}${CL}"
echo -e "${GN}║${CL}  IP Address:     ${YW}${CT_IP}${CL}"
echo -e "${GN}║${CL}  Web UI:         ${YW}http://${CT_IP}:5000${CL}"
echo -e "${GN}╠══════════════════════════════════════════════════════════════╣${CL}"
pct exec "$CTID" -- bash -c 'cd /opt/poam-tracker && source .env && echo "  Admin User:     $ADMIN_USERNAME" && echo "  Admin Password: $ADMIN_PASSWORD"' 2>&1 | sed 's/^/║  /'
echo -e "${GN}╚══════════════════════════════════════════════════════════════╝${CL}"
echo ""
msg_info "To update later, run: pct exec ${CTID} -- bash /opt/poam-tracker/install/update.sh"
