# GCS Static Website Hosting Script

A comprehensive bash script for automating the deployment of static websites to Google Cloud Storage buckets.

## Features

### Core Functionality
- **Bucket Creation**: Create GCS buckets optimized for static website hosting
- **File Upload**: Recursively upload website files while preserving directory structure
- **Website Configuration**: Set index and error pages (e.g., index.html, 404.html)
- **Public Access**: Configure IAM policies to make content publicly accessible
- **Complete Setup**: One-command deployment workflow
- **Status Reporting**: View bucket configuration and content details
- **Cleanup**: Safe bucket deletion with confirmation prompts

### Advanced Options
- **Dry Run Mode**: Preview operations without executing them
- **Verbose Logging**: Detailed operation tracking
- **Force Mode**: Skip confirmation prompts for automation
- **Flexible Storage**: Support for multiple storage classes (standard, nearline, coldline, archive)
- **Location Control**: Deploy to any GCS region
- **Selective Operations**: Run individual steps or complete workflows

## Prerequisites

1. **gcloud CLI**: Install from https://cloud.google.com/sdk/docs/install
2. **Authentication**: Run `gcloud auth login` to authenticate
3. **GCP Project**: Have a GCP project with billing enabled
4. **API Access**: Compute Engine API must be enabled
5. **IAM Permissions**: Your account needs:
   - Storage Admin (`roles/storage.admin`)
   - Compute Network Admin (`roles/compute.networkAdmin`) - for load balancer setup

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/gcs-static-website/main/gcs-static-website.sh

# Make it executable
chmod +x gcs-static-website.sh

# Optionally, move to your PATH
sudo mv gcs-static-website.sh /usr/local/bin/gcs-website
```

## Usage

### Basic Syntax

```bash
./gcs-static-website.sh [OPTIONS] ACTION
```

### Actions

| Action | Description |
|--------|-------------|
| `create` | Create a new bucket for static website hosting |
| `upload` | Upload website files to the bucket |
| `configure` | Configure website settings (index/error pages) |
| `make-public` | Make all bucket objects publicly accessible |
| `setup` | Run create, upload, configure, and make-public in sequence |
| `setup-lb` | Create load balancer with SSL for custom domain (HTTPS) |
| `status` | Display bucket configuration and status |
| `status-lb` | Display load balancer and SSL certificate status |
| `list` | List files in the bucket |
| `remove` | Remove a file or folder from the bucket |
| `clean-lb` | Delete load balancer, SSL cert, and reserved IP |
| `clean` | Delete the bucket and all its contents |

### Options

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--project` | `-p` | GCP Project ID | Yes |
| `--bucket` | `-b` | Bucket name | Yes |
| `--source` | `-s` | Source directory containing website files | For upload/setup |
| `--index` | `-i` | Index page filename (default: index.html) | No |
| `--error` | `-e` | Error page filename (default: 404.html) | No |
| `--location` | `-l` | Bucket location (default: us) | No |
| `--class` | `-c` | Storage class (default: standard) | No |
| `--recursive` | `-r` | List files recursively (for list action) | No |
| `--path` | | Path to file/folder to remove (for remove action) | For remove |
| `--domain` | | Custom domain(s) for SSL (comma-separated) | For setup-lb |
| `--lb-name` | | Load balancer name (default: BUCKET_NAME-lb) | No |
| `--cert-name` | | SSL certificate name (default: BUCKET_NAME-cert) | No |
| `--ip-name` | | Static IP name (default: BUCKET_NAME-ip) | No |
| `--skip-public` | | Skip making bucket public during setup | No |
| `--force` | `-f` | Force operations without confirmation | No |
| `--dry-run` | `-d` | Show what would be done without executing | No |
| `--verbose` | `-v` | Enable verbose output | No |
| `--help` | `-h` | Display help message | No |

## Examples

### Complete Website Setup

Deploy a complete static website in one command:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./website \
  setup
```

### Step-by-Step Deployment

#### 1. Create Bucket

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -l us-central1 \
  -c standard \
  create
```

#### 2. Upload Files

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./website \
  upload
```

#### 3. Configure Website Settings

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -i index.html \
  -e 404.html \
  configure
```

#### 4. Make Public

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  make-public
```

### Custom Configuration

Use custom index and error pages:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./dist \
  -i home.html \
  -e notfound.html \
  setup
```

### Preview Changes (Dry Run)

Preview what would happen without making changes:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./website \
  -d \
  setup
```

### Check Bucket Status

View bucket configuration and content:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  status
```

### List Files

List top-level files and folders:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  list
```

List all files recursively:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -r \
  list
```

### Remove Files or Folders

Remove a specific file:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --path images/logo.png \
  remove
```

Remove a folder and all its contents (note the trailing slash):

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --path assets/ \
  remove
```

Remove with force (no confirmation):

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --path old-content/ \
  -f \
  remove
```

Preview removal with dry-run:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --path scripts/ \
  -d \
  remove
```

### Delete Bucket

Remove bucket with confirmation:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  clean
```

Force delete without confirmation (use with caution):

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -f \
  clean
```

### Verbose Mode

Get detailed information about operations:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./website \
  -v \
  setup
```

## Storage Class Options

Choose the appropriate storage class based on your access patterns:

- **standard**: Best for frequently accessed data (default)
- **nearline**: Low-cost for infrequently accessed data (once per month)
- **coldline**: Very low-cost for rarely accessed data (once per 90 days)
- **archive**: Lowest cost for archival data (once per year)

Example with nearline storage:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -c nearline \
  create
```

## Location Options

Deploy to any GCS region. Common locations include:

- **us**: United States (multi-region)
- **eu**: Europe (multi-region)
- **asia**: Asia (multi-region)
- **us-central1**: Iowa
- **us-east1**: South Carolina
- **europe-west1**: Belgium
- **asia-southeast1**: Singapore

Example with specific region:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -l europe-west1 \
  create
```

## File Management

### Listing Files

The `list` action allows you to view the contents of your bucket:

**Top-level listing** (default):
- Shows files and folders at the root level
- Faster for large buckets
- Good for getting an overview

**Recursive listing** (with `-r` flag):
- Shows all files in all subdirectories
- Provides complete file inventory
- Displays total object count

### Removing Files

The `remove` action allows you to delete specific files or entire folders:

**File removal**:
- Specify the exact path to the file
- Example: `--path images/logo.png`

**Folder removal**:
- Add a trailing slash to the path
- Example: `--path assets/`
- Recursively deletes all contents

**Safety features**:
- Confirmation prompt by default
- Use `-f/--force` to skip confirmation (for automation)
- Use `-d/--dry-run` to preview what would be deleted
- Validates path exists before deletion

## Accessing Your Website

After deployment, your website will be accessible at:

```
https://storage.googleapis.com/BUCKET_NAME/index.html
```

For example:
```
https://storage.googleapis.com/my-website-bucket/index.html
```

## HTTPS Setup with Custom Domain

The script includes full automation for setting up HTTPS with custom domains using Google Cloud Load Balancer and SSL certificates.

### Quick Start

```bash
# Complete HTTPS setup with custom domain
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --domain www.example.com,example.com \
  setup-lb
```

This will:
1. ✅ Reserve a static IP address
2. ✅ Create a Google-managed SSL certificate
3. ✅ Set up an external Application Load Balancer
4. ✅ Configure backend bucket with CDN enabled
5. ✅ Create URL map and forwarding rules
6. ✅ Display DNS configuration instructions

### Prerequisites for HTTPS Setup

**You must own a domain** (e.g., `example.com`). You cannot use this feature without a custom domain.

**Domain Options**:
- Single domain: `--domain www.example.com`
- Multiple domains: `--domain www.example.com,example.com`
- Subdomain: `--domain blog.example.com`

### Step-by-Step HTTPS Setup

#### 1. Create and Deploy Your Website First

```bash
# Setup bucket and upload files
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  -s ./website \
  setup
```

#### 2. Create Load Balancer with SSL

```bash
# Setup HTTPS for your custom domain
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --domain www.example.com,example.com \
  setup-lb
```

The script will output your static IP address and DNS instructions.

#### 3. Configure DNS Records

Add A records to your domain's DNS:

```
Type: A
Name: www
Value: [STATIC_IP_FROM_OUTPUT]

Type: A
Name: @
Value: [STATIC_IP_FROM_OUTPUT]
```

**DNS Providers**: GoDaddy, Namecheap, Cloudflare, Cloud Domains, etc.

#### 4. Wait for SSL Certificate Provisioning

SSL certificates take **15-60 minutes** to provision after DNS configuration.

Check status:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  status-lb
```

Look for `managed.status: ACTIVE` in the output.

#### 5. Access Your Website

Once the certificate is active:

```
https://www.example.com
https://example.com
```

### Load Balancer Management

#### Check Status

View load balancer, SSL certificate, and static IP status:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  status-lb
```

This shows:
- Static IP address and reservation status
- SSL certificate provisioning status
- Domain validation status
- Load balancer configuration
- Forwarding rules

#### Delete Load Balancer

Remove all load balancer infrastructure:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  clean-lb
```

This deletes:
- Forwarding rule
- Target HTTPS proxy
- URL map
- Backend bucket configuration
- SSL certificate
- Reserved static IP address

**Important**: The GCS bucket and its contents are NOT deleted. Use `clean` action to delete the bucket.

### Custom Names

Use custom names for load balancer components:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --domain www.example.com \
  --lb-name my-custom-lb \
  --cert-name my-ssl-cert \
  --ip-name my-static-ip \
  setup-lb
```

### Advanced Configuration

#### With Dry Run

Preview what would be created:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --domain www.example.com \
  -d \
  setup-lb
```

#### With Verbose Output

Get detailed operation logs:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-website-bucket \
  --domain www.example.com \
  -v \
  setup-lb
```

### Two Deployment Options

#### Option 1: Direct GCS Access (No Custom Domain)

**Use when**: Development, testing, or no custom domain needed

```bash
# Basic setup
./gcs-static-website.sh -p my-project -b my-bucket -s ./website setup

# Access via:
https://storage.googleapis.com/my-bucket/index.html
```

**Pros**:
- ✅ Simple and fast
- ✅ Free HTTPS (Google's certificate)
- ✅ No domain required
- ✅ No DNS configuration

**Cons**:
- ❌ Long URL (not branded)
- ❌ Can't use custom domain

#### Option 2: Custom Domain with Load Balancer (Production)

**Use when**: Production websites, custom branding needed

```bash
# Full setup with HTTPS
./gcs-static-website.sh -p my-project -b my-bucket -s ./website setup
./gcs-static-website.sh -p my-project -b my-bucket --domain www.example.com setup-lb

# Access via:
https://www.example.com
```

**Pros**:
- ✅ Custom domain (branded)
- ✅ Professional appearance
- ✅ Free SSL certificate
- ✅ CDN included
- ✅ Multiple domains supported

**Cons**:
- ❌ Requires domain ownership
- ❌ DNS configuration needed
- ❌ 15-60 min SSL provisioning
- ❌ Additional costs (load balancer, egress)

## Troubleshooting

### Authentication Issues

```bash
# Verify authentication
gcloud auth list

# Re-authenticate if needed
gcloud auth login

# Set default project
gcloud config set project PROJECT_ID
```

### Permission Errors

Ensure your account has the required IAM roles:

```bash
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

### Bucket Already Exists

If the bucket name is already taken (globally unique), choose a different name:

```bash
./gcs-static-website.sh \
  -p my-project \
  -b my-unique-website-bucket-12345 \
  create
```

### Files Not Uploading

Verify the source directory exists and contains files:

```bash
ls -la ./website
```

### Cannot Remove File/Folder

If removal fails, verify the path:

```bash
# List files to find the correct path
./gcs-static-website.sh -p my-project -b my-website-bucket -r list

# For folders, ensure trailing slash
./gcs-static-website.sh -p my-project -b my-website-bucket --path folder/ remove
```

### SSL Certificate Not Provisioning

If SSL certificate stays in `PROVISIONING` state:

1. **Verify DNS**: Ensure A records point to the correct IP
   ```bash
   # Check DNS propagation
   nslookup www.example.com
   dig www.example.com
   ```

2. **Check domain status**:
   ```bash
   ./gcs-static-website.sh -p my-project -b my-bucket status-lb
   ```

3. **Wait**: SSL provisioning takes 15-60 minutes after DNS is configured

4. **Domain verification**: Ensure you own the domain and it's verified with Google

### Load Balancer Errors

**403 Forbidden**: Bucket might not be public
```bash
./gcs-static-website.sh -p my-project -b my-bucket make-public
```

**404 Not Found**: Check if files exist in bucket
```bash
./gcs-static-website.sh -p my-project -b my-bucket -r list
```

**Certificate errors**: Check certificate status
```bash
gcloud compute ssl-certificates describe CERT_NAME --global
```

### Public Access Not Working

Check if public access prevention is enabled:

```bash
gcloud storage buckets describe gs://BUCKET_NAME \
  --format="get(iamConfiguration.publicAccessPrevention)"
```

## Security Considerations

### Public Access Warning

Making a bucket public exposes all content to the internet. Ensure:
- No sensitive data is in the bucket
- No credentials or API keys in your code
- No private information in HTML/JS files

### Best Practices

1. **Separate Buckets**: Use different buckets for public and private content
2. **Version Control**: Keep website source in version control (Git)
3. **Review Before Upload**: Check files before making bucket public
4. **Regular Audits**: Periodically review bucket permissions
5. **Use HTTPS**: Set up load balancer for production sites

## Workflow Integration

### CI/CD Pipeline Example (GitHub Actions)

```yaml
name: Deploy to GCS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Deploy website
        run: |
          ./gcs-static-website.sh \
            -p ${{ secrets.GCP_PROJECT }} \
            -b my-website-bucket \
            -s ./dist \
            upload
```

### Makefile Integration

```makefile
.PHONY: deploy status list clean-files clean

deploy:
	./gcs-static-website.sh -p $(PROJECT) -b $(BUCKET) -s ./dist upload

status:
	./gcs-static-website.sh -p $(PROJECT) -b $(BUCKET) status

list:
	./gcs-static-website.sh -p $(PROJECT) -b $(BUCKET) -r list

clean-files:
	./gcs-static-website.sh -p $(PROJECT) -b $(BUCKET) --path $(PATH) remove

clean:
	./gcs-static-website.sh -p $(PROJECT) -b $(BUCKET) -f clean
```

## Performance Tips

1. **Enable CDN**: Use Cloud CDN with load balancer for faster global delivery
2. **Compress Files**: Gzip HTML/CSS/JS before uploading
3. **Cache Headers**: Set appropriate cache-control headers
4. **Optimize Images**: Compress images before deployment
5. **Minify Assets**: Minify CSS/JS files

## Cost Considerations

### Storage Costs
- **Bucket storage**: Minimal for static websites
- **Storage class optimization**: Use nearline/coldline for archives

### Load Balancer Costs (when using HTTPS with custom domain)
- **Forwarding rules**: ~$18/month for first 5 rules
- **Egress (outbound traffic)**: Varies by region and volume
- **Static IP**: ~$0.01/hour when not attached to forwarding rule
- **CDN (if enabled)**: Based on cache egress and requests

### Cost Optimization Tips
1. **Start without load balancer**: Use direct GCS access for development
2. **Enable CDN**: Reduces egress costs for frequently accessed content
3. **Set up billing alerts**: Monitor costs in GCP Console
4. **Regional buckets**: Use specific regions vs multi-region for lower costs
5. **Lifecycle policies**: Automatically delete old versions
6. **Monitor usage**: Review Cloud Billing reports regularly

### Estimate Your Costs

Use the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) to estimate:
- Cloud Storage costs
- Load Balancer costs
- Network egress costs

## Features Roadmap

Potential future enhancements:

- ✅ Load balancer automation (implemented)
- ✅ SSL certificate management (implemented)
- ⬜ HTTP to HTTPS redirect automation
- ⬜ CDN cache invalidation
- ⬜ Lifecycle policy management
- ⬜ CORS configuration
- ⬜ Custom domain verification automation
- ⬜ IPv6 support
- ⬜ Multiple backend buckets
- ⬜ Cloud Armor integration

## Contributing

Contributions are welcome! Please open issues or pull requests on GitHub.

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GCS Documentation: https://cloud.google.com/storage/docs
- Script Issues: Open an issue on GitHub
- GCP Support: https://cloud.google.com/support

## References

- [GCS Static Website Hosting](https://cloud.google.com/storage/docs/hosting-static-website)
- [gcloud Storage Commands](https://cloud.google.com/sdk/gcloud/reference/storage)
- [Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates)
