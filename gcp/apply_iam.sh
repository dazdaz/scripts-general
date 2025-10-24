#!/bin/bash

# This script takes three arguments: PROJECT_NAME, MEMBER, and ROLE
# It looks up the PROJECT_ID from the PROJECT_NAME before applying the policy.
#
# Example usage (as requested):
# ./apply_iam.sh "My Example Project" "user:example-username@example.com" "roles/owner"

# --- 1. Check Arguments ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <PROJECT_NAME> <MEMBER> <ROLE>"
    echo "Note: PROJECT_NAME must be quoted if it contains spaces."
    echo ""
    echo "Example: As your admin user, you may want to run this command :-"
    echo "$0 \"My Example Project Name\" \"user:example-username@example.com\" \"roles/owner\""
    exit 1
fi

# Assign arguments to variables
PROJECT_NAME="$1"
MEMBER="$2"
ROLE="$3"

echo "Looking up PROJECT_ID for project name: '$PROJECT_NAME'..."

# --- 2. Look up Project ID from Project Name ---
# We use gcloud projects describe with a filter to find the project by its
# display name and then format the output to return *only* the projectId.
# The 'limit=1' ensures we only get one result if names are somehow duplicated.
PROJECT_ID=$(gcloud projects list \
  --filter="name='$PROJECT_NAME'" \
  --format="value(projectId)" \
  --limit=1)

# Check if the lookup failed (PROJECT_ID variable will be empty)
if [ -z "$PROJECT_ID" ]; then
    echo "Error: Failed to find PROJECT_ID for '$PROJECT_NAME'."
    echo "Please check the project name and ensure your gcloud user has 'resourcemanager.projects.get' permission."
    exit 1
fi

echo "Found PROJECT_ID: $PROJECT_ID"
echo "---"

# --- 3. Apply the IAM Policy ---
echo "Attempting to add '$ROLE' for '$MEMBER' to project '$PROJECT_ID'..."

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="$ROLE"

# Check the exit status of the gcloud command
if [ $? -eq 0 ]; then
  echo "Successfully updated IAM policy."
else
  echo "Failed to update IAM policy. Please check your permissions (you may need 'roles/resourcemanager.projectIamAdmin')."
  exit 1
fi
