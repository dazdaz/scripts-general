#!/bin/bash

# Script to remove all git commit history for a specific GitHub repository
# Usage: ./remove_git_history.sh <github-repo-url> [options]

set -e # Exit on error

# Parse arguments
AUTO_CONFIRM=false
AUTO_PUSH=false
TARGET_REPO=""
CLONE_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        --push|-p)
            AUTO_PUSH=true
            shift
            ;;
        --dir|-d)
            CLONE_DIR="$2"
            shift 2
            ;;
        *)
            if [ -z "$TARGET_REPO" ]; then
                TARGET_REPO="$1"
            fi
            shift
            ;;
    esac
done

# Check if repository URL is provided
if [ -z "$TARGET_REPO" ]; then
    echo "❌ Error: GitHub repository URL is required."
    echo ""
    echo "Usage: $0 <github-repo-url> [options]"
    echo ""
    echo "Options:"
    echo "  --yes, -y        Skip confirmation prompts (use with caution!)"
    echo "  --push, -p       Automatically push to remote after resetting history"
    echo "  --dir, -d <path> Directory to clone into (if not in a git repo)"
    echo ""
    echo "Example:"
    echo "  $0 https://github.com/username/repository.git"
    echo "  $0 https://github.com/username/repository.git --yes --push"
    echo "  $0 https://github.com/username/repository.git --dir ./my-repo --yes"
    exit 1
fi

echo "🎯 Target GitHub Repository: $TARGET_REPO"
echo ""
echo "⚠️  WARNING: This will remove ALL commit history!"
echo "This action cannot be undone locally, but you can recover from the remote if needed."
echo ""

if [ "$AUTO_CONFIRM" = false ]; then
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
else
    echo "⚙️ Auto-confirm enabled, proceeding without prompts..."
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "🗺️ Not currently in a git repository."
    
    # Extract repository name from URL
    REPO_NAME=$(basename "$TARGET_REPO" .git)
    
    # Determine clone directory
    if [ -z "$CLONE_DIR" ]; then
        CLONE_DIR="./$REPO_NAME"
    fi
    
    echo "📁 Will clone repository to: $CLONE_DIR"
    echo ""
    
    if [ "$AUTO_CONFIRM" = false ]; then
        read -p "Clone the repository first? (yes/no): " clone_confirm
        if [ "$clone_confirm" != "yes" ]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
    
    echo "⏳ Cloning repository..."
    git clone "$TARGET_REPO" "$CLONE_DIR"
    
    echo "✅ Repository cloned."
    echo "⤵️ Changing to repository directory..."
    cd "$CLONE_DIR"
fi

echo ""
echo "🗺️ Verifying current repository..."

# Get current remote URL if it exists
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

if [ -n "$CURRENT_REMOTE" ]; then
    echo "🌐 Current remote: $CURRENT_REMOTE"
    echo "🌿 Current branch: $CURRENT_BRANCH"
    
    # Normalize URLs for comparison (remove trailing .git if present)
    NORMALIZED_CURRENT=$(echo "$CURRENT_REMOTE" | sed 's/\.git$//')
    NORMALIZED_TARGET=$(echo "$TARGET_REPO" | sed 's/\.git$//')
    
    # Warn if current remote doesn't match target
    if [ "$NORMALIZED_CURRENT" != "$NORMALIZED_TARGET" ]; then
        echo ""
        echo "⚠️  WARNING: Current remote ($CURRENT_REMOTE) doesn't match target ($TARGET_REPO)"
        if [ "$AUTO_CONFIRM" = false ]; then
            read -p "Do you want to continue and update to the target repository? (yes/no): " continue_confirm
            if [ "$continue_confirm" != "yes" ]; then
                echo "Operation cancelled."
                exit 0
            fi
        else
            echo "⚙️ Auto-confirm enabled, updating to target repository..."
        fi
    fi
fi

echo ""
echo "⏳ Removing git history..."

# Remove the .git directory
rm -rf .git

echo "✅ Git history removed."
echo ""
echo "⏳ Initializing new repository..."

# Initialize a new git repository
git init

# Set the default branch name
git branch -M "$CURRENT_BRANCH"

echo "✅ New repository initialized with branch: $CURRENT_BRANCH"
echo ""
echo "⏳ Adding all files to the new repository..."

# Add all files
git add .

echo "✅ Files added."
echo ""
echo "⏳ Creating initial commit..."

# Create the initial commit
git commit -m "Initial commit - history reset"

echo "✅ Initial commit created."
echo ""
echo "⏳ Adding remote repository..."

# Add the target remote
git remote add origin "$TARGET_REPO"

echo "✅ Remote repository added: $TARGET_REPO"
echo ""

# Push to remote if requested
if [ "$AUTO_PUSH" = true ]; then
    echo "🚀 Pushing to remote repository..."
    echo ""
    echo "⚠️  WARNING: This will PERMANENTLY overwrite the remote repository's history!"
    
    if [ "$AUTO_CONFIRM" = false ]; then
        read -p "Are you absolutely sure you want to force push? (yes/no): " push_confirm
        if [ "$push_confirm" != "yes" ]; then
            echo "Push cancelled. You can manually push later with:"
            echo "    cd $(pwd)"
            echo "    git push -f origin $CURRENT_BRANCH"
            exit 0
        fi
    else
        echo "⚙️ Auto-confirm enabled, force pushing..."
    fi
    
    git push -f origin "$CURRENT_BRANCH"
    
    echo ""
    echo "✅ Successfully pushed to remote!"
    echo ""
    echo "🎉 Done! The remote repository now has a fresh history with only one commit."
    echo ""
    echo "⚠️  IMPORTANT:"
    echo "    • All team members must re-clone the repository"
    echo "    • All previous commits, branches, and tags have been lost on the remote"
else
    echo "🎉 Done! Your repository now has a fresh history with only one commit."
    echo ""
    echo "📬 Next step to push to GitHub:"
    echo "    cd $(pwd)"
    echo "    git push -f origin $CURRENT_BRANCH"
    echo ""
    echo "⚠️  IMPORTANT: Force pushing will overwrite the remote repository's history!"
    echo "    • Make sure all team members are aware before doing this."
    echo "    • Anyone who has cloned the repository will need to re-clone it."
    echo "    • All previous commits, branches, and tags will be lost on the remote."
fi
