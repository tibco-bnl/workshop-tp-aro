# How to Add DNS Records for Azure Red Hat OpenShift (ARO) Routes

This guide provides step-by-step instructions for creating DNS records in Azure DNS zones for OpenShift routes, specifically for TIBCO Platform deployments on ARO clusters.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Method 1: Using Azure CLI (Recommended)](#method-1-using-azure-cli-recommended)
- [Method 2: Using Azure Portal](#method-2-using-azure-portal)
- [Method 3: Using External DNS (Automated)](#method-3-using-external-dns-automated)
- [Verification and Testing](#verification-and-testing)
- [Troubleshooting](#troubleshooting)
- [Common DNS Records for TIBCO Platform](#common-dns-records-for-tibco-platform)

---

## Overview

When deploying TIBCO Platform on Azure Red Hat OpenShift (ARO), you need to create DNS records that point to the ARO cluster's router to make your services accessible via custom domain names. This document covers different methods to create these DNS records, with a focus on the **wildcard DNS approach** that simplifies TIBCO Platform deployments.

**Key Concepts:**
- **ARO Router**: The OpenShift router that handles ingress traffic to your cluster
- **Route/Ingress**: OpenShift's ingress mechanism that exposes services externally
- **DNS Zone**: Azure DNS service that hosts your domain records
- **A Record**: DNS record type that maps a hostname to an IP address
- **Wildcard DNS**: DNS records using `*` that match any subdomain (e.g., `*.cp1-my.apps.example.com`)

**TIBCO Platform DNS Strategy:**
- **Control Plane**: Uses wildcard domains for flexible subdomain management
- **Admin Interface**: Accessible via `admin.${CP_MY_DNS_DOMAIN}`
- **Subscription Domains**: Dynamic subdomains like `<subscription-name>.${CP_MY_DNS_DOMAIN}`
- **Tunnel Services**: Hybrid connectivity via `*.${CP_TUNNEL_DNS_DOMAIN}`

---

## Prerequisites

Before you begin, ensure you have:

1. **Azure CLI installed and configured**
2. **Access to Azure DNS zone** with appropriate permissions
3. **ARO cluster deployed** with routes configured
4. **Required environment variables** from your deployment

### Required Environment Variables

```bash
# Set these variables according to your deployment
export TP_DNS_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"           # Resource group containing DNS zone
export TP_CLUSTER_DOMAIN="nxp.atsnl-emea.azure.dataplanes.pro"  # Your DNS zone name
export TP_CLUSTER_NAME="aroCluster"                              # ARO cluster name
export TP_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"              # ARO cluster resource group

# TIBCO Platform specific variables
export CP_INSTANCE_ID="cp1"                                      # Control Plane instance ID
export TP_DOMAIN="apps.${TP_CLUSTER_DOMAIN}"                    # Base domain for applications
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_DOMAIN}"     # Control Plane UI domain
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}" # Control Plane tunnel domain
```

> **Note**: You can source the complete environment variables from the main ARO guide:
> ```bash
> source /path/to/aro-environment-variables.sh
> ```

---

## Method 1: Using Azure CLI (Recommended)

### Step 1: Get the ARO Router IP Address

The ARO cluster provides a dedicated ingress IP address that you can get directly from Azure:

```bash
# Get ARO ingress IP address (recommended method)
INGRESS_IP="$(az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv)"
echo "ARO Ingress IP: $INGRESS_IP"

# Alternative: Get router hostname and resolve IP
ROUTER_HOSTNAME=$(oc get route -A -o jsonpath='{.items[0].status.ingress[0].routerCanonicalHostname}')
echo "Router hostname: $ROUTER_HOSTNAME"

# Resolve the IP address (if using alternative method)
ROUTER_IP=$(nslookup $ROUTER_HOSTNAME | grep "Address:" | tail -1 | awk '{print $2}')
echo "Router IP: $ROUTER_IP"

# For the rest of this guide, we'll use INGRESS_IP
export ROUTER_IP="$INGRESS_IP"
```

### Step 2: Create DNS Records

For a specific service (e.g., mail server):

```bash
# Create A record for mail server
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name mail \
    --ipv4-address ${ROUTER_IP}
```

For wildcard records (recommended for TIBCO Platform):

```bash
# Create wildcard A record for Control Plane UI (covers admin and subscription domains)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-my.apps" \
    --ipv4-address ${ROUTER_IP}

# Create wildcard A record for Control Plane tunnel
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-tunnel.apps" \
    --ipv4-address ${ROUTER_IP}
```

**Why wildcard DNS is recommended for TIBCO Platform:**
- **Admin Interface**: Automatically covers `admin.${CP_MY_DNS_DOMAIN}`
- **Subscription Domains**: Supports dynamic subscription domains like `<subscription-name>.${CP_MY_DNS_DOMAIN}`
- **Tunnel Services**: Handles various tunnel endpoints under `*.${CP_TUNNEL_DNS_DOMAIN}`
- **Simplified Management**: No need to create individual records for each subdomain
- **Future-Proof**: Automatically supports new subdomains without DNS changes

### Step 3: Verify DNS Records

```bash
# List all A records in the DNS zone
az network dns record-set a list \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --output table

# Check specific record
az network dns record-set a show \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name mail
```

---

## Method 2: Using Azure Portal

### Step 1: Navigate to DNS Zone

1. **Open Azure Portal**: Go to [portal.azure.com](https://portal.azure.com)
2. **Search for DNS zones**: Use the search bar at the top
3. **Select your DNS zone**: Click on your domain (e.g., `example.com`)
4. **Verify resource group**: Ensure it's in the correct resource group

### Step 2: Get Router IP Address

From your terminal or Azure Cloud Shell:

```bash
# Get ARO ingress IP (recommended method)
az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv

# Alternative: Get router IP via hostname resolution
oc get route -A -o jsonpath='{.items[0].status.ingress[0].routerCanonicalHostname}' | xargs nslookup | grep "Address:" | tail -1 | awk '{print $2}'
```

### Step 3: Add DNS Record

1. **Click "+ Record set"** in the DNS zone overview
2. **Configure the record**:
   - **Name**: Enter the subdomain or wildcard pattern:
     - For specific service: `mail` (creates `mail.example.com`)
     - For Control Plane UI: `*.cp1-my.apps` (creates wildcard for all CP UI services)
     - For Control Plane tunnel: `*.cp1-tunnel.apps` (creates wildcard for tunnel services)
   - **Type**: Select `A`
   - **Alias record set**: Select `No`
   - **TTL**: Enter `300` (5 minutes)
   - **TTL unit**: Select `Seconds`
   - **IP address**: Enter the router IP address from Step 2
3. **Click "OK"** to create the record

**Example for TIBCO Platform wildcard records:**
- **Name**: `*.cp1-my.apps` → Creates: `*.cp1-my.apps.example.com`
- **Name**: `*.cp1-tunnel.apps` → Creates: `*.cp1-tunnel.apps.example.com`

### Step 4: Verify in Portal

- **Check record list**: The new record should appear in the DNS zone overview
- **Note TTL**: Records typically take 5-15 minutes to propagate

---

## Method 3: Using External DNS (Automated)

If you have External DNS installed (see main ARO guide), you can automate DNS record creation.

### Step 1: Annotate Routes

Add External DNS annotations to your OpenShift routes:

```bash
# For mail server route
oc annotate route maildev-route -n tibco-ext \
    external-dns.alpha.kubernetes.io/hostname=mail.${TP_CLUSTER_DOMAIN} \
    --overwrite

# For other routes, replace 'route-name' and 'namespace'
oc annotate route <route-name> -n <namespace> \
    external-dns.alpha.kubernetes.io/hostname=<desired-hostname> \
    --overwrite
```

### Step 2: Verify External DNS

```bash
# Check External DNS logs
oc logs -n external-dns-system deployment/external-dns

# Look for DNS record creation messages
oc logs -n external-dns-system deployment/external-dns | grep -i "record\|dns"
```

### Step 3: Monitor Record Creation

External DNS typically creates records within 1-5 minutes:

```bash
# Watch for new DNS records
az network dns record-set a list \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --query "[?name=='mail']"
```

---

## Verification and Testing

### DNS Resolution Testing

```bash
# Test specific service DNS resolution
nslookup mail.${TP_CLUSTER_DOMAIN}

# Test TIBCO Platform Control Plane domains
nslookup admin.${CP_MY_DNS_DOMAIN}
nslookup test.${CP_TUNNEL_DNS_DOMAIN}

# Test with different DNS servers
nslookup admin.${CP_MY_DNS_DOMAIN} 8.8.8.8
nslookup admin.${CP_MY_DNS_DOMAIN} 1.1.1.1

# Test DNS propagation with dig (install bind-tools if needed)
dig admin.${CP_MY_DNS_DOMAIN}
dig test.${CP_TUNNEL_DNS_DOMAIN}

# Alternative if dig is not available
nslookup admin.${CP_MY_DNS_DOMAIN}
nslookup test.${CP_TUNNEL_DNS_DOMAIN}
```

### TIBCO Platform Specific Testing

```bash
# Test Control Plane admin interface
nslookup admin.${CP_MY_DNS_DOMAIN}
curl -I --connect-timeout 5 https://admin.${CP_MY_DNS_DOMAIN} 2>/dev/null | head -1

# Test subscription domain (example: bnl subscription)
nslookup bnl.${CP_MY_DNS_DOMAIN}
curl -I --connect-timeout 5 https://bnl.${CP_MY_DNS_DOMAIN} 2>/dev/null | head -1

# Test tunnel connectivity domain
nslookup test.${CP_TUNNEL_DNS_DOMAIN}
```

### HTTP/HTTPS Testing

```bash
# Test email server connectivity
curl -I http://mail.${TP_CLUSTER_DOMAIN}
curl -I https://mail.${TP_CLUSTER_DOMAIN}

# Test TIBCO Platform Control Plane connectivity
curl -I https://admin.${CP_MY_DNS_DOMAIN}
curl -I https://test.${CP_TUNNEL_DNS_DOMAIN}

# Test with verbose output for troubleshooting
curl -v https://admin.${CP_MY_DNS_DOMAIN}

# Test subscription domain connectivity (example)
curl -I https://bnl.${CP_MY_DNS_DOMAIN}
```

### Browser Testing

1. **Email Server**: Navigate to `https://mail.${TP_CLUSTER_DOMAIN}` (MailDev interface)
2. **Control Plane Admin**: Navigate to `https://admin.${CP_MY_DNS_DOMAIN}` (TIBCO Platform console)
3. **Subscription Domain**: Navigate to `https://<subscription-name>.${CP_MY_DNS_DOMAIN}` (if subscriptions are created)
4. **Check certificate**: Verify SSL certificate is valid (should match wildcard certificate)
5. **Test functionality**: Ensure applications load and work as expected

**Expected URLs for TIBCO Platform:**
- **Email Interface**: `https://mail.nxp.atsnl-emea.azure.dataplanes.pro`
- **Control Plane Admin**: `https://admin.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro`
- **Subscription Example**: `https://bnl.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro`

---

## Troubleshooting

### Common Issues and Solutions

#### DNS Not Resolving

**Problem**: `nslookup` returns "can't find" or "NXDOMAIN"

**Solutions**:
```bash
# Check if record exists in Azure
az network dns record-set a show \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name mail

# Check wildcard records for TIBCO Platform
az network dns record-set a show \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name "*.${CP_INSTANCE_ID}-my.apps"

# Wait for DNS propagation (5-15 minutes)
# Clear local DNS cache
sudo dscacheutil -flushcache  # macOS
sudo systemctl restart systemd-resolved  # Ubuntu

# Test with different DNS servers
nslookup admin.${CP_MY_DNS_DOMAIN} 8.8.8.8
nslookup mail.${TP_CLUSTER_DOMAIN} 8.8.8.8
```

#### Wrong IP Address

**Problem**: DNS resolves to incorrect IP

**Solutions**:
```bash
# Get current ARO ingress IP
CURRENT_INGRESS_IP="$(az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv)"
echo "Current ARO Ingress IP: $CURRENT_INGRESS_IP"

# Alternative: Verify router IP via hostname resolution
oc get route -A -o jsonpath='{.items[0].status.ingress[0].routerCanonicalHostname}' | xargs nslookup

# Update DNS record with correct IP
az network dns record-set a update \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name mail \
    --set aRecords[0].ipv4Address=${CURRENT_INGRESS_IP}

# Update wildcard records if needed
az network dns record-set a update \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name "*.${CP_INSTANCE_ID}-my.apps" \
    --set aRecords[0].ipv4Address=${CURRENT_INGRESS_IP}
```

#### Certificate Issues

**Problem**: SSL certificate errors in browser

**Solutions**:
```bash
# Check route TLS configuration
oc get route maildev-route -n tibco-ext -o yaml

# Verify certificate in route
oc describe route maildev-route -n tibco-ext

# Check if cert-manager is working (if using automated certs)
oc get certificates -A
```

#### External DNS Not Working

**Problem**: External DNS not creating records

**Solutions**:
```bash
# Check External DNS pod status
oc get pods -n external-dns-system

# Check External DNS logs for errors
oc logs -n external-dns-system deployment/external-dns

# Verify Azure permissions
az role assignment list --assignee <service-principal-id> --scope <dns-zone-scope>

# Check External DNS configuration
oc get deployment external-dns -n external-dns-system -o yaml
```

---

## Common DNS Records for TIBCO Platform

### Control Plane Records (Recommended: Wildcard Approach)

```bash
# Get ARO ingress IP
INGRESS_IP="$(az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv)"

# Control Plane UI (wildcard - covers admin and all subscription domains)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-my.apps" \
    --ipv4-address ${INGRESS_IP}

# Control Plane Tunnel (wildcard - covers all tunnel services)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-tunnel.apps" \
    --ipv4-address ${INGRESS_IP}
```

**What these wildcard records cover:**
- `*.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro` covers:
  - `admin.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro` (Admin interface)
  - `bnl.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro` (Subscription domain)
  - `<any-subdomain>.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro`
- `*.cp1-tunnel.apps.nxp.atsnl-emea.azure.dataplanes.pro` covers all tunnel endpoints

### Data Plane Records

```bash
# Data Plane capabilities (examples)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "bwce.apps" \
    --ipv4-address ${ROUTER_IP}

az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "flogo.apps" \
    --ipv4-address ${ROUTER_IP}
```

### Email Server Record

```bash
# Mail server (MailDev for TIBCO Platform email testing)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "mail" \
    --ipv4-address ${INGRESS_IP}
```

**Purpose**: 
- Provides web interface for viewing emails sent by TIBCO Platform
- Used for admin user activation and platform notifications
- Accessible at: `https://mail.nxp.atsnl-emea.azure.dataplanes.pro`

### Monitoring and Observability Records

```bash
# Prometheus (if using external access)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "prometheus" \
    --ipv4-address ${ROUTER_IP}

# Grafana (if using external access)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "grafana" \
    --ipv4-address ${ROUTER_IP}
```

---

## TIBCO Platform DNS Best Practices

### Recommended DNS Strategy

For TIBCO Platform deployments, use the **wildcard DNS approach** for simplified management:

#### 1. Wildcard Records Only
```bash
# Instead of creating individual records for each service:
# admin.cp1-my.apps.example.com
# bnl.cp1-my.apps.example.com  
# subscription1.cp1-my.apps.example.com

# Create ONE wildcard record that covers all:
*.cp1-my.apps.example.com → ARO_INGRESS_IP
```

#### 2. Certificate and DNS Alignment
- **Wildcard DNS**: `*.cp1-my.apps.example.com`
- **Wildcard Certificate**: `*.cp1-my.apps.example.com`
- **Ingress Configuration**: Uses wildcard host in router-operator

#### 3. Simplified Management
```bash
# Single command creates DNS for ALL Control Plane services
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-my.apps" \
    --ipv4-address ${INGRESS_IP}
```

#### 4. What Gets Covered Automatically
- ✅ `admin.cp1-my.apps.example.com` (Control Plane admin)
- ✅ `subscription1.cp1-my.apps.example.com` (Subscription domains)
- ✅ `subscription2.cp1-my.apps.example.com` (Additional subscriptions)
- ✅ `any-new-service.cp1-my.apps.example.com` (Future services)

### Migration from Individual Records

If you previously created individual DNS records, you can consolidate:

```bash
# Remove individual records (optional)
az network dns record-set a delete \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --name "admin.cp1-my.apps" \
    --yes

# Create wildcard record (covers all subdomains)
az network dns record-set a add-record \
    --resource-group ${TP_DNS_RESOURCE_GROUP} \
    --zone-name ${TP_CLUSTER_DOMAIN} \
    --record-set-name "*.${CP_INSTANCE_ID}-my.apps" \
    --ipv4-address ${INGRESS_IP}
```

---

## Best Practices

### Security Considerations

1. **Principle of Least Privilege**: Grant minimal DNS permissions required
2. **TTL Settings**: Use appropriate TTL values (300-3600 seconds)
3. **Wildcard Usage**: Use wildcards judiciously for security
4. **SSL/TLS**: Always use HTTPS for production services

### Operational Considerations

1. **Documentation**: Document all DNS records and their purposes
2. **Monitoring**: Monitor DNS resolution and certificate expiration
3. **Backup**: Consider DNS record backup strategies
4. **Change Management**: Use version control for DNS changes

### Performance Considerations

1. **TTL Optimization**: Balance between propagation speed and cache efficiency
2. **Geographic Distribution**: Consider Azure Traffic Manager for global applications
3. **Health Checks**: Implement health checks for critical services

---

## References

### TIBCO Platform Specific
- [TIBCO Platform ARO Setup Guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide.md) - Complete ARO deployment guide
- [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm) - Official platform documentation
- [TIBCO Platform Administration - Signing to Platform Console](https://docs.tibco.com/pub/platform-cp/1.10.0/doc/html/Administration/signing-to-platform-console.htm)

### Azure and OpenShift
- [Azure DNS Documentation](https://docs.microsoft.com/en-us/azure/dns/) - Azure DNS service documentation
- [Azure Red Hat OpenShift Documentation](https://docs.microsoft.com/en-us/azure/openshift/) - ARO specific documentation
- [OpenShift Routes Documentation](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html) - OpenShift ingress documentation

### Tools and Automation
- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns) - Automated DNS management
- [cert-manager Documentation](https://cert-manager.io/docs/) - Certificate automation

---

> **Note**: This document assumes you're working with Azure DNS zones and ARO clusters. Adjust commands and procedures according to your specific environment and DNS provider.