# Windows Guide: SSL Certificate Generation and DNS Configuration for TIBCO Control Plane

This guide provides step-by-step instructions for generating SSL certificates and configuring DNS records for TIBCO Control Plane on Windows environments.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Method 1: Using Docker Desktop (Recommended)](#method-1-using-docker-desktop-recommended)
- [Method 2: Using WSL2 (Windows Subsystem for Linux)](#method-2-using-wsl2-windows-subsystem-for-linux)
- [Method 3: Using PowerShell with Certbot](#method-3-using-powershell-with-certbot)
- [DNS Record Creation (All Methods)](#dns-record-creation-all-methods)
- [DNS Verification (All Methods)](#dns-verification-all-methods)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have the following installed on your Windows machine:

### Common Requirements
- **Windows 10/11** (build 19041 or higher for WSL2)
- **OpenShift CLI (oc)** or **kubectl** for Windows
  - Download from: https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/windows/
  - Add to PATH: `C:\Program Files\OpenShift\oc.exe`
- **Azure CLI** for Windows
  - Download from: https://aka.ms/installazurecliwindows
  - Or install via: `winget install -e --id Microsoft.AzureCLI`

### Method-Specific Requirements
- **Docker Desktop**: For Method 1 (https://www.docker.com/products/docker-desktop/)
- **WSL2**: For Method 2 (Windows feature, enable via PowerShell)
- **Python 3.8+**: For Method 3 (https://www.python.org/downloads/)

### Environment Variables Setup

Before proceeding, set up your environment variables. Open **PowerShell as Administrator** and run:

```powershell
# Set environment variables (replace with your actual values)
$env:CP_INSTANCE_ID = "cp1"
$env:TP_CLUSTER_DOMAIN = "nxp.atsnl-emea.azure.dataplanes.pro"
$env:TP_SANDBOX = "apps"
$env:CP_MY_DNS_DOMAIN = "${env:CP_INSTANCE_ID}-my.${env:TP_SANDBOX}.${env:TP_CLUSTER_DOMAIN}"
$env:CP_TUNNEL_DNS_DOMAIN = "${env:CP_INSTANCE_ID}-tunnel.${env:TP_SANDBOX}.${env:TP_CLUSTER_DOMAIN}"
$env:EMAIL_FOR_CERTBOT = "kulbhushan.bhalerao@tibco.com"
$env:TP_RESOURCE_GROUP = "kul-atsbnl-flogo-azfunc"
$env:TP_CLUSTER_NAME = "aroCluster"
$env:TP_DNS_RESOURCE_GROUP = "kul-atsbnl-flogo-azfunc"

# Verify environment variables
Write-Host "CP_INSTANCE_ID: $env:CP_INSTANCE_ID"
Write-Host "CP_MY_DNS_DOMAIN: $env:CP_MY_DNS_DOMAIN"
Write-Host "CP_TUNNEL_DNS_DOMAIN: $env:CP_TUNNEL_DNS_DOMAIN"
```

**To make these permanent** (survive PowerShell session restarts):
```powershell
[System.Environment]::SetEnvironmentVariable('CP_INSTANCE_ID', 'cp1', 'User')
[System.Environment]::SetEnvironmentVariable('TP_CLUSTER_DOMAIN', 'nxp.atsnl-emea.azure.dataplanes.pro', 'User')
# ... repeat for other variables
```

---

## Method 1: Using Docker Desktop (Recommended)

This is the **easiest and most consistent** method for Windows users.

### Step 1: Install Docker Desktop

1. Download and install Docker Desktop from: https://www.docker.com/products/docker-desktop/
2. Start Docker Desktop
3. Verify installation in PowerShell:
   ```powershell
   docker --version
   ```

### Step 2: Generate MY Domain Certificate

Open **PowerShell** and run:

```powershell
# Create scratch directory for certificates
$SCRATCH_DIR_MY = "C:\temp\$env:CP_INSTANCE_ID-my"
New-Item -ItemType Directory -Force -Path $SCRATCH_DIR_MY

# Run certbot in Docker container
docker run --rm -it `
  -v "${SCRATCH_DIR_MY}:/etc/letsencrypt" `
  -v "${SCRATCH_DIR_MY}\work:/var/lib/letsencrypt" `
  certbot/certbot certonly --manual `
  --preferred-challenges=dns `
  --email $env:EMAIL_FOR_CERTBOT `
  --server https://acme-v02.api.letsencrypt.org/directory `
  --agree-tos `
  -d "*.$env:CP_MY_DNS_DOMAIN" `
  --config-dir "/etc/letsencrypt/config" `
  --work-dir "/etc/letsencrypt/work" `
  --logs-dir "/etc/letsencrypt/logs"
```

> **Important**: Do not interrupt the command. When prompted:
> 1. Note the TXT record value shown by certbot
> 2. Open another PowerShell window (keep this one open)
> 3. Create DNS TXT record (see [DNS Record Creation](#dns-txt-record-creation-for-my-domain) below)
> 4. Wait 2-5 minutes for DNS propagation
> 5. Return to this window and press **Enter** to continue

### Step 3: Generate TUNNEL Domain Certificate

```powershell
# Create scratch directory for tunnel certificates
$SCRATCH_DIR_TUNNEL = "C:\temp\$env:CP_INSTANCE_ID-tunnel"
New-Item -ItemType Directory -Force -Path $SCRATCH_DIR_TUNNEL

# Run certbot in Docker container
docker run --rm -it `
  -v "${SCRATCH_DIR_TUNNEL}:/etc/letsencrypt" `
  -v "${SCRATCH_DIR_TUNNEL}\work:/var/lib/letsencrypt" `
  certbot/certbot certonly --manual `
  --preferred-challenges=dns `
  --email $env:EMAIL_FOR_CERTBOT `
  --server https://acme-v02.api.letsencrypt.org/directory `
  --agree-tos `
  -d "*.$env:CP_TUNNEL_DNS_DOMAIN" `
  --config-dir "/etc/letsencrypt/config" `
  --work-dir "/etc/letsencrypt/work" `
  --logs-dir "/etc/letsencrypt/logs"
```

> **Important**: Follow the same DNS TXT record creation process as above (see [DNS TXT Record Creation](#dns-txt-record-creation-for-tunnel-domain))

### Step 4: Create Kubernetes Secrets

After certificates are generated:

```powershell
# Create secret for MY domain
oc create secret tls custom-my-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="$SCRATCH_DIR_MY\config\live\$env:CP_MY_DNS_DOMAIN\fullchain.pem" `
  --key="$SCRATCH_DIR_MY\config\live\$env:CP_MY_DNS_DOMAIN\privkey.pem"

# Create secret for TUNNEL domain
oc create secret tls custom-tunnel-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="$SCRATCH_DIR_TUNNEL\config\live\$env:CP_TUNNEL_DNS_DOMAIN\fullchain.pem" `
  --key="$SCRATCH_DIR_TUNNEL\config\live\$env:CP_TUNNEL_DNS_DOMAIN\privkey.pem"
```

---

## Method 2: Using WSL2 (Windows Subsystem for Linux)

WSL2 provides a full Linux environment on Windows.

### Step 1: Enable and Install WSL2

Open **PowerShell as Administrator** and run:

```powershell
# Enable WSL
wsl --install

# Restart your computer when prompted
```

After restart, install Ubuntu:
```powershell
wsl --install -d Ubuntu-22.04
```

### Step 2: Install Certbot in WSL2

Open **Ubuntu** (WSL2) terminal:

```bash
# Update packages
sudo apt update

# Install certbot
sudo apt install -y certbot

# Verify installation
certbot --version
```

### Step 3: Set Environment Variables in WSL2

In the Ubuntu (WSL2) terminal:

```bash
# Export environment variables
export CP_INSTANCE_ID="cp1"
export TP_CLUSTER_DOMAIN="nxp.atsnl-emea.azure.dataplanes.pro"
export TP_SANDBOX="apps"
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_SANDBOX}.${TP_CLUSTER_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_SANDBOX}.${TP_CLUSTER_DOMAIN}"
export EMAIL_FOR_CERTBOT="kulbhushan.bhalerao@tibco.com"

# Verify
echo "CP_MY_DNS_DOMAIN: $CP_MY_DNS_DOMAIN"
echo "CP_TUNNEL_DNS_DOMAIN: $CP_TUNNEL_DNS_DOMAIN"
```

### Step 4: Generate Certificates in WSL2

```bash
# Generate MY domain certificate
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-my"
sudo certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL_FOR_CERTBOT} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_MY_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

> **Note**: Create DNS TXT record when prompted (see DNS section below)

```bash
# Generate TUNNEL domain certificate
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-tunnel"
sudo certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL_FOR_CERTBOT} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_TUNNEL_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

### Step 5: Copy Certificates to Windows

From WSL2, copy certificates to Windows accessible location:

```bash
# Create Windows directory (accessible from WSL)
mkdir -p /mnt/c/temp/certs-my
mkdir -p /mnt/c/temp/certs-tunnel

# Copy MY domain certificates
sudo cp /tmp/cp1-my/config/live/${CP_MY_DNS_DOMAIN}/* /mnt/c/temp/certs-my/
sudo chmod 644 /mnt/c/temp/certs-my/*

# Copy TUNNEL domain certificates
sudo cp /tmp/cp1-tunnel/config/live/${CP_TUNNEL_DNS_DOMAIN}/* /mnt/c/temp/certs-tunnel/
sudo chmod 644 /mnt/c/temp/certs-tunnel/*
```

### Step 6: Create Secrets from PowerShell

Back in **PowerShell**:

```powershell
# Create secret for MY domain
oc create secret tls custom-my-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="C:\temp\certs-my\fullchain.pem" `
  --key="C:\temp\certs-my\privkey.pem"

# Create secret for TUNNEL domain
oc create secret tls custom-tunnel-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="C:\temp\certs-tunnel\fullchain.pem" `
  --key="C:\temp\certs-tunnel\privkey.pem"
```

---

## Method 3: Using PowerShell with Certbot

Install certbot natively on Windows using Python.

### Step 1: Install Python and Certbot

1. Download and install Python from: https://www.python.org/downloads/
   - **Important**: Check "Add Python to PATH" during installation

2. Open **PowerShell as Administrator**:

```powershell
# Upgrade pip
python -m pip install --upgrade pip

# Install certbot
pip install certbot

# Verify installation
certbot --version
```

### Step 2: Generate Certificates

```powershell
# Create directories
$SCRATCH_DIR_MY = "C:\certbot\$env:CP_INSTANCE_ID-my"
New-Item -ItemType Directory -Force -Path $SCRATCH_DIR_MY

# Generate MY domain certificate
certbot certonly --manual `
  --preferred-challenges=dns `
  --email $env:EMAIL_FOR_CERTBOT `
  --server https://acme-v02.api.letsencrypt.org/directory `
  --agree-tos `
  -d "*.$env:CP_MY_DNS_DOMAIN" `
  --config-dir "$SCRATCH_DIR_MY\config" `
  --work-dir "$SCRATCH_DIR_MY\work" `
  --logs-dir "$SCRATCH_DIR_MY\logs"
```

> **Note**: Create DNS TXT record when prompted

```powershell
# Generate TUNNEL domain certificate
$SCRATCH_DIR_TUNNEL = "C:\certbot\$env:CP_INSTANCE_ID-tunnel"
New-Item -ItemType Directory -Force -Path $SCRATCH_DIR_TUNNEL

certbot certonly --manual `
  --preferred-challenges=dns `
  --email $env:EMAIL_FOR_CERTBOT `
  --server https://acme-v02.api.letsencrypt.org/directory `
  --agree-tos `
  -d "*.$env:CP_TUNNEL_DNS_DOMAIN" `
  --config-dir "$SCRATCH_DIR_TUNNEL\config" `
  --work-dir "$SCRATCH_DIR_TUNNEL\work" `
  --logs-dir "$SCRATCH_DIR_TUNNEL\logs"
```

### Step 3: Create Kubernetes Secrets

```powershell
# Create secret for MY domain
oc create secret tls custom-my-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="$SCRATCH_DIR_MY\config\live\$env:CP_MY_DNS_DOMAIN\fullchain.pem" `
  --key="$SCRATCH_DIR_MY\config\live\$env:CP_MY_DNS_DOMAIN\privkey.pem"

# Create secret for TUNNEL domain
oc create secret tls custom-tunnel-tls `
  -n "$env:CP_INSTANCE_ID-ns" `
  --cert="$SCRATCH_DIR_TUNNEL\config\live\$env:CP_TUNNEL_DNS_DOMAIN\fullchain.pem" `
  --key="$SCRATCH_DIR_TUNNEL\config\live\$env:CP_TUNNEL_DNS_DOMAIN\privkey.pem"
```

---

## DNS Record Creation (All Methods)

These DNS operations work the same across all methods using Azure CLI in PowerShell.

### DNS TXT Record Creation for MY Domain

When certbot prompts for DNS verification, open a **new PowerShell window**:

```powershell
# Login to Azure (if not already logged in)
az login

# Set subscription
az account set --subscription $env:TP_SUBSCRIPTION_ID

# Add TXT record for DNS challenge
# Replace <CHALLENGE_VALUE> with the value shown by certbot
az network dns record-set txt add-record `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX" `
  -v "<CHALLENGE_VALUE>"

# Verify TXT record was created
az network dns record-set txt show `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX"
```

**Wait 2-5 minutes** for DNS propagation, then return to certbot window and press **Enter**.

### DNS TXT Record Creation for TUNNEL Domain

```powershell
# Add TXT record for TUNNEL DNS challenge
# Replace <CHALLENGE_VALUE> with the value shown by certbot
az network dns record-set txt add-record `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-tunnel.$env:TP_SANDBOX" `
  -v "<CHALLENGE_VALUE>"

# Verify TXT record was created
az network dns record-set txt show `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-tunnel.$env:TP_SANDBOX"
```

### Create A Records for Wildcard Domains

After certificates are generated, create the wildcard A records:

```powershell
# Get ARO ingress IP
$INGRESS_IP = az aro show `
  -n $env:TP_CLUSTER_NAME `
  -g $env:TP_RESOURCE_GROUP `
  --query 'ingressProfiles[0].ip' -o tsv

Write-Host "Ingress IP: $INGRESS_IP"

# Add wildcard A record for MY domain
az network dns record-set a add-record `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "*.$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX" `
  -a $INGRESS_IP

# Add wildcard A record for TUNNEL domain
az network dns record-set a add-record `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "*.$env:CP_INSTANCE_ID-tunnel.$env:TP_SANDBOX" `
  -a $INGRESS_IP
```

### Clean Up TXT Records (Optional)

After certificate generation, you can remove the TXT challenge records:

```powershell
# Remove TXT record for MY domain
az network dns record-set txt delete `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX" `
  --yes

# Remove TXT record for TUNNEL domain
az network dns record-set txt delete `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  -n "_acme-challenge.$env:CP_INSTANCE_ID-tunnel.$env:TP_SANDBOX" `
  --yes
```

---

## DNS Verification (All Methods)

### Option 1: Using nslookup (Built-in Windows)

```powershell
# Verify MY domain
nslookup admin.$env:CP_MY_DNS_DOMAIN

# Verify TUNNEL domain
nslookup test.$env:CP_TUNNEL_DNS_DOMAIN

# Expected output should show the ARO ingress IP
```

### Option 2: Using PowerShell Resolve-DnsName

```powershell
# Verify MY domain
Resolve-DnsName -Name "admin.$env:CP_MY_DNS_DOMAIN" -Type A

# Verify TUNNEL domain
Resolve-DnsName -Name "test.$env:CP_TUNNEL_DNS_DOMAIN" -Type A
```

### Option 3: Using curl (if installed)

```powershell
# Install curl via chocolatey (if not available)
# choco install curl

# Test MY domain
curl -I --connect-timeout 5 "https://admin.$env:CP_MY_DNS_DOMAIN" 2>&1 | Select-String -Pattern "HTTP"

# Test TUNNEL domain
curl -I --connect-timeout 5 "https://test.$env:CP_TUNNEL_DNS_DOMAIN" 2>&1 | Select-String -Pattern "HTTP"
```

### Option 4: Using Azure CLI

```powershell
# List all A records to verify
az network dns record-set a list `
  -g $env:TP_DNS_RESOURCE_GROUP `
  -z $env:TP_CLUSTER_DOMAIN `
  --query "[?contains(name, '$env:CP_INSTANCE_ID')].{Name:name, IP:arecords[0].ipv4Address}" `
  -o table
```

---

## Troubleshooting

### Issue: "certbot: command not found" in PowerShell

**Solution**:
```powershell
# Verify Python is in PATH
python --version

# If Python is installed, reinstall certbot
pip uninstall certbot
pip install certbot

# Add Python Scripts to PATH manually
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311\Scripts"
```

### Issue: Docker volume mount fails on Windows

**Solution**: Ensure Docker Desktop has access to the drive:
1. Open Docker Desktop
2. Go to Settings → Resources → File Sharing
3. Add `C:\` drive
4. Restart Docker Desktop

### Issue: Certificate files have wrong permissions

**Solution** (PowerShell as Administrator):
```powershell
# Fix permissions on certificate files
$certPath = "C:\temp\certs-my"
icacls $certPath /grant "${env:USERNAME}:(OI)(CI)F" /T
```

### Issue: DNS TXT record not propagating

**Solution**:
```powershell
# Check DNS propagation status
nslookup -type=TXT "_acme-challenge.$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX.$env:TP_CLUSTER_DOMAIN"

# Or use online tools:
# https://dnschecker.org
# https://www.whatsmydns.net
```

Wait 5-10 minutes and try again.

### Issue: oc/kubectl not found in PowerShell

**Solution**:
```powershell
# Add to PATH temporarily
$env:Path += ";C:\Program Files\OpenShift"

# Or permanently (as Administrator):
[System.Environment]::SetEnvironmentVariable(
    "Path",
    [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Program Files\OpenShift",
    "Machine"
)
```

### Issue: Azure CLI commands fail with authentication error

**Solution**:
```powershell
# Clear cached credentials
az account clear

# Login again
az login

# Verify subscription
az account show
```

### Issue: Certificate renewal needed

**Solution** (Docker method):
```powershell
# Renew certificates (same command as initial generation)
docker run --rm -it `
  -v "${SCRATCH_DIR_MY}:/etc/letsencrypt" `
  certbot/certbot renew
```

---

## Quick Reference Card

### PowerShell Environment Variables Setup
```powershell
$env:CP_INSTANCE_ID = "cp1"
$env:TP_CLUSTER_DOMAIN = "nxp.atsnl-emea.azure.dataplanes.pro"
$env:TP_SANDBOX = "apps"
$env:CP_MY_DNS_DOMAIN = "$env:CP_INSTANCE_ID-my.$env:TP_SANDBOX.$env:TP_CLUSTER_DOMAIN"
$env:CP_TUNNEL_DNS_DOMAIN = "$env:CP_INSTANCE_ID-tunnel.$env:TP_SANDBOX.$env:TP_CLUSTER_DOMAIN"
$env:EMAIL_FOR_CERTBOT = "your.email@tibco.com"
$env:TP_RESOURCE_GROUP = "your-resource-group"
$env:TP_CLUSTER_NAME = "aroCluster"
$env:TP_DNS_RESOURCE_GROUP = "your-dns-resource-group"
```

### Verify Secrets Created
```powershell
oc get secrets -n "$env:CP_INSTANCE_ID-ns" | Select-String "tls"
```

### View Certificate Details
```powershell
oc describe secret custom-my-tls -n "$env:CP_INSTANCE_ID-ns"
oc describe secret custom-tunnel-tls -n "$env:CP_INSTANCE_ID-ns"
```

---

## Summary

This guide provides three methods for generating SSL certificates and configuring DNS on Windows:

1. **Docker Desktop (Recommended)**: Easiest, most consistent, no local installation needed
2. **WSL2**: Full Linux environment, good for developers familiar with Linux
3. **PowerShell Native**: Windows-native approach using Python

Choose the method that best fits your environment and preferences. All methods produce the same result: valid SSL certificates and properly configured DNS records for your TIBCO Control Plane deployment.

## Next Steps

After completing certificate and DNS setup:

1. Verify all secrets are created: `oc get secrets -n cp1-ns`
2. Proceed with TIBCO Control Plane installation (Step 8.4 in main guide)
3. Access Control Plane UI at: `https://admin.$env:CP_MY_DNS_DOMAIN`

## References

- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Azure DNS Documentation](https://docs.microsoft.com/en-us/azure/dns/)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/windows/)
- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [OpenShift CLI Tools](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
