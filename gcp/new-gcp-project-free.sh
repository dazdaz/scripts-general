#!/bin/bash
set -euo pipefail

# === CONFIGURATION (only change these) ===
BILLING_ACCOUNT_ID="01EF07-AAAAAA-BBBBBB"      # Your billing account
USER="user:user@myhost.org"                    # Your identity (owner)
FREE_MODE=false
ADD_TIMESTAMP=false

# === Help & Argument Parsing ===
show_help() {
  cat <<EOF
Usage: $0 [--free] [--timestamp] <project-id-1> [project-id-2] ...

Options:
  --free        Apply fully relaxed org policies (allow external IPs, no Shielded VM, etc.)
  --timestamp   Append current timestamp to each project ID for uniqueness
  -h, --help    Show this help

Examples:
  $0 --free my-sandbox-01
  $0 --free --timestamp gpu-playground-nov25
  $0 --timestamp secure-prod-app-us secure-prod-app-eu

Required: At least one project ID must be provided.
EOF
  exit 1
}

if [ $# -eq 0 ]; then
  echo "Error: No project ID provided."
  show_help
fi

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --free)
      FREE_MODE=true
      shift
      ;;
    --timestamp)
      ADD_TIMESTAMP=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      # All remaining args are project IDs
      break
      ;;
  esac
done

# Now $1, $2, ... are project IDs
if [ $# -eq 0 ]; then
  echo "Error: No project IDs specified after flags."
  show_help
fi

declare -a PROJECTS=("$@")

# Append timestamp if requested
if $ADD_TIMESTAMP; then
  TIMESTAMP=$(date +%s)
  for i in "${!PROJECTS[@]}"; do
    PROJECTS[i]="${PROJECTS[i]}-$TIMESTAMP"
  done
fi

echo "Creating project(s): ${PROJECTS[*]}"
$FREE_MODE && echo "FREE MODE: All restrictions disabled"
$ADD_TIMESTAMP && echo "Timestamp suffix applied"
echo

# === Function: Apply fully relaxed policies ===
apply_free_policies() {
  local proj=$1
  echo "Applying unrestricted org policies to $proj ..."

  cat <<EOF > /tmp/free_policy_$$.yaml
constraint: constraints/compute.trustedImageProjects
listPolicy:
  allValues: ALLOW
EOF
  gcloud resource-manager org-policies set-policy /tmp/free_policy_$$.yaml --project="$proj" --quiet
  rm -f /tmp/free_policy_$$.yaml

  local policies=(
    compute.vmExternalIpAccess
    compute.restrictSharedVpcSubnetworks
    compute.restrictSharedVpcHostProjects
    compute.restrictVpcPeering
    compute.vmCanIpForward
    iam.allowedPolicyMemberDomains
  )
  for p in "${policies[@]}"; do
    cat <<EOF > /tmp/free_policy_$$.yaml
constraint: constraints/$p
listPolicy:
  allValues: ALLOW
EOF
    gcloud resource-manager org-policies set-policy /tmp/free_policy_$$.yaml --project="$proj" --quiet
    rm -f /tmp/free_policy_$$.yaml
  done

  # Disable boolean enforcement
  gcloud resource-manager org-policies disable-enforce compute.requireShieldedVm --project="$proj" --quiet || true
  gcloud resource-manager org-policies disable-enforce compute.requireOsLogin --project="$proj" --quiet || true
  gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project="$proj" --quiet || true
  gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountCreation --project="$proj" --quiet || true

  echo "All restrictions removed from $proj"
}

# === Main Loop ===
for PROJECT_ID in "${PROJECTS[@]}"; do
  echo "Creating project: $PROJECT_ID"

  gcloud projects create "$PROJECT_ID" \
    --name="Dev Project - $PROJECT_ID" \
    --labels=cost-center=dev \
    --quiet

  echo "Linking billing..."
  gcloud beta billing projects link "$PROJECT_ID" \
    --billing-account="$BILLING_ACCOUNT_ID" \
    --quiet

  echo "Granting OWNER to $USER..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="$USER" \
    --role="roles/owner" \
    --quiet

  echo "Granting Service Usage Consumer..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="$USER" \
    --role="roles/serviceusage.serviceUsageConsumer" \
    --quiet

  echo "Enabling core APIs..."
  gcloud services enable \
    cloudresourcemanager.googleapis.com \
    serviceusage.googleapis.com \
    iam.googleapis.com \
    --project="$PROJECT_ID" --quiet

  gcloud config set project "$PROJECT_ID" --quiet

  if $FREE_MODE; then
    apply_free_policies "$PROJECT_ID"
  fi

  echo "Setting ADC quota project..."
  gcloud auth application-default set-quota-project "$PROJECT_ID" --quiet || true

  echo "READY: $PROJECT_ID"
  if $FREE_MODE; then
    echo "   • Fully unrestricted (--free)"
  fi
  echo
done

echo "ALL PROJECTS CREATED SUCCESSFULLY!"
echo "Current default project:"
gcloud config get-value project
echo
echo "Tip: Use --free for personal sandboxes, --timestamp for unique names"
