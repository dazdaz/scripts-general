#!/bin/bash
# filename: new-gcp-project.sh
# ------------------------------------------------------------
# RUN THIS SCRIPT AS ORGANIZATION ADMINISTRATOR ONLY!
# ------------------------------------------------------------
# Required permissions:
# • roles/resourcemanager.organizationAdmin (or at least:
#     roles/resourcemanager.projectCreator at org level)
# • roles/billing.accountUser (or roles/billing.admin)
#
# This script will:
# • Create project with EXACT ID
# • Link billing
# • Make you Owner of the new project
# • Generate TWO files:
# ├── setproj.sh        ← source anytime to switch context
# └── owner-setup.sh    ← NEW OWNER MUST RUN THIS ONCE
# ------------------------------------------------------------
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# === ORGANIZATION ADMINISTRATOR CHECK ===
log "Checking Organization Administrator permissions..."
if ! gcloud organizations list --format="value(name)" >/dev/null 2>&1; then
  error "You do NOT have access to any GCP Organization.\n" \
        "    Required role: roles/resourcemanager.organizationAdmin\n" \
        "    Fix: Ask your Org Admin to grant you the role at organization level,\n" \
        "         or run: gcloud auth login with an account that already has it."
fi
log "Organization Administrator access confirmed."

# === Usage ===
[[ $# -lt 2 ]] && {
  cat <<EOF
Usage: $0 <exact-project-id> "<display name>" [billing-account-id]

Examples:
  $0 lunar-base "Lunar Research Base"
  $0 mars-base-prod "Mars Production 2025" 01A2B3-CCCCCC-DDDDDD

Note: Billing account ID format = XXXXXX-XXXXXX-XXXXXX
EOF
  exit 1
}

PROJECT_ID="$1"
DISPLAY_NAME="$2"
BILLING_ACCOUNT_ID="${3:-}"

# === Validate project ID ===
if ! [[ "$PROJECT_ID" =~ ^[a-z0-9]([-a-z0-9]{4,28}[a-z0-9])?$ ]]; then
  error "Invalid project ID format.\n    Must be 6–30 lowercase letters, numbers, hyphens.\n    Must start/end with alphanumeric."
fi

# === Auto-detect open billing account ===
if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
  BILLING_ACCOUNT_ID=$(gcloud beta billing accounts list \
    --filter="open=true" \
    --format="value(name)" \
    --limit=1)

  [[ -z "$BILLING_ACCOUNT_ID" ]] && error "No open billing accounts found!"
  log "Auto-selected billing account: $BILLING_ACCOUNT_ID"
else
  log "Using provided billing account: $BILLING_ACCOUNT_ID"
fi

USER="user:$(gcloud config get-value account 2>/dev/null || echo 'unknown')"
log "Creating project: $PROJECT_ID"
gcloud projects create "$PROJECT_ID" \
  --name="$DISPLAY_NAME" \
  --quiet || error "Failed to create project (ID already taken or invalid)"

log "Linking billing account..."
gcloud beta billing projects link "$PROJECT_ID" \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --quiet

log "Granting you Owner role on the new project..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$USER" \
  --role="roles/owner" \
  --quiet

log "Enabling essential APIs..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com \
  cloudbilling.googleapis.com \
  --project="$PROJECT_ID" \
  --quiet

# === 1. setproj.sh (universal context switcher) ===
cat > setproj.sh <<EOF
#!/bin/bash
# Universal GCP context switcher for: $PROJECT_ID
export PROJECT_ID="$PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="\$PROJECT_ID"
export CLOUDSDK_CORE_PROJECT="\$PROJECT_ID"
export GCLOUD_PROJECT="\$PROJECT_ID"

gcloud config set project "\$PROJECT_ID" >/dev/null 2>&1 || true
echo -e "${GREEN}Switched to project: \$PROJECT_ID${NC}"
echo "   $DISPLAY_NAME"
echo "   https://console.cloud.google.com/?project=\$PROJECT_ID"
EOF
chmod +x setproj.sh

# === 2. owner-setup.sh (MUST BE RUN BY THE FINAL OWNER!) ===
cat > owner-setup.sh <<EOF
#!/bin/bash
# =================================================
# OWNER SETUP SCRIPT – RUN THIS ONCE AS THE PROJECT OWNER
# =================================================
# Fixes Application Default Credentials (ADC) quota project
# Without this: Terraform / gsutil / client libs → 403 billing errors
# =================================================
echo -e "${CYAN}Setting ADC quota project to: $PROJECT_ID${NC}"
gcloud auth application-default set-quota-project "$PROJECT_ID" >/dev/null

echo
echo -e "${GREEN}DONE! ADC fixed permanently.${NC}"
echo "You can now safely use:"
echo " • Terraform"
echo " • gsutil / gcloud"
echo " • Python / Node / Go client libraries"
echo " • VS Code GCP extensions"
echo "without billing permission errors"
echo
echo "Tip: Run 'source setproj.sh' anytime to switch context"
EOF
chmod +x owner-setup.sh

# === FINAL SUCCESS MESSAGE ===
clear
echo
echo "=================================================="
echo "   PROJECT CREATED SUCCESSFULLY!"
echo "=================================================="
echo "   Project ID      : $PROJECT_ID"
echo "   Display Name    : $DISPLAY_NAME"
echo "   Console URL     : https://console.cloud.google.com/?project=$PROJECT_ID"
echo
echo "=================================================="
echo "   NEXT STEPS – SEND THESE TO THE NEW OWNER"
echo "=================================================="
echo
echo "   1. Send them these two files:"
echo "      ${CYAN}setproj.sh${NC}"
echo "      ${CYAN}owner-setup.sh${NC}"
echo
echo "   2. Tell them to run ONCE:"
echo "      ${YELLOW}./owner-setup.sh${NC}"
echo
echo "   3. Then anytime they work on the project:"
echo "      ${YELLOW}source setproj.sh${NC}"
echo
echo "=================================================="
echo "   IMPORTANT: Never run owner-setup.sh as the"
echo "   Organization Administrator – it must be run"
echo "   on the final owner's workstation!"
echo "=================================================="
echo
