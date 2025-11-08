#!/bin/bash

# GCS Static Website Hosting Script
# Automates the process of hosting a static website in Google Cloud Storage

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
BUCKET_NAME=""
SOURCE_DIR=""
INDEX_PAGE="index.html"
ERROR_PAGE="404.html"
LOCATION="us"
STORAGE_CLASS="standard"
ACTION=""
DRY_RUN=false
VERBOSE=false
FORCE=false
SKIP_PUBLIC=false
REMOVE_PATH=""
LIST_RECURSIVE=false
DOMAIN=""
LB_NAME=""
CERT_NAME=""
IP_NAME=""

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] ACTION

Host a static website in a Google Cloud Storage bucket.

ACTIONS:
    create              Create a new bucket for static website hosting
    upload              Upload website files to the bucket
    configure           Configure website settings (index/error pages)
    make-public         Make all bucket objects publicly accessible
    setup               Run create, upload, configure, and make-public in sequence
    setup-lb            Create load balancer with SSL for custom domain (HTTPS)
    status              Display bucket configuration and status
    status-lb           Display load balancer and SSL certificate status
    list                List files in the bucket
    remove              Remove a file or folder from the bucket
    clean-lb            Delete load balancer, SSL cert, and reserved IP
    clean               Delete the bucket and all its contents

OPTIONS:
    -p, --project PROJECT_ID        GCP Project ID (required)
    -b, --bucket BUCKET_NAME        Bucket name (required)
    -s, --source SOURCE_DIR         Source directory containing website files
    -i, --index INDEX_PAGE          Index page filename (default: index.html)
    -e, --error ERROR_PAGE          Error page filename (default: 404.html)
    -l, --location LOCATION         Bucket location (default: us)
    -c, --class STORAGE_CLASS       Storage class (default: standard)
                                    Options: standard, nearline, coldline, archive
    -r, --recursive                 List files recursively (for list action)
    --path PATH                     Path to file/folder to remove (for remove action)
    --domain DOMAIN                 Custom domain(s) for SSL (comma-separated, e.g., www.example.com,example.com)
    --lb-name NAME                  Load balancer name (default: BUCKET_NAME-lb)
    --cert-name NAME                SSL certificate name (default: BUCKET_NAME-cert)
    --ip-name NAME                  Static IP name (default: BUCKET_NAME-ip)
    --skip-public                   Skip making bucket public during setup
    -f, --force                     Force operations without confirmation
    -d, --dry-run                   Show what would be done without executing
    -v, --verbose                   Enable verbose output
    -h, --help                      Display this help message

EXAMPLES:
    # Complete setup - create bucket, upload files, configure, and make public
    $0 -p my-project -b my-website-bucket -s ./website setup
    # → Access at: https://storage.googleapis.com/my-website-bucket/index.html

    # Create bucket only
    $0 -p my-project -b my-website-bucket create

    # Upload files to existing bucket
    $0 -p my-project -b my-website-bucket -s ./website upload

    # Configure website settings
    $0 -p my-project -b my-website-bucket -i home.html -e notfound.html configure

    # Make bucket public
    $0 -p my-project -b my-website-bucket make-public

    # Check status
    $0 -p my-project -b my-website-bucket status

    # List all files in bucket
    $0 -p my-project -b my-website-bucket list

    # List files recursively
    $0 -p my-project -b my-website-bucket -r list

    # Remove a specific file
    $0 -p my-project -b my-website-bucket --path images/logo.png remove

    # Remove a folder
    $0 -p my-project -b my-website-bucket --path assets/ remove

    # Setup HTTPS with custom domain (requires domain ownership)
    $0 -p my-project -b my-website-bucket --domain www.example.com,example.com setup-lb
    # → After DNS setup and SSL provisioning: https://www.example.com

    # Check load balancer status
    $0 -p my-project -b my-website-bucket status-lb

    # Delete load balancer and SSL cert
    $0 -p my-project -b my-website-bucket clean-lb

    # Delete bucket (with confirmation)
    $0 -p my-project -b my-website-bucket clean

ACCESS YOUR WEBSITE:
    Option 1 - Direct GCS URL (no custom domain):
        https://storage.googleapis.com/BUCKET_NAME/index.html
    
    Option 2 - Custom domain (after setup-lb and DNS configuration):
        https://YOUR_DOMAIN/

PREREQUISITES:
    - gcloud CLI installed and authenticated
    - Compute Engine API enabled for the project
    - Appropriate IAM permissions (Storage Admin, Compute Network Admin)

EOF
    exit 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_verbose "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        log_error "Visit: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "Project ID is required. Use -p or --project option."
        exit 1
    fi
    
    if [[ -z "$BUCKET_NAME" ]]; then
        log_error "Bucket name is required. Use -b or --bucket option."
        exit 1
    fi
    
    # Verify gcloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_error "Not authenticated with gcloud. Run 'gcloud auth login' first."
        exit 1
    fi
    
    log_verbose "Prerequisites check passed"
}

# Check if bucket exists
bucket_exists() {
    gcloud storage buckets describe "gs://$BUCKET_NAME" --project="$PROJECT_ID" &> /dev/null
    return $?
}

# Create bucket
create_bucket() {
    log_info "Creating bucket: gs://$BUCKET_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create bucket with:"
        log_info "  Location: $LOCATION"
        log_info "  Storage class: $STORAGE_CLASS"
        return 0
    fi
    
    if bucket_exists; then
        log_warning "Bucket gs://$BUCKET_NAME already exists"
        return 0
    fi
    
    gcloud storage buckets create "gs://$BUCKET_NAME" \
        --project="$PROJECT_ID" \
        --location="$LOCATION" \
        --default-storage-class="$STORAGE_CLASS" \
        --public-access-prevention \
        --uniform-bucket-level-access
    
    log_success "Bucket created successfully"
}

# Upload files
upload_files() {
    if [[ -z "$SOURCE_DIR" ]]; then
        log_error "Source directory is required for upload. Use -s or --source option."
        exit 1
    fi
    
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory does not exist: $SOURCE_DIR"
        exit 1
    fi
    
    log_info "Uploading files from $SOURCE_DIR to gs://$BUCKET_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would upload files from: $SOURCE_DIR"
        log_info "[DRY RUN] Files to upload:"
        find "$SOURCE_DIR" -type f | head -10
        local file_count=$(find "$SOURCE_DIR" -type f | wc -l)
        if [[ $file_count -gt 10 ]]; then
            log_info "[DRY RUN] ... and $((file_count - 10)) more files"
        fi
        return 0
    fi
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    # Upload all files, preserving directory structure
    gcloud storage cp -r "$SOURCE_DIR/*" "gs://$BUCKET_NAME/" \
        --project="$PROJECT_ID"
    
    log_success "Files uploaded successfully"
}

# Configure website settings
configure_website() {
    log_info "Configuring website settings..."
    log_info "  Index page: $INDEX_PAGE"
    log_info "  Error page: $ERROR_PAGE"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would configure website with index: $INDEX_PAGE, error: $ERROR_PAGE"
        return 0
    fi
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    gcloud storage buckets update "gs://$BUCKET_NAME" \
        --web-main-page-suffix="$INDEX_PAGE" \
        --web-error-page="$ERROR_PAGE" \
        --project="$PROJECT_ID"
    
    log_success "Website configuration updated"
}

# Make bucket public
make_public() {
    log_info "Making bucket publicly accessible..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would grant allUsers the Storage Object Viewer role"
        return 0
    fi
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    # Remove public access prevention first
    log_verbose "Removing public access prevention..."
    gcloud storage buckets update "gs://$BUCKET_NAME" \
        --no-public-access-prevention \
        --project="$PROJECT_ID"
    
    # Grant public access
    log_verbose "Granting public access..."
    gcloud storage buckets add-iam-policy-binding "gs://$BUCKET_NAME" \
        --member=allUsers \
        --role=roles/storage.objectViewer \
        --project="$PROJECT_ID"
    
    log_success "Bucket is now publicly accessible"
    log_warning "All objects in this bucket are now publicly readable"
}

# Display bucket status
show_status() {
    log_info "Fetching bucket information for gs://$BUCKET_NAME"
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    echo ""
    echo "=== Bucket Details ==="
    gcloud storage buckets describe "gs://$BUCKET_NAME" \
        --project="$PROJECT_ID" \
        --format="yaml(name,location,storageClass,timeCreated,updated,website)"
    
    echo ""
    echo "=== IAM Policy (Public Access) ==="
    gcloud storage buckets get-iam-policy "gs://$BUCKET_NAME" \
        --project="$PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:allUsers" \
        --format="table(bindings.role)" 2>/dev/null || echo "No public access configured"
    
    echo ""
    echo "=== Object Count ==="
    local object_count=$(gcloud storage ls "gs://$BUCKET_NAME" --project="$PROJECT_ID" 2>/dev/null | wc -l)
    echo "Total objects: $object_count"
    
    if [[ $object_count -gt 0 ]]; then
        echo ""
        echo "=== Sample Objects (first 10) ==="
        gcloud storage ls "gs://$BUCKET_NAME/**" \
            --project="$PROJECT_ID" 2>/dev/null | head -10
    fi

    echo ""
    echo "=== Website URL ==="
    echo "https://storage.googleapis.com/$BUCKET_NAME/$INDEX_PAGE"
}

# List files in bucket
list_files() {
    log_info "Listing files in gs://$BUCKET_NAME"
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    echo ""
    if [[ "$LIST_RECURSIVE" == true ]]; then
        log_info "Listing all files recursively..."
        gcloud storage ls -r "gs://$BUCKET_NAME/**" \
            --project="$PROJECT_ID"
    else
        log_info "Listing top-level files and folders..."
        gcloud storage ls "gs://$BUCKET_NAME" \
            --project="$PROJECT_ID"
    fi
    
    echo ""
    local object_count=$(gcloud storage ls -r "gs://$BUCKET_NAME/**" --project="$PROJECT_ID" 2>/dev/null | grep -v ":$" | wc -l)
    log_info "Total objects: $object_count"
}

# Remove file or folder from bucket
remove_from_bucket() {
    if [[ -z "$REMOVE_PATH" ]]; then
        log_error "Path is required for remove action. Use --path option."
        exit 1
    fi
    
    local full_path="gs://$BUCKET_NAME/$REMOVE_PATH"
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist"
        exit 1
    fi
    
    # Determine if it's a file or folder
    local is_folder=false
    if [[ "$REMOVE_PATH" == */ ]]; then
        is_folder=true
    fi
    
    if [[ "$is_folder" == true ]]; then
        log_info "Removing folder: $full_path"
    else
        log_info "Removing file: $full_path"
    fi
    
    if [[ "$FORCE" == false ]]; then
        echo -e "${YELLOW}WARNING: This will permanently delete the specified content.${NC}"
        read -p "Are you sure you want to continue? (yes/no): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would remove: $full_path"
        return 0
    fi
    
    # Check if path exists
    if ! gcloud storage ls "$full_path" --project="$PROJECT_ID" &> /dev/null; then
        log_error "Path does not exist: $full_path"
        exit 1
    fi
    
    if [[ "$is_folder" == true ]]; then
        gcloud storage rm -r "$full_path**" \
            --project="$PROJECT_ID"
        log_success "Folder removed successfully"
    else
        gcloud storage rm "$full_path" \
            --project="$PROJECT_ID"
        log_success "File removed successfully"
    fi
}

# Setup load balancer with SSL certificate
setup_load_balancer() {
    if [[ -z "$DOMAIN" ]]; then
        log_error "Domain is required for load balancer setup. Use --domain option."
        log_error "Example: --domain www.example.com,example.com"
        exit 1
    fi
    
    # Set default names if not provided
    LB_NAME="${LB_NAME:-${BUCKET_NAME}-lb}"
    CERT_NAME="${CERT_NAME:-${BUCKET_NAME}-cert}"
    IP_NAME="${IP_NAME:-${BUCKET_NAME}-ip}"
    
    log_info "Setting up HTTPS load balancer for custom domain(s)..."
    log_info "  Domain(s): $DOMAIN"
    log_info "  Load Balancer: $LB_NAME"
    log_info "  SSL Certificate: $CERT_NAME"
    log_info "  Static IP: $IP_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create load balancer infrastructure"
        return 0
    fi
    
    if ! bucket_exists; then
        log_error "Bucket gs://$BUCKET_NAME does not exist. Create it first."
        exit 1
    fi
    
    echo ""
    log_info "Step 1/6: Reserving static IP address..."
    if gcloud compute addresses describe "$IP_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Static IP $IP_NAME already exists"
        STATIC_IP=$(gcloud compute addresses describe "$IP_NAME" --global --project="$PROJECT_ID" --format="get(address)")
    else
        gcloud compute addresses create "$IP_NAME" \
            --ip-version=IPV4 \
            --global \
            --project="$PROJECT_ID"
        STATIC_IP=$(gcloud compute addresses describe "$IP_NAME" --global --project="$PROJECT_ID" --format="get(address)")
        log_success "Static IP reserved: $STATIC_IP"
    fi
    
    echo ""
    log_info "Step 2/6: Creating SSL certificate..."
    if gcloud compute ssl-certificates describe "$CERT_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        log_warning "SSL certificate $CERT_NAME already exists"
    else
        gcloud compute ssl-certificates create "$CERT_NAME" \
            --domains="$DOMAIN" \
            --global \
            --project="$PROJECT_ID"
        log_success "SSL certificate created (provisioning may take 15-60 minutes)"
    fi
    
    echo ""
    log_info "Step 3/6: Creating backend bucket..."
    local backend_bucket="${BUCKET_NAME}-backend"
    if gcloud compute backend-buckets describe "$backend_bucket" --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Backend bucket $backend_bucket already exists"
    else
        gcloud compute backend-buckets create "$backend_bucket" \
            --gcs-bucket-name="$BUCKET_NAME" \
            --enable-cdn \
            --project="$PROJECT_ID"
        log_success "Backend bucket created"
    fi
    
    echo ""
    log_info "Step 4/6: Creating URL map..."
    if gcloud compute url-maps describe "$LB_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        log_warning "URL map $LB_NAME already exists"
    else
        gcloud compute url-maps create "$LB_NAME" \
            --default-backend-bucket="$backend_bucket" \
            --global \
            --project="$PROJECT_ID"
        log_success "URL map created"
    fi
    
    echo ""
    log_info "Step 5/6: Creating target HTTPS proxy..."
    local target_proxy="${LB_NAME}-proxy"
    if gcloud compute target-https-proxies describe "$target_proxy" --global --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Target HTTPS proxy $target_proxy already exists"
    else
        gcloud compute target-https-proxies create "$target_proxy" \
            --ssl-certificates="$CERT_NAME" \
            --url-map="$LB_NAME" \
            --global \
            --project="$PROJECT_ID"
        log_success "Target HTTPS proxy created"
    fi
    
    echo ""
    log_info "Step 6/6: Creating forwarding rule..."
    local forwarding_rule="${LB_NAME}-https-rule"
    if gcloud compute forwarding-rules describe "$forwarding_rule" --global --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Forwarding rule $forwarding_rule already exists"
    else
        gcloud compute forwarding-rules create "$forwarding_rule" \
            --address="$IP_NAME" \
            --global \
            --target-https-proxy="$target_proxy" \
            --ports=443 \
            --project="$PROJECT_ID"
        log_success "Forwarding rule created"
    fi
    
    echo ""
    log_success "Load balancer setup complete!"
    echo ""
    log_warning "IMPORTANT: DNS Configuration Required"
    echo "----------------------------------------"
    echo "Add the following DNS record(s) to your domain:"
    echo ""
    IFS=',' read -ra DOMAINS <<< "$DOMAIN"
    for d in "${DOMAINS[@]}"; do
        # Remove www. prefix to get base domain
        if [[ "$d" == www.* ]]; then
            echo "  Type: A"
            echo "  Name: www"
            echo "  Value: $STATIC_IP"
            echo ""
        else
            echo "  Type: A"
            echo "  Name: @"
            echo "  Value: $STATIC_IP"
            echo ""
        fi
    done
    echo "----------------------------------------"
    echo ""
    log_warning "SSL Certificate Provisioning"
    echo "The SSL certificate will take 15-60 minutes to provision."
    echo "Use the 'status-lb' command to check the certificate status."
    echo ""
    log_info "Once DNS is configured and certificate is active, your site will be at:"
    IFS=',' read -ra DOMAINS <<< "$DOMAIN"
    echo "  https://${DOMAINS[0]}/$INDEX_PAGE"
}

# Show load balancer status
show_lb_status() {
    LB_NAME="${LB_NAME:-${BUCKET_NAME}-lb}"
    CERT_NAME="${CERT_NAME:-${BUCKET_NAME}-cert}"
    IP_NAME="${IP_NAME:-${BUCKET_NAME}-ip}"
    
    log_info "Fetching load balancer information..."
    
    echo ""
    echo "=== Static IP Address ==="
    if gcloud compute addresses describe "$IP_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute addresses describe "$IP_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --format="yaml(name,address,status)"
    else
        echo "Static IP not found: $IP_NAME"
    fi
    
    echo ""
    echo "=== SSL Certificate Status ==="
    if gcloud compute ssl-certificates describe "$CERT_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute ssl-certificates describe "$CERT_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --format="yaml(name,managed.status,managed.domainStatus)"
        
        echo ""
        local cert_status=$(gcloud compute ssl-certificates describe "$CERT_NAME" --global --project="$PROJECT_ID" --format="get(managed.status)")
        if [[ "$cert_status" == "ACTIVE" ]]; then
            log_success "SSL certificate is ACTIVE and ready to use"
        else
            log_warning "SSL certificate status: $cert_status"
            log_info "Provisioning typically takes 15-60 minutes after DNS configuration"
        fi
    else
        echo "SSL certificate not found: $CERT_NAME"
    fi
    
    echo ""
    echo "=== Load Balancer ==="
    if gcloud compute url-maps describe "$LB_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute url-maps describe "$LB_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --format="yaml(name,defaultBackendBucket)"
    else
        echo "Load balancer not found: $LB_NAME"
    fi
    
    echo ""
    echo "=== Forwarding Rules ==="
    local forwarding_rule="${LB_NAME}-https-rule"
    if gcloud compute forwarding-rules describe "$forwarding_rule" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute forwarding-rules describe "$forwarding_rule" \
            --global \
            --project="$PROJECT_ID" \
            --format="yaml(name,IPAddress,target,portRange)"
    else
        echo "Forwarding rule not found: $forwarding_rule"
    fi
}

# Clean up load balancer
clean_load_balancer() {
    LB_NAME="${LB_NAME:-${BUCKET_NAME}-lb}"
    CERT_NAME="${CERT_NAME:-${BUCKET_NAME}-cert}"
    IP_NAME="${IP_NAME:-${BUCKET_NAME}-ip}"
    
    if [[ "$FORCE" == false ]]; then
        echo -e "${YELLOW}WARNING: This will delete the load balancer, SSL certificate, and static IP.${NC}"
        echo "The following resources will be deleted:"
        echo "  - Forwarding rule: ${LB_NAME}-https-rule"
        echo "  - Target HTTPS proxy: ${LB_NAME}-proxy"
        echo "  - URL map: $LB_NAME"
        echo "  - Backend bucket: ${BUCKET_NAME}-backend"
        echo "  - SSL certificate: $CERT_NAME"
        echo "  - Static IP: $IP_NAME"
        read -p "Are you sure you want to continue? (yes/no): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    log_info "Deleting load balancer infrastructure..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would delete load balancer components"
        return 0
    fi
    
    local forwarding_rule="${LB_NAME}-https-rule"
    local target_proxy="${LB_NAME}-proxy"
    local backend_bucket="${BUCKET_NAME}-backend"
    
    echo ""
    log_info "Step 1/6: Deleting forwarding rule..."
    if gcloud compute forwarding-rules describe "$forwarding_rule" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute forwarding-rules delete "$forwarding_rule" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
        log_success "Forwarding rule deleted"
    else
        log_warning "Forwarding rule not found: $forwarding_rule"
    fi
    
    echo ""
    log_info "Step 2/6: Deleting target HTTPS proxy..."
    if gcloud compute target-https-proxies describe "$target_proxy" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute target-https-proxies delete "$target_proxy" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
        log_success "Target HTTPS proxy deleted"
    else
        log_warning "Target HTTPS proxy not found: $target_proxy"
    fi
    
    echo ""
    log_info "Step 3/6: Deleting URL map..."
    if gcloud compute url-maps describe "$LB_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute url-maps delete "$LB_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
        log_success "URL map deleted"
    else
        log_warning "URL map not found: $LB_NAME"
    fi
    
    echo ""
    log_info "Step 4/6: Deleting backend bucket..."
    if gcloud compute backend-buckets describe "$backend_bucket" --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute backend-buckets delete "$backend_bucket" \
            --project="$PROJECT_ID" \
            --quiet
        log_success "Backend bucket deleted"
    else
        log_warning "Backend bucket not found: $backend_bucket"
    fi
    
    echo ""
    log_info "Step 5/6: Deleting SSL certificate..."
    if gcloud compute ssl-certificates describe "$CERT_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute ssl-certificates delete "$CERT_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
        log_success "SSL certificate deleted"
    else
        log_warning "SSL certificate not found: $CERT_NAME"
    fi
    
    echo ""
    log_info "Step 6/6: Releasing static IP..."
    if gcloud compute addresses describe "$IP_NAME" --global --project="$PROJECT_ID" &> /dev/null; then
        gcloud compute addresses delete "$IP_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
        log_success "Static IP released"
    else
        log_warning "Static IP not found: $IP_NAME"
    fi
    
    echo ""
    log_success "Load balancer infrastructure deleted successfully"
}

# Clean up bucket
clean_bucket() {
    if [[ "$FORCE" == false ]]; then
        echo -e "${YELLOW}WARNING: This will delete the bucket gs://$BUCKET_NAME and all its contents.${NC}"
        read -p "Are you sure you want to continue? (yes/no): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    log_info "Deleting bucket gs://$BUCKET_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would delete bucket and all contents"
        return 0
    fi
    
    if ! bucket_exists; then
        log_warning "Bucket gs://$BUCKET_NAME does not exist"
        return 0
    fi
    
    gcloud storage rm -r "gs://$BUCKET_NAME" \
        --project="$PROJECT_ID"
    
    log_success "Bucket deleted successfully"
}

# Complete setup workflow
setup_workflow() {
    log_info "Starting complete website setup..."
    
    create_bucket
    
    if [[ -n "$SOURCE_DIR" ]]; then
        upload_files
    else
        log_warning "No source directory specified, skipping file upload"
    fi
    
    configure_website
    
    if [[ "$SKIP_PUBLIC" == false ]]; then
        make_public
    else
        log_info "Skipping public access configuration (--skip-public flag)"
    fi
    
    log_success "Website setup complete!"
    echo ""
    log_info "Your website should be accessible at:"
    log_info "https://storage.googleapis.com/$BUCKET_NAME/$INDEX_PAGE"
    echo ""
    log_warning "Note: For HTTPS with a custom domain, you'll need to set up a load balancer."
    log_info "See: https://cloud.google.com/storage/docs/hosting-static-website"
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project)
                PROJECT_ID="$2"
                shift 2
                ;;
            -b|--bucket)
                BUCKET_NAME="$2"
                shift 2
                ;;
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -i|--index)
                INDEX_PAGE="$2"
                shift 2
                ;;
            -e|--error)
                ERROR_PAGE="$2"
                shift 2
                ;;
            -l|--location)
                LOCATION="$2"
                shift 2
                ;;
            -c|--class)
                STORAGE_CLASS="$2"
                shift 2
                ;;
            -r|--recursive)
                LIST_RECURSIVE=true
                shift
                ;;
            --path)
                REMOVE_PATH="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --lb-name)
                LB_NAME="$2"
                shift 2
                ;;
            --cert-name)
                CERT_NAME="$2"
                shift 2
                ;;
            --ip-name)
                IP_NAME="$2"
                shift 2
                ;;
            --skip-public)
                SKIP_PUBLIC=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            create|upload|configure|make-public|setup|setup-lb|status|status-lb|list|remove|clean-lb|clean)
                ACTION="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    if [[ -z "$ACTION" ]]; then
        log_error "No action specified"
        usage
    fi
}

# Main function
main() {
    parse_args "$@"
    check_prerequisites
    
    case $ACTION in
        create)
            create_bucket
            ;;
        upload)
            upload_files
            ;;
        configure)
            configure_website
            ;;
        make-public)
            make_public
            ;;
        setup)
            setup_workflow
            ;;
        status)
            show_status
            ;;
        setup-lb)
            setup_load_balancer
            ;;
        status-lb)
            show_lb_status
            ;;
        list)
            list_files
            ;;
        remove)
            remove_from_bucket
            ;;
        clean-lb)
            clean_load_balancer
            ;;
        clean)
            clean_bucket
            ;;
        *)
            log_error "Invalid action: $ACTION"
            usage
            ;;
    esac
}

# Run main function
main "$@"
