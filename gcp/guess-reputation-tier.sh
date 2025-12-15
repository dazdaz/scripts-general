#!/bin/bash

# --- Script to Infer GCP Project Reputation ---
# This script attempts to guess a GCP project's reputation tier.
# By checking several observable factors, primarily default resource quotas and billing status.
# Higher reputation generally grants higher default quotas for sensitive resources.
#
# How it works:
# 1.  Checks for a selected GCP project.
# 2.  Verifies Billing Status: Ensures billing is enabled and the account is open. Bad billing health strongly implies low reputation.
# 3.  Gathers Quota Information: For several reputation-sensitive resources across different regions:
#     - Cloud Run: NVIDIA L4 GPUs
#     - Compute Engine: CPUs
#     - Compute Engine: NVIDIA L4 GPUs
#     - Compute Engine: Static IP Addresses
# 4.  Analyzes Quota Levels: Compares the default limits found against typical thresholds for low, medium, or high reputation accounts.
#     - Very low or zero quotas, especially outside us-central1, suggest lower reputation.
#     - More generous quotas across multiple regions suggest higher reputation.
# 5.  Infers Reputation: Combines signals from billing status and the observed quota levels
#     to provide an educated guess of the project's likely reputation category (e.g., VERY LOW, LOW, MEDIUM, HIGH).
#
# Disclaimer: This is an *inference* only. Actual reputation is a complex internal metric.

# Regions to check for regional quotas
REGIONS=("us-central1" "europe-west4" "asia-southeast1")
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

# 1. Check if a GCP project is configured in gcloud
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: No GCP project is set. Use 'gcloud config set project YOUR_PROJECT_ID'"
  exit 1
fi

echo "--- Comprehensive Reputation Indicator Check for project: $PROJECT_ID ---"
echo

# --- 2. Billing Status ---
# Fetch project billing information.
echo "--- Billing Status ---"
BILLING_INFO=$(gcloud beta billing projects describe "$PROJECT_ID" --format=json)
if [[ $? -ne 0 ]]; then
  echo "Error fetching billing info. Quitting."
  exit 1
fi

BILLING_ENABLED=$(echo "$BILLING_INFO" | jq -r '.billingEnabled')
BILLING_ACCOUNT=$(echo "$BILLING_INFO" | jq -r '.billingAccountName | split("/")[1]')

if [[ "$BILLING_ENABLED" == "true" ]]; then
  echo "Billing Account: $BILLING_ACCOUNT"
  echo "Billing Status: ENABLED"
  # Check if the billing account itself is open and in a good state.
  BILLING_ACCOUNT_INFO=$(gcloud beta billing accounts describe "$BILLING_ACCOUNT" --format=json)
  BILLING_OPEN=$(echo "$BILLING_ACCOUNT_INFO" | jq -r '.open')
  if [[ "$BILLING_OPEN" == "true" ]]; then
    echo "Billing Account State: OPEN"
  else
    echo "Billing Account State: CLOSED or SUSPENDED"
    echo "=> VERY LOW effective reputation due to billing issues."
    exit 1
  fi
else
  echo "Billing Status: DISABLED"
  echo "=> VERY LOW effective reputation. Billing is not enabled."
  exit 1
fi
echo

# --- 3. Quota Checks ---
echo "--- Quota Checks ---"

# Helper function to parse the quota limit for a specific region from JSON output.
# Defaults to "0" if the quota or region is not found.
get_limit() {
  local quota_data=$1
  local region=$2
  local limit=$(echo "$quota_data" | jq -r --arg REGION "$region" '
    [ .[] | .dimensionsInfo[]? | select(.dimensions.region == $REGION) | .details.value ] | .[0] // "0"
  ')
  if [[ -z "$limit" || "$limit" == "null" ]]; then
    echo "0"
  else
    echo "$limit"
  fi
}

# Helper function to fetch quota data for a specific service and metric.
fetch_quota_data() {
  local service=$1
  local metric=$2
  gcloud beta quotas info list \
    --service="$service" \
    --project="$PROJECT_ID" \
    --filter="metric = \"${service}/${metric}\"" \
    --format=json
}

# Check Cloud Run L4 GPUs Quota
CR_L4_METRIC="nvidia_l4_gpu_allocation_no_zonal_redundancy"
CR_L4_DATA=$(fetch_quota_data "run.googleapis.com" "$CR_L4_METRIC")
echo "Cloud Run NVIDIA L4 GPUs ($CR_L4_METRIC):"
cr_l4_limits=()
for region in "${REGIONS[@]}"; do
  val=$(get_limit "$CR_L4_DATA" "$region")
  echo "  $region: $val"
  cr_l4_limits+=("$val")
done

# Check GCE CPUs Quota
GCE_CPU_METRIC="cpus"
GCE_CPU_DATA=$(fetch_quota_data "compute.googleapis.com" "$GCE_CPU_METRIC")
echo "GCE CPUs ($GCE_CPU_METRIC):"
gce_cpu_limits=()
for region in "${REGIONS[@]}"; do
  val=$(get_limit "$GCE_CPU_DATA" "$region")
  echo "  $region: $val"
  gce_cpu_limits+=("$val")
done

# Check GCE L4 GPUs Quota
GCE_L4_METRIC="nvidia_l4_gpus"
GCE_L4_DATA=$(fetch_quota_data "compute.googleapis.com" "$GCE_L4_METRIC")
echo "GCE NVIDIA L4 GPUs ($GCE_L4_METRIC):"
gce_l4_limits=()
for region in "${REGIONS[@]}"; do
  val=$(get_limit "$GCE_L4_DATA" "$region")
  echo "  $region: $val"
  gce_l4_limits+=("$val")
done

# Check GCE Static IP Addresses Quota
GCE_IP_METRIC="static_addresses"
GCE_IP_DATA=$(fetch_quota_data "compute.googleapis.com" "$GCE_IP_METRIC")
echo "GCE Static IP Addresses ($GCE_IP_METRIC):"
gce_ip_limits=()
for region in "${REGIONS[@]}"; do
  val=$(get_limit "$GCE_IP_DATA" "$region")
  echo "  $region: $val"
  gce_ip_limits+=("$val")
done
echo

# --- 4. Reputation Inference Logic ---
# Tally signals suggesting low, medium, or high reputation based on quota limits.
echo "--- Reputation Guess ---"
low_quota_signals=0
medium_quota_signals=0
high_quota_signals=0

# Analyze Cloud Run GPU limits (us-central1 vs other regions)
[[ ${cr_l4_limits[0]} -eq 0 && ${cr_l4_limits[1]} -eq 0 ]] && ((low_quota_signals+=2)) # Low in us-central1 and others
[[ ${cr_l4_limits[0]} -gt 0 && ${cr_l4_limits[1]} -eq 0 ]] && ((medium_quota_signals+=1)) # Some in us-central1, low in others
[[ ${cr_l4_limits[0]} -gt 0 && ${cr_l4_limits[1]} -gt 0 ]] && ((high_quota_signals+=1)) # Some in us-central1 and others

# Analyze GCE GPU limits
[[ ${gce_l4_limits[0]} -eq 0 && ${gce_l4_limits[1]} -eq 0 ]] && ((low_quota_signals+=2))
[[ ${gce_l4_limits[0]} -gt 0 && ${gce_l4_limits[1]} -eq 0 ]] && ((medium_quota_signals+=1))
[[ ${gce_l4_limits[0]} -gt 0 && ${gce_l4_limits[1]} -gt 0 ]] && ((high_quota_signals+=1))

# Analyze GCE CPU limits (typical default for LOW is ~24, HIGH is 72+)
[[ ${gce_cpu_limits[0]} -lt 24 && ${gce_cpu_limits[1]} -lt 24 ]] && ((low_quota_signals+=1))
[[ ${gce_cpu_limits[0]} -ge 72 && ${gce_cpu_limits[1]} -ge 72 ]] && ((high_quota_signals+=1))

# Analyze GCE Static IP limits (typical default for LOW is ~8)
[[ ${gce_ip_limits[0]} -lt 8 && ${gce_ip_limits[1]} -lt 8 ]] && ((low_quota_signals+=1))
[[ ${gce_ip_limits[0]} -ge 8 && ${gce_ip_limits[1]} -ge 8 ]] && ((high_quota_signals+=1))

echo "Signal Counts: Low=$low_quota_signals, Medium=$medium_quota_signals, High=$high_quota_signals"

# --- 5. Final Guess ---
# Combine the signals to make a final reputation guess.
if [[ $low_quota_signals -ge 5 ]]; then
  echo "=> Likely VERY LOW to LOW Reputation"
elif [[ $high_quota_signals -ge 2 ]]; then
  echo "=> Likely HIGH to VERY HIGH Reputation"
elif [[ $medium_quota_signals -ge 1 || $high_quota_signals -ge 1 ]]; then
  echo "=> Likely MEDIUM Reputation"
else
  echo "=> Likely LOW to MEDIUM Reputation"
fi

# --- 6. Disclaimer ---
echo "Disclaimer: This is an educated guess based on default quotas and billing status.
      Actual reputation is an internal, multi-faceted metric."
