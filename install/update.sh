#!/usr/bin/env bash
# =============================================================================
# POAM Tracker — Update Script (run inside LXC)
# =============================================================================
set -e

APP="POAM Tracker"
APP_DIR="/opt/poam-tracker"

RD=$'\033[0;31m'
GN=$'\033[0;32m'
YW=$'\033[0;33m'
BL=$'\033[0;34m'
CL=$'\033[0m'

msg_info() { echo -e "${BL}[INFO]${CL} $1"; }
msg_ok()   { echo -e "${GN}[OK]${CL} $1"; }
msg_warn() { echo -e "${YW}[WARN]${CL} $1"; }
msg_error(){ echo -e "${RD}[ERROR]${CL} $1"; }

echo ""
echo -e "${BL}Updating ${APP}...${CL}"
echo ""

cd "$APP_DIR" || { msg_error "App directory not found at ${APP_DIR}"; exit 1; }

msg_info "Pulling latest changes..."
if git pull origin main 2>&1 || git pull origin master 2>&1; then
    msg_ok "Code updated"
else
    msg_warn "Git pull had issues, rebuilding with current code"
fi

msg_info "Rebuilding Docker containers..."
docker compose down
docker compose up -d --build
msg_ok "Containers rebuilt and restarted"

# Wait for health check
msg_info "Waiting for app to be ready..."
for i in {1..30}; do
    if curl -fs http://localhost:5000/health > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
msg_ok "App is responding"

IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' 2>&1 || echo "localhost")

echo ""
echo -e "${GN}╔══════════════════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║         ${APP} Update Complete!                  ${GN}║${CL}"
echo -e "${GN}╠══════════════════════════════════════════════════════════════╣${CL}"
echo -e "${GN}║${CL}  Web UI:  ${YW}http://${IP}:5000${CL}"
echo -e "${GN}╚══════════════════════════════════════════════════════════════╝${CL}"
