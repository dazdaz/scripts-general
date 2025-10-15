#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help message
show_help() {
    cat << EOF
GitHub PAT Setup for macOS
===========================

This script securely configures your GitHub Personal Access Token (PAT) for Git operations.

What it does:
1. **Checks for existing credentials** in macOS Keychain
2. **Configures Git globally** to use macOS Keychain (osxkeychain credential helper)
3. **Stores your PAT** in the macOS Keychain (secure, encrypted storage)
4. **Works for all GitHub repositories** automatically
5. **No plaintext storage** - credentials are encrypted by macOS

Usage:
    $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    -u, --username  Specify GitHub username (optional, will prompt if not provided)
    -t, --token     Specify GitHub PAT (optional, will prompt if not provided)
    -f, --force     Force update even if credentials already exist
    -r, --remove    Remove GitHub credentials from keychain and exit

Example:
    $0
    $0 --username your_github_username
    $0 -u your_github_username -t ghp_yourtoken
    $0 --force  # Update existing credentials
    $0 --remove # Remove credentials from keychain

Test your token:
    curl -s -H "Authorization: Bearer ghp_yourtoken" https://api.github.com/user | jq -r '.login // .message'
    
    Valid token output: your_username
    Invalid token output: Bad credentials

Requirements:
    - macOS operating system
    - Git installed
    - Valid GitHub Personal Access Token

Note:
    If you don't have a PAT, create one at:
    https://github.com/settings/tokens

EOF
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script only works on macOS${NC}"
        exit 1
    fi
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: Git is not installed${NC}"
        exit 1
    fi
}

# Check if git-credential-osxkeychain exists
check_git_credential_osxkeychain() {
    echo -e "${YELLOW}Checking for git-credential-osxkeychain...${NC}"
    
    # First check if it's available in PATH
    if command -v git-credential-osxkeychain &> /dev/null; then
        echo -e "${GREEN}‚úì git-credential-osxkeychain found in PATH${NC}"
        return 0
    fi
    
    # Check common installation locations
    local common_paths=(
        "/usr/local/git/current/bin/git-credential-osxkeychain"
        "/usr/local/bin/git-credential-osxkeychain"
        "/opt/homebrew/bin/git-credential-osxkeychain"
        "/Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git-credential-osxkeychain"
    )
    
    for path in "${common_paths[@]}"; do
        if [ -f "$path" ]; then
            echo -e "${GREEN}‚úì git-credential-osxkeychain found at: $path${NC}"
            return 0
        fi
    done
    
    # Check if Git was installed via Homebrew
    local git_path=$(which git 2>/dev/null)
    if [[ "$git_path" == *"homebrew"* ]] || [[ "$git_path" == *"/opt/"* ]]; then
        local git_dir=$(dirname "$git_path")
        if [ -f "$git_dir/git-credential-osxkeychain" ]; then
            echo -e "${GREEN}‚úì git-credential-osxkeychain found at: $git_dir/git-credential-osxkeychain${NC}"
            return 0
        fi
    fi
    
    # Not found in common locations
    echo -e "${RED}‚úó git-credential-osxkeychain not found${NC}"
    echo -e "${YELLOW}‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê${NC}"
    echo -e "${YELLOW}The osxkeychain credential helper is not available.${NC}"
    echo -e "${YELLOW}This typically happens when Git was not installed properly.${NC}\n"
    
    echo -e "${BLUE}How to fix this:${NC}\n"
    
    echo -e "${BLUE}Option 1: Install Git via Homebrew (Recommended)${NC}"
    echo -e "  1. Install Homebrew if not already installed:"
    echo -e "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo -e "  2. Install Git:"
    echo -e "     brew install git"
    echo -e "  3. Run this script again\n"
    
    echo -e "${BLUE}Option 2: Install Xcode Command Line Tools${NC}"
    echo -e "  1. Run: xcode-select --install"
    echo -e "  2. Follow the installation prompts"
    echo -e "  3. Run this script again\n"
    
    echo -e "${BLUE}Option 3: Download Git from official website${NC}"
    echo -e "  1. Visit: https://git-scm.com/download/mac"
    echo -e "  2. Download and install the official Git installer"
    echo -e "  3. Run this script again\n"
    
    echo -e "${YELLOW}After installing Git, verify by running:${NC}"
    echo -e "  git credential-osxkeychain"
    echo -e "${YELLOW}You should see usage information (not 'command not found')${NC}"
    echo -e "${YELLOW}‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê‚ïê${NC}"
    
    return 1
}

# Check if credentials already exist in keychain
check_existing_credentials() {
    echo -e "${YELLOW}Checking for existing GitHub credentials in Keychain...${NC}"
    
    # Try to retrieve credentials from keychain
    local retrieved=$(echo "protocol=https
host=github.com
" | git credential-osxkeychain get 2>/dev/null || echo "")
    
    if [ -n "$retrieved" ]; then
        # Extract username and password from the retrieved credentials
        local stored_username=$(echo "$retrieved" | grep "^username=" | cut -d'=' -f2)
        local stored_password=$(echo "$retrieved" | grep "^password=" | cut -d'=' -f2)
        
        if [ -n "$stored_username" ] && [ -n "$stored_password" ]; then
            echo -e "${BLUE}‚úì Found existing credentials for user: $stored_username${NC}"
            return 0
        fi
    fi
    
    echo -e "${BLUE}‚úì No existing credentials found${NC}"
    return 1
}

# Remove existing credentials from keychain
remove_existing_credentials() {
    echo -e "${YELLOW}Removing existing credentials from Keychain...${NC}"
    
    echo "protocol=https
host=github.com
" | git credential-osxkeychain erase 2>/dev/null || true
    
    echo -e "${GREEN}‚úì Existing credentials removed${NC}"
}

# Remove credentials and exit (for --remove flag)
remove_credentials_and_exit() {
    echo -e "${GREEN}=== Remove GitHub Credentials ===${NC}\n"
    
    if ! check_existing_credentials; then
        echo -e "\n${BLUE}No GitHub credentials found in Keychain.${NC}"
        echo -e "${BLUE}Nothing to remove.${NC}"
        exit 0
    fi
    
    echo -e "\n${YELLOW}This will remove your GitHub credentials from macOS Keychain.${NC}"
    echo -e "${YELLOW}You will need to enter credentials again for future Git operations.${NC}"
    read -p "Are you sure you want to remove your GitHub credentials? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Operation cancelled. Credentials not removed.${NC}"
        exit 0
    fi
    
    remove_existing_credentials
    
    # Verify removal
    if ! check_existing_credentials 2>/dev/null; then
        echo -e "\n${GREEN}=== Credentials Successfully Removed ===${NC}"
        echo -e "${GREEN}GitHub credentials have been removed from macOS Keychain.${NC}"
        echo -e "\n${YELLOW}Note: Your Git credential helper configuration remains unchanged.${NC}"
        echo -e "${YELLOW}Run this script again (without --remove) to store new credentials.${NC}"
    else
        echo -e "\n${YELLOW}Warning: Credentials may still exist in Keychain.${NC}"
        echo -e "${YELLOW}You can manually remove them in Keychain Access.app${NC}"
    fi
    
    exit 0
}

# Configure git to use osxkeychain
configure_git_credential_helper() {
    echo -e "${YELLOW}Configuring Git to use macOS Keychain...${NC}"
    
    # Check if credential.helper already has multiple values
    local helper_count=$(git config --global --get-all credential.helper 2>/dev/null | wc -l)
    
    if [ "$helper_count" -gt 1 ]; then
        echo -e "${BLUE}‚úì Multiple credential helpers found. Cleaning up...${NC}"
        # Remove all existing credential helpers
        git config --global --unset-all credential.helper 2>/dev/null || true
    fi
    
    # Set osxkeychain as the only credential helper
    git config --global credential.helper osxkeychain
    
    echo -e "${GREEN}‚úì Git credential helper configured${NC}"
}

# Test GitHub PAT
test_github_pat() {
    local username=$1
    local token=$2
    
    echo -e "${YELLOW}Testing GitHub PAT...${NC}"
    
    # Debug: Show token length (without revealing the token)
    echo -e "${BLUE}Debug: Token length = ${#token} characters${NC}"
    
    # Test the PAT by making an API call using Bearer authentication
    local result=$(curl -s -H "Authorization: Bearer $token" https://api.github.com/user)
    
    # Use jq if available, otherwise use grep
    if command -v jq &> /dev/null; then
        login=$(echo "$result" | jq -r '.login // empty')
        message=$(echo "$result" | jq -r '.message // empty')
    else
        # Fallback to grep/sed if jq is not available
        login=$(echo "$result" | grep -o '"login":"[^"]*"' | head -1 | sed 's/"login":"\([^"]*\)"/\1/')
        message=$(echo "$result" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"\([^"]*\)"/\1/')
    fi
    
    # Debug output
    echo -e "${BLUE}Debug: API response login field = '$login'${NC}"
    [ -n "$message" ] && echo -e "${BLUE}Debug: API response message = '$message'${NC}"
    
    if [ -n "$login" ] && [ "$login" != "null" ]; then
        echo -e "${GREEN}‚úì PAT is valid (authenticated as: $login)${NC}"
        return 0
    else
        echo -e "${RED}‚úó PAT is invalid${NC}"
        if [ -n "$message" ] && [ "$message" != "null" ]; then
            echo -e "${RED}Error: $message${NC}"
        fi
        # Debug: Show first/last 4 chars of token
        if [ ${#token} -gt 8 ]; then
            echo -e "${BLUE}Debug: Token starts with '${token:0:4}' and ends with '${token: -4}'${NC}"
        fi
        return 1
    fi
}

# Test existing credentials
test_existing_credentials() {
    echo -e "${YELLOW}Testing existing credentials...${NC}"
    
    # Retrieve credentials
    local retrieved=$(echo "protocol=https
host=github.com
" | git credential-osxkeychain get 2>/dev/null || echo "")
    
    if [ -z "$retrieved" ]; then
        echo -e "${RED}‚úó No credentials found${NC}"
        return 1
    fi
    
    local stored_username=$(echo "$retrieved" | grep "^username=" | cut -d'=' -f2)
    local stored_password=$(echo "$retrieved" | grep "^password=" | cut -d'=' -f2)
    
    if [ -z "$stored_username" ] || [ -z "$stored_password" ]; then
        echo -e "${RED}‚úó Incomplete credentials${NC}"
        return 1
    fi
    
    # Test the stored credentials using the same method
    local result=$(curl -s -H "Authorization: Bearer $stored_password" https://api.github.com/user)
    
    if command -v jq &> /dev/null; then
        login=$(echo "$result" | jq -r '.login // empty')
    else
        login=$(echo "$result" | grep -o '"login":"[^"]*"' | head -1 | sed 's/"login":"\([^"]*\)"/\1/')
    fi
    
    if [ -n "$login" ] && [ "$login" != "null" ]; then
        echo -e "${GREEN}‚úì Existing credentials are valid (authenticated as: $login)${NC}"
        return 0
    else
        echo -e "${RED}‚úó Existing credentials are invalid or expired${NC}"
        return 1
    fi
}

# Store credentials in keychain
store_credentials() {
    local username=$1
    local token=$2
    
    echo -e "${YELLOW}Storing credentials in macOS Keychain...${NC}"
    
    # Store credentials directly using git credential helper
    echo "protocol=https
host=github.com
username=$username
password=$token
" | git credential-osxkeychain store
    
    echo -e "${GREEN}‚úì Credentials stored securely in macOS Keychain${NC}"
}

# Verify stored credentials
verify_credentials() {
    echo -e "${YELLOW}Verifying stored credentials...${NC}"
    
    # Try to retrieve credentials from keychain
    retrieved=$(echo "protocol=https
host=github.com
" | git credential-osxkeychain get 2>/dev/null || echo "")
    
    if [ -n "$retrieved" ]; then
        echo -e "${GREEN}‚úì Credentials successfully stored and retrieved from Keychain${NC}"
        return 0
    else
        echo -e "${RED}‚úó Could not verify stored credentials${NC}"
        return 1
    fi
}

# Main function
main() {
    local username=""
    local token=""
    local force=false
    local remove=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--username)
                username="$2"
                shift 2
                ;;
            -t|--token)
                token="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -r|--remove)
                remove=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run basic checks
    check_macos
    check_git
    
    # Check for git-credential-osxkeychain
    if ! check_git_credential_osxkeychain; then
        echo -e "\n${RED}Error: Cannot proceed without git-credential-osxkeychain${NC}"
        exit 1
    fi
    
    # Handle --remove flag
    if [ "$remove" = true ]; then
        remove_credentials_and_exit
    fi
    
    echo -e "${GREEN}=== GitHub PAT Setup for macOS ===${NC}\n"
    
    # Check for existing credentials
    if check_existing_credentials; then
        if [ "$force" = false ]; then
            echo -e "\n${BLUE}Existing credentials found in Keychain.${NC}"
            
            # Test if existing credentials are still valid
            if test_existing_credentials; then
                echo -e "\n${GREEN}Your existing credentials are working fine!${NC}"
                read -p "Do you want to update them anyway? (y/N): " update_confirm
                if [[ ! "$update_confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${BLUE}Keeping existing credentials. Exiting.${NC}"
                    exit 0
                fi
            else
                echo -e "\n${YELLOW}Your existing credentials appear to be invalid or expired.${NC}"
                read -p "Do you want to update them? (Y/n): " update_confirm
                if [[ "$update_confirm" =~ ^[Nn]$ ]]; then
                    echo -e "${BLUE}Keeping existing credentials. Exiting.${NC}"
                    exit 0
                fi
            fi
            
            # Remove existing credentials before storing new ones
            remove_existing_credentials
        else
            echo -e "${YELLOW}Force flag detected. Will update existing credentials.${NC}"
            remove_existing_credentials
        fi
    fi
    
    # Get username if not provided
    if [ -z "$username" ]; then
        read -p "Enter your GitHub username: " username
        # Trim whitespace from username
        username=$(echo "$username" | xargs)
    fi
    
    if [ -z "$username" ]; then
        echo -e "${RED}Error: Username is required${NC}"
        exit 1
    fi
    
    # Get token if not provided
    if [ -z "$token" ]; then
        echo -e "${YELLOW}Enter your GitHub Personal Access Token (PAT):${NC}"
        echo -e "${YELLOW}(input will be hidden)${NC}"
        read -s token
        echo ""
        # Trim ALL whitespace (including newlines, spaces, tabs) from token
        token=$(echo "$token" | tr -d '[:space:]')
    else
        # Also trim whitespace if token was provided via command line
        token=$(echo "$token" | tr -d '[:space:]')
    fi
    
    if [ -z "$token" ]; then
        echo -e "${RED}Error: PAT is required${NC}"
        exit 1
    fi
    
    # Validate token format (GitHub PATs start with ghp_, gho_, ghu_, ghs_, or ghr_)
    if [[ ! "$token" =~ ^(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36,}$ ]]; then
        echo -e "${YELLOW}Warning: Token format doesn't match expected GitHub PAT format${NC}"
        echo -e "${YELLOW}Expected format: ghp_xxxx... (starts with ghp_, gho_, ghu_, ghs_, or ghr_)${NC}"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Test the PAT
    if ! test_github_pat "$username" "$token"; then
        echo -e "${RED}Error: PAT validation failed. Please check your token and try again.${NC}"
        echo -e "${YELLOW}Tip: Make sure you copied the entire token without extra spaces${NC}"
        exit 1
    fi
    
    # Configure Git
    configure_git_credential_helper
    
    # Store credentials
    store_credentials "$username" "$token"
    
    # Verify
    if verify_credentials; then
        echo -e "\n${GREEN}=== Setup Complete ===${NC}"
        echo -e "${GREEN}Your GitHub PAT is now securely stored in macOS Keychain.${NC}"
        echo -e "${GREEN}You won't need to enter credentials for future Git operations with GitHub.${NC}"
        echo -e "\n${YELLOW}Note: Your credentials are stored in Keychain Access.app${NC}"
        echo -e "${YELLOW}You can view/manage them at: Keychain Access > github.com${NC}"
        echo -e "${YELLOW}To remove credentials, run: $0 --remove${NC}"
    else
        echo -e "\n${YELLOW}Warning: Setup completed but verification failed.${NC}"
        echo -e "${YELLOW}Try running a git operation to test.${NC}"
    fi
}

# Run main function
main "$@"
