#!/usr/bin/env bash
# =============================================================================
# POAM Tracker — GitHub Repository Setup Helper
# =============================================================================
set -e

GN='\033[0;32m'
YW='\033[0;33m'
RD='\033[0;31m'
CL='\033[0m'

msg_info() { echo -e "${GN}[INFO]${CL} $1"; }
msg_warn() { echo -e "${YW}[WARN]${CL} $1"; }
msg_error(){ echo -e "${RD}[ERROR]${CL} $1"; }

echo ""
echo "  POAM Tracker — GitHub Repository Setup"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    msg_error "GitHub CLI (gh) is not installed."
    echo ""
    echo "Install it with:"
    echo "  sudo apt-get install gh    # Debian/Ubuntu"
    echo "  brew install gh              # macOS"
    echo ""
    echo "Then authenticate:"
    echo "  gh auth login"
    echo ""
    echo "Or create the repo manually at https://github.com/new"
    echo "and push with:"
    echo "  git init"
    echo "  git remote add origin https://github.com/YOUR_USER/poam-tracker.git"
    echo "  git add ."
    echo "  git commit -m 'Initial commit'"
    echo "  git push -u origin main"
    exit 1
fi

# Check auth
if ! gh auth status &> /dev/null; then
    msg_error "You are not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# Prompt for repo details
read -rp "Repository name [poam-tracker]: " REPO_NAME
REPO_NAME=${REPO_NAME:-poam-tracker}

read -rp "Visibility (public/private) [public]: " VIS
VIS=${VIS:-public}

read -rp "Description [POAM Tracker - Plan of Action and Milestones web app]: " DESC
DESC=${DESC:-"POAM Tracker - Plan of Action and Milestones web app"}

msg_info "Creating GitHub repository..."
gh repo create "$REPO_NAME" --${VIS} --description "$DESC" --source=. --remote=origin --push

msg_info "Repository created and code pushed!"
echo ""
echo -e "${GN}Next steps:${CL}"
echo "  1. Update install/poam-tracker.sh and replace REPO-OWNER with your GitHub username"
echo "  2. Update README.md and replace REPO-OWNER with your GitHub username"
echo "  3. Commit and push the updated files"
echo "  4. Share the one-liner install command from the README"
echo ""
