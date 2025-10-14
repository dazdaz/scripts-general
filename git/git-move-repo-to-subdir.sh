#!/bin/bash

# Script to move a source repository's contents into a subdirectory of a target repository

# Check if correct number of arguments is provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <source_repo_url> <target_repo_url> <subdir_name> <source_branch> <target_branch>"
    echo "Example: $0 https://github.com/user/source-repo.git https://github.com/user/target-repo.git subdir-name main main"
    echo "Example: $0 https://github.com/dazdaz/computer-use-preview-daz.git https://github.com/dazdaz/google-gemini.git computer-use-preview-daz main main
    exit 1
fi

SOURCE_REPO=$1
TARGET_REPO=$2
SUBDIR_NAME=$3
SOURCE_BRANCH=$4
TARGET_BRANCH=$5

# Create a temporary directory for cloning
TEMP_DIR=$(mktemp -d)
echo "Working in temporary directory: $TEMP_DIR"

# Clone the target repository
echo "Cloning target repository..."
git clone "$TARGET_REPO" "$TEMP_DIR/target"
cd "$TEMP_DIR/target" || exit

# Add the source repository as a remote
echo "Adding source repository as remote..."
git remote add source-repo "$SOURCE_REPO"
git fetch source-repo

# Create the subdirectory and merge contents
echo "Creating subdirectory '$SUBDIR_NAME' and merging source repo contents..."
mkdir "$SUBDIR_NAME"
git read-tree --prefix="$SUBDIR_NAME/" -u "source-repo/$SOURCE_BRANCH"

# Commit the changes
echo "Committing changes..."
git add .
git commit -m "Moved contents of $SOURCE_REPO into $SUBDIR_NAME/"

# Push to the target repository
echo "Pushing changes to target repository..."
git push origin "$TARGET_BRANCH"

# Clean up
echo "Cleaning up..."
git remote remove source-repo
cd - || exit
rm -rf "$TEMP_DIR"

echo "Done! Contents of $SOURCE_REPO have been moved to $SUBDIR_NAME/ in $TARGET_REPO."
echo "Verify at $TARGET_REPO and consider deleting the source repository manually if needed."
