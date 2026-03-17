# TIBCO Platform 1.15.0 DNS and Architecture Simplification

## Overview
This document outlines the key architectural changes in TIBCO Platform 1.15.0 that simplify DNS configuration and make hybrid connectivity optional.

## Key Changes from Previous Versions

### 1. Simplified DNS Structure
**Before (1.14.x and earlier):**
- Multi-level subdomain structure: `admin.cp1-my.apps.example.com`
- Separate MY domain: `cp1-my.apps.example.com`
- Separate TUNNEL domain: `cp1-tunnel.apps.example.com`
- Requires wildcard certificates for both domains

**After (1.15.0):**
- Single-level subdomain structure: `admin.example.com`
- Direct usage of base domain with prefixes
- Tunnel domain is **OPTIONAL** (only needed if hybrid connectivity enabled)
- Simplified certificate management

### 2. Hybrid Connectivity Now Optional
**Before:**
- `hybrid-proxy` component was always required
- Tunnel domain and certificates were mandatory
- Separate ingress configuration for tunnel traffic

**After:**
- `hybrid-proxy` component is optional (only needed for hybrid cloud scenarios)
- Tunnel domain only required if `global.tibco.hybridConnectivity.enabled: true`
- Simplified deployment for standalone Control Planes

### 3. Environment Variables Simplification

**Old Structure:**
```bash
export CP_INSTANCE_ID="cp1"
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}"
```

**New Structure (1.15.0):**
```bash
export CP_INSTANCE_ID="cp1"
export TP_BASE_DNS_DOMAIN="example.com"
export CP_ADMIN_HOST_PREFIX="admin"
export CP_SUBSCRIPTION="dev"
export CP_HYBRID_CONNECTIVITY="true"  # Set to "false" if tunnel not needed
```

### 4. Router-Operator Ingress Configuration

**Old Configuration:**
```yaml
router-operator:
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    tls:
      - secretName: ${CP_MY_TLS_SECRET_NAME}
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

**New Configuration (1.15.0):**
```yaml
router-operator:
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    hosts:
      - host: "${CP_SUBSCRIPTION}.${TP_BASE_DNS_DOMAIN}"
        paths:
          - path: /
            pathType: Prefix
            port: 100
      - host: "${CP_ADMIN_HOST_PREFIX}.${TP_BASE_DNS_DOMAIN}"
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

### 5. DNS Record Creation

**Before:**
```bash
# Multiple wildcard entries needed
*.cp1-my.apps.example.com -> INGRESS_IP
*.cp1-tunnel.apps.example.com -> INGRESS_IP
```

**After (1.15.0):**
```bash
# Simple A records or single wildcard
admin.example.com -> INGRESS_IP
dev.example.com -> INGRESS_IP
# OR use wildcard: *.example.com -> INGRESS_IP
```

### 6. Certificate Generation

**Before:**
```bash
# Two separate certificate generation commands
certbot certonly --manual -d "*.${CP_MY_DNS_DOMAIN}"
certbot certonly --manual -d "*.${CP_TUNNEL_DNS_DOMAIN}"
```

**After (1.15.0):**
```bash
# Single certificate for base domain
certbot certonly --manual -d "*.${TP_BASE_DNS_DOMAIN}"
# OR specific certificates for each subdomain
certbot certonly --manual -d "admin.${TP_BASE_DNS_DOMAIN}" -d "${CP_SUBSCRIPTION}.${TP_BASE_DNS_DOMAIN}"
```

## Migration Guide

### For New Deployments (1.15.0)
1. Use simplified DNS variables (see "New Structure" above)
2. Set `CP_HYBRID_CONNECTIVITY="false"` if you don't need hybrid connectivity
3. Generate a single wildcard certificate for `*.${TP_BASE_DNS_DOMAIN}`
4. Create simple DNS A records for required subdomains
5. Use the new router-operator ingress configuration

### For Existing Deployments (Upgrading to 1.15.0)
1. You can continue using the old DNS structure (backward compatible)
2. Consider migrating to simplified DNS structure during next DNS renewal
3. Hybrid-proxy will continue to work if already deployed
4. New deployments should use simplified structure

## When to Use Hybrid Connectivity

**Enable hybrid-proxy/tunnel when:**
- Connecting Data Planes across different clouds (AWS, Azure, GCP)
- Managing Data Planes in on-premises environments
- Using TIBCO Cloud Control Plane with on-premises Data Planes
- Need secure tunneling between Control Plane and remote Data Planes

**Disable hybrid-proxy/tunnel when:**
- All components deployed in same Kubernetes cluster
- All Data Planes in same cloud provider network
- Workshop/evaluation environments
- Simplified standalone Control Plane deployments

## Prerequisites Updates

### Prerequisites for 1.15.0:
```markdown
1. Access to TIBCO Control Plane SaaS (if using cloud integration)
2. Access to a PostgreSQL 16.x Database
3. Access to a SMTP enabled Email Server (OPTIONAL starting 1.10.0)
4. Identify and register DNS names for Control Plane Router/UI
   - **NEW in 1.15.0:** DNS/Ingress for Control Plane Tunnel is **OPTIONAL**
5. Acquire certificates to secure Control Plane Services
   - Certificate CN and/or SAN must match CP Router/UI
   - Tunnel DNS Names only needed if hybrid connectivity enabled
```

## Benefits of Simplified Structure

### 1. Easier DNS Management
- Fewer DNS records to create and manage
- Standard single-level subdomain structure
- Easier to integrate with corporate DNS policies

### 2. Simplified Certificate Management
- Single wildcard certificate covers all Control Plane services
- Reduces certificate renewal overhead
- Easier to use public CA certificates

### 3. Reduced Deployment Complexity
- Fewer configuration variables
- Clearer separation between required and optional components
- Faster deployment for standalone scenarios

### 4. Better Resource Utilization
- Hybrid-proxy pods not needed for standalone deployments
- Reduced memory and CPU footprint
- Lower cost for workshop and evaluation environments

## Configuration Examples

### Example 1: Standalone Control Plane (No Hybrid Connectivity)
```yaml
global:
  tibco:
    hybridConnectivity:
      enabled: false  # Disables hybrid-proxy completely

router-operator:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - host: "admin.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

### Example 2: Control Plane with Hybrid Connectivity
```yaml
global:
  tibco:
    hybridConnectivity:
      enabled: true  # Enables hybrid-proxy for remote Data Planes

hybrid-proxy:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - host: "tunnel.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 105

router-operator:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - host: "admin.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 100
      - host: "dev.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

## Reference

- **AKS 1.15.0 Guide:** Based on official TIBCO Platform 1.15.0 deployment on AKS
- **TIBCO Documentation:** [Platform CP Installation Guide](https://docs.tibco.com/pub/platform-cp/latest/)
- **Helm Charts:** [tp-helm-charts v1.15.0](https://github.com/TIBCOSoftware/tp-helm-charts)

## Backward Compatibility

The old DNS structure (`cp1-my.apps.example.com`) is still supported in 1.15.0 for backward compatibility. However, new deployments should use the simplified structure for better maintainability.

### Using Both Structures (Transition Period)
```yaml
router-operator:
  ingress:
    hosts:
      # New simplified structure
      - host: "admin.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 100
      # Old structure (for backward compatibility)
      - host: "*.cp1-my.apps.example.com"
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

---

**Document Version:** 1.0  
**Last Updated:** March 17, 2026  
**Applies To:** TIBCO Platform Control Plane 1.15.0+
