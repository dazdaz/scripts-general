#!/bin/bash

set -e

# === CONFIGURE THESE ===
PROJECT_ID="spacelab-123"  # or use spacelab-$(date +%s) for uniqueness
DISPLAY_NAME="My Dev Project"
BILLING_ACCOUNT_ID="01EF07-AAAAAA-BBBBBB"
USER="user:user@myhost.org"
# =======================

echo "Creating new project: $PROJECT_ID"

gcloud projects create "$PROJECT_ID" --name="$DISPLAY_NAME" --set-as-default
echo "Created: $PROJECT_ID"

echo "Linking billing account..."
gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID"

echo "Granting OWNER role to $USER..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$USER" --role="roles/owner"

echo "Granting Service Usage Consumer..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$USER" --role="roles/serviceusage.serviceUsageConsumer"

echo "Enabling APIs..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  iam.googleapis.com \
  --project="$PROJECT_ID"

gcloud config set project "$PROJECT_ID"
echo "Default project set to: $PROJECT_ID"

export PROJECT_ID=spacelab-x
echo "Logging in for Application Default Credentials..."
gcloud auth application-default login --project="$PROJECT_ID" --no-launch-browser
# ==================

echo "Setting ADC quota project..."
gcloud auth application-default set-quota-project "$PROJECT_ID"

echo "ALL DONE! Project ready: $PROJECT_ID"
echo "   - You are OWNER"
echo "   - Billing linked"
echo "   - ADC configured"
echo ""
gcloud config get-value project
