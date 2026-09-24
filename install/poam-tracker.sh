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
RD='\033[0;31m'
GN='\033[0;32m'
YW='\033[0;33m'
BL='\033[0;34m'
CL='\033[0m'

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
read -rp "${YW}Container ID (auto-detect if blank):${CL} " CTID
if [[ -z "$CTID" ]]; then
    # Find next available CTID
    CTID=$(pvesh get /cluster/nextid 2>/dev/null || echo "100")
fi

read -rp "${YW}Container hostname [${HN}]:${CL} " input_hn
[[ -n "$input_hn" ]] && HN="$input_hn"

read -rp "${YW}Disk size (GB) [${DISK_SIZE}]:${CL} " input_disk
[[ -n "$input_disk" ]] && DISK_SIZE="$input_disk"

read -rp "${YW}CPU cores [${CORES}]:${CL} " input_cores
[[ -n "$input_cores" ]] && CORES="$input_cores"

read -rp "${YW}RAM (MB) [${RAM}]:${CL} " input_ram
[[ -n "$input_ram" ]] && RAM="$input_ram"

read -rp "${YW}Bridge [${BRG}]:${CL} " input_brg
[[ -n "$input_brg" ]] && BRG="$input_brg"

read -rp "${YW}Use DHCP? [Y/n]:${CL} " dhcp_ans
if [[ "${dhcp_ans,,}" == "n" ]]; then
    read -rp "${YW}IP address/CIDR (e.g. 192.168.1.100/24):${CL} " NET
    read -rp "${YW}Gateway:${CL} " GATE
fi

read -rsp "${YW}Root password (leave blank for random):${CL} " PW
[[ -z "$PW" ]] && PW=$(openssl rand -base64 16)
echo ""

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
read -rp "${YW}Proceed with installation? [y/N]:${CL} " confirm
[[ "${confirm,,}" != "y" ]] && { msg_info "Aborted by user."; exit 0; }

# ---------------------------------------------------------------------------
# Detect template
# ---------------------------------------------------------------------------
msg_info "Detecting Debian 12 template..."
TEMPLATE=$(pveam available --section system | grep -m1 'debian-12-standard' | awk '{print $2}')
if [[ -z "$TEMPLATE" ]]; then
    msg_error "Debian 12 template not found. Run: pveam update"
    exit 1
fi
STORAGE=$(pvesm status -content rootdir | awk 'NR==2{print $1}')
if [[ -z "$STORAGE" ]]; then
    msg_error "No storage with 'rootdir' content type found."
    exit 1
fi
msg_ok "Using template: ${TEMPLATE} on ${STORAGE}"

# ---------------------------------------------------------------------------
# Download template if missing
# ---------------------------------------------------------------------------
if ! pveam list "$STORAGE" | grep -q "$TEMPLATE"; then
    msg_info "Downloading template..."
    pveam download "$STORAGE" "$TEMPLATE" > /dev/null 2>&1
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
    --password "$PW" > /dev/null 2>&1

msg_ok "Container created"

# ---------------------------------------------------------------------------
# Start container and wait for network
# ---------------------------------------------------------------------------
msg_info "Starting container..."
pct start "$CTID"
sleep 3

# Wait for container network
for i in {1..30}; do
    if pct exec "$CTID" -- bash -c "ip route get 1.1.1.1 > /dev/null 2>&1"; then
        break
    fi
    sleep 1
done
msg_ok "Container started"

# ---------------------------------------------------------------------------
# Install Docker inside LXC
# ---------------------------------------------------------------------------
msg_info "Installing Docker inside LXC..."
pct exec "$CTID" -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update > /dev/null 2>&1
    apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg > /dev/null 2>&1
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    apt-get update > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
' > /dev/null 2>&1
msg_ok "Docker installed"

# ---------------------------------------------------------------------------
# Clone repo and start app
# ---------------------------------------------------------------------------
REPO_URL="${POAM_REPO:-https://github.com/michaelkpeters/poam-tracker.git}"
msg_info "Cloning POAM Tracker repository..."
pct exec "$CTID" -- bash -c "
    mkdir -p /opt && cd /opt
    git clone ${REPO_URL} poam-tracker 2>&1 || { echo 'Git clone failed'; exit 1; }
" > /dev/null 2>&1
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
    docker compose up -d > /dev/null 2>&1
' > /dev/null 2>&1
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
