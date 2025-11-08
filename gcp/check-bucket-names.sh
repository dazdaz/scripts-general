#!/bin/bash

# GCS Bucket Name Availability Checker
# Checks if bucket names are valid and available without creating them

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Counters
VALID_COUNT=0
INVALID_COUNT=0
AVAILABLE_COUNT=0
TAKEN_COUNT=0
ERROR_COUNT=0

# Arrays to store results
declare -a VALID_NAMES=()
declare -a INVALID_NAMES=()
declare -a AVAILABLE_NAMES=()
declare -a TAKEN_NAMES=()
declare -a ERROR_NAMES=()

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [BUCKET_NAMES...]

Check if GCS bucket names are valid and available without creating them.

OPTIONS:
    -f, --file FILE     Read bucket names from file (one per line)
    -p, --project ID    GCP Project ID (optional, for checking availability)
    -q, --quiet         Suppress detailed output, show only summary
    -v, --verbose       Show detailed validation information
    -h, --help          Display this help message

ARGUMENTS:
    BUCKET_NAMES        One or more bucket names to check

EXAMPLES:
    # Check single bucket name
    $0 my-bucket-name

    # Check multiple bucket names
    $0 bucket1 bucket2 bucket3

    # Check names from file
    $0 -f bucket-names.txt

    # Check with project ID to verify availability
    $0 -p my-project my-bucket-name

    # Quiet mode (summary only)
    $0 -q bucket1 bucket2 bucket3

BUCKET NAME RULES:
    - Must be 3-63 characters long
    - Can only contain lowercase letters, numbers, hyphens, underscores, and dots
    - Must start and end with a letter or number
    - Cannot contain 'goog' prefix or 'google' substring
    - Cannot be formatted as IP address (e.g., 192.168.1.1)
    - Dots create subdomain-like structure (bucket.example.com style)

EXIT CODES:
    0 - All names are valid and available
    1 - One or more names are invalid or unavailable
    2 - Error (missing gcloud, authentication failed, etc.)

EOF
    exit 0
}

# Logging functions
log_info() {
    if [[ "$QUIET" == false ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_valid() {
    if [[ "$QUIET" == false ]]; then
        echo -e "${GREEN}✓ VALID${NC}  $1 ${CYAN}(meets GCS naming requirements)${NC}"
    fi
}

log_invalid() {
    echo -e "${RED}✗ INVALID${NC} $1 - $2"
}

log_available() {
    echo -e "${GREEN}✓ AVAILABLE${NC} $1"
}

log_taken() {
    echo -e "${YELLOW}✗ TAKEN${NC} $1"
}

log_error() {
    echo -e "${RED}✗ ERROR${NC} $1 - $2"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# Validate bucket name format
validate_bucket_name() {
    local name="$1"
    local errors=()
    
    # Length check (3-63 characters)
    if [[ ${#name} -lt 3 || ${#name} -gt 63 ]]; then
        errors+=("Length must be 3-63 characters (got ${#name})")
    fi
    
    # Character check (lowercase letters, numbers, hyphens, underscores, dots)
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9._-]*[a-z0-9]$ ]]; then
        errors+=("Must contain only lowercase letters, numbers, hyphens, underscores, and dots")
    fi
    
    # Start and end check
    if [[ ! "$name" =~ ^[a-z0-9] ]]; then
        errors+=("Must start with a letter or number")
    fi
    
    if [[ ! "$name" =~ [a-z0-9]$ ]]; then
        errors+=("Must end with a letter or number")
    fi
    
    # Google-related restrictions
    if [[ "$name" =~ ^goog ]]; then
        errors+=("Cannot start with 'goog'")
    fi
    
    if [[ "$name" =~ google ]]; then
        errors+=("Cannot contain 'google'")
    fi
    
    # IP address format check
    if [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        errors+=("Cannot be formatted as IP address")
    fi
    
    # Consecutive dots or hyphens
    if [[ "$name" =~ \.\. ]] || [[ "$name" =~ -- ]]; then
        errors+=("Cannot contain consecutive dots or hyphens")
    fi
    
    # Return validation result
    if [[ ${#errors[@]} -eq 0 ]]; then
        return 0
    else
        # Print errors
        for error in "${errors[@]}"; do
            log_verbose "  - $error"
        done
        echo "${errors[0]}"  # Return first error for display
        return 1
    fi
}

# Check if bucket name is available
check_availability() {
    local name="$1"
    local error_output
    
    # Try to describe the bucket globally (without project)
    # Capture both stdout and stderr
    error_output=$(gcloud storage buckets describe "gs://$name" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Bucket exists and we have access
        return 1  # Taken
    elif echo "$error_output" | grep -q "does not have permission\|Permission.*denied"; then
        # Permission error means bucket exists but we don't own it
        log_verbose "  Bucket exists (permission denied)"
        return 1  # Taken
    elif echo "$error_output" | grep -q "NOT_FOUND\|does not exist\|404"; then
        # Bucket truly doesn't exist
        return 0  # Available
    else
        # Unknown error - assume taken to be safe
        log_verbose "  Unknown error, assuming taken: $error_output"
        return 1  # Taken (safe default)
    fi
}

# Process a single bucket name
process_bucket_name() {
    local name="$1"
    
    # Validate format
    local validation_error
    if validation_error=$(validate_bucket_name "$name"); then
        log_valid "$name"
        VALID_NAMES+=("$name")
        ((VALID_COUNT++))
        
        # Always check availability
        if check_availability "$name"; then
            log_available "$name"
            AVAILABLE_NAMES+=("$name")
            ((AVAILABLE_COUNT++))
        else
            log_taken "$name"
            TAKEN_NAMES+=("$name")
            ((TAKEN_COUNT++))
        fi
    else
        log_invalid "$name" "$validation_error"
        INVALID_NAMES+=("$name")
        ((INVALID_COUNT++))
    fi
}

# Print summary
print_summary() {
    local total=$((VALID_COUNT + INVALID_COUNT + ERROR_COUNT))
    
    echo ""
    echo "============================================================"
    echo "SUMMARY: $VALID_COUNT valid, $INVALID_COUNT invalid"
    echo "AVAILABILITY: $AVAILABLE_COUNT available, $TAKEN_COUNT taken"
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo "ERRORS: $ERROR_COUNT"
    fi
    
    if [[ $INVALID_COUNT -eq 0 && $ERROR_COUNT -eq 0 ]]; then
        if [[ $TAKEN_COUNT -eq 0 ]]; then
            echo "All bucket names are valid and available! Ready to use in GCS."
        else
            echo "Some bucket names are already taken. Choose different names."
        fi
    else
        echo "Some bucket names need correction. See details above."
    fi
    echo "============================================================"
}

# Main function
main() {
    local bucket_names=()
    local file_path=""
    PROJECT_ID=""
    QUIET=false
    VERBOSE=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                file_path="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT_ID="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo "Error: Unknown option: $1"
                usage
                ;;
            *)
                bucket_names+=("$1")
                shift
                ;;
        esac
    done
    
    # Read from file if specified
    if [[ -n "$file_path" ]]; then
        if [[ ! -f "$file_path" ]]; then
            echo "Error: File not found: $file_path"
            exit 2
        fi
        
        log_info "Reading bucket names from $file_path..."
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Trim whitespace
            line=$(echo "$line" | xargs)
            bucket_names+=("$line")
        done < "$file_path"
    fi
    
    # Check if we have any bucket names
    if [[ ${#bucket_names[@]} -eq 0 ]]; then
        echo "Error: No bucket names provided"
        usage
    fi
    
    # Check for gcloud
    if ! command -v gcloud &> /dev/null; then
        echo "Error: gcloud CLI is not installed"
        echo "Visit: https://cloud.google.com/sdk/docs/install"
        exit 2
    fi
    
    # Check authentication (required for availability checking)
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        echo "Error: Not authenticated with gcloud"
        echo "Run: gcloud auth login"
        exit 2
    fi
    
    if [[ -n "$PROJECT_ID" ]]; then
        log_info "Project ID: $PROJECT_ID"
    fi
    
    log_info "Added ${#bucket_names[@]} name(s) from command line"
    echo ""
    echo "============================================================"
    echo "VALIDATING ${#bucket_names[@]} BUCKET NAME(S)"
    echo "============================================================"
    echo ""
    
    # Process each bucket name
    for name in "${bucket_names[@]}"; do
        process_bucket_name "$name"
    done
    
    # Print summary
    print_summary
    
    # Exit code
    if [[ $INVALID_COUNT -gt 0 || $ERROR_COUNT -gt 0 || $TAKEN_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
