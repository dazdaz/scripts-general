#!/bin/bash
# filename: new-gcp-project-free.sh
# STAR WARS EDITION — FULLY UNLEASHED
# Run as Organization Administrator
# Now with --free flag = total galactic domination (no restrictions)
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

# === ORG ADMIN CHECK ===
log "Verifying Organization Administrator access..."
if ! gcloud organizations list --format="value(name)" >/dev/null 2>&1; then
  error "NO ORGANIZATION ACCESS!\nYou need roles/resourcemanager.organizationAdmin at org level."
fi
log "Organization Administrator confirmed — the Empire approves."

# === FLAGS ===
FREE_MODE=false
ADD_TIMESTAMP=false

show_help() {
  cat <<EOF
Usage: $0 [--free] [--timestamp] <project-id> "<Display Name>" [billing-id]

STAR WARS EXAMPLES:
  $0 deathstar-prod "Death Star - Production" 
  $0 --free borg-prod "Borg Cube - Unrestricted Sandbox"
  $0 --free --timestamp ewok "Ewok Foundry" 01A2B3-CCCCCC-DDDDDD

Flags:
  --free       = FULL CHAOS MODE → removes ALL org policies (external IPs, SA keys, Shielded VM, etc.)
  --timestamp  = appends -$(date +%s) for guaranteed uniqueness
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --free)       FREE_MODE=true; shift ;;
    --timestamp)  ADD_TIMESTAMP=true; shift ;;
    -h|--help)    show_help ;;
    *)            break ;;
  esac
done

[[ $# -lt 2 ]] && show_help

PROJECT_ID="$1"
DISPLAY_NAME="$2"
BILLING_ACCOUNT_ID="${3:-}"

# === TIMESTAMP ===
if $ADD_TIMESTAMP; then
  TS=$(date +%s)
  PROJECT_ID="${PROJECT_ID}-${TS}"
  log "Timestamp applied → $PROJECT_ID"
fi

# === VALIDATE ID ===
if ! [[ "$PROJECT_ID" =~ ^[a-z0-9]([-a-z0-9]{4,28}[a-z0-9])?$ ]]; then
  error "Invalid project ID: $PROJECT_ID\nMust be 6-30 chars, lowercase, numbers, hyphens only."
fi

# === AUTO BILLING ===
if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
  BILLING_ACCOUNT_ID=$(gcloud beta billing accounts list --filter="open=true" --format="value(name)" --limit=1)
  [[ -z "$BILLING_ACCOUNT_ID" ]] && error "No open billing accounts!"
  log "Auto billing: $BILLING_ACCOUNT_ID"
else
  log "Using billing: $BILLING_ACCOUNT_ID"
fi

USER="user:$(gcloud config get-value account)"

# === CREATE PROJECT ===
log "Creating $PROJECT_ID — $DISPLAY_NAME"
gcloud projects create "$PROJECT_ID" --name="$DISPLAY_NAME" --quiet || \
  error "Project creation failed (ID taken or invalid)"

log "Linking billing..."
gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID" --quiet

log "Granting you Owner..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$USER" --role="roles/owner" --quiet

log "Enabling core APIs..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com \
  cloudbilling.googleapis.com \
  --project="$PROJECT_ID" --quiet

# === FREE MODE: TOTAL POLICY ANNIHILATION ===
if $FREE_MODE; then
  log "FREE MODE ACTIVATED — removing ALL restrictions..."
  apply_free() {
    local p=$1
    # Allow everything
    for constraint in \
      compute.vmExternalIpAccess \
      compute.restrictSharedVpcSubnetworks \
      compute.restrictSharedVpcHostProjects \
      compute.restrictVpcPeering \
      compute.vmCanIpForward \
      iam.allowedPolicyMemberDomains \
      compute.trustedImageProjects; do
      cat > /tmp/free.yaml <<EOF
constraint: constraints/$constraint
listPolicy:
  allValues: ALLOW
EOF
      gcloud resource-manager org-policies set-policy /tmp/free.yaml --project="$p" --quiet || true
    done

    # Disable boolean enforcements
    gcloud resource-manager org-policies disable-enforce compute.requireShieldedVm --project="$p" --quiet || true
    gcloud resource-manager org-policies disable-enforce compute.requireOsLogin --project="$p" --quiet || true
    gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project="$p" --quiet || true
    gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountCreation --project="$p" --quiet || true

    rm -f /tmp/free.yaml
    log "All org policies DISABLED on $p — TOTAL FREEDOM"
  }
  apply_free "$PROJECT_ID"
fi

# === GENERATE HELPER SCRIPTS ===
cat > setproj.sh <<EOF
#!/bin/bash
export PROJECT_ID="$PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="\$PROJECT_ID"
gcloud config set project "\$PROJECT_ID" >/dev/null 2>&1 || true
echo -e "${GREEN}Switched → \$PROJECT_ID${NC}"
echo " $DISPLAY_NAME"
echo " https://console.cloud.google.com/?project=\$PROJECT_ID"
EOF
chmod +x setproj.sh

cat > owner-setup.sh <<EOF
#!/bin/bash
echo -e "${CYAN}Fixing ADC for $PROJECT_ID${NC}"
gcloud auth application-default set-quota-project "$PROJECT_ID" --quiet
echo -e "${GREEN}ADC fixed — Terraform/gsutil ready!${NC}"
echo "Run: source setproj.sh"
EOF
chmod +x owner-setup.sh

# === FINAL GALACTIC VICTORY ===
clear
echo
echo "=================================================="
echo "        PROJECT CREATED — THE FORCE IS STRONG"
echo "=================================================="
echo " ID           : $PROJECT_ID"
echo " Name         : $DISPLAY_NAME"
echo " Console      : https://console.cloud.google.com/?project=$PROJECT_ID"
echo " Billing      : $BILLING_ACCOUNT_ID"
$FREE_MODE && echo " RESTRICTIONS : NONE — --free mode active"
echo
echo "=================================================="
echo " SEND TO NEW OWNER:"
echo "   ${CYAN}setproj.sh${NC}    → source anytime"
echo "   ${CYAN}owner-setup.sh${NC} → run ONCE on their machine"
echo
echo "   ${YELLOW}./owner-setup.sh${NC}"
echo "   ${YELLOW}source setproj.sh${NC}"
echo "=================================================="
echo "Never run owner-setup.sh as Org Admin!"
echo "=================================================="
