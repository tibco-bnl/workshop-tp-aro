# TIBCO Platform 1.15.0 - DNS Configuration Quick Reference

## Quick Decision Guide

### Should I use Simplified DNS or Legacy DNS?

```
┌──────────────────────────────────────────────────────────────┐
│                    DECISION FLOWCHART                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Are you upgrading from v1.14.x or earlier? ────┐           │
│                                                   │           │
│                                    YES ─────> Use Legacy DNS  │
│                                     │                         │
│                                    NO                         │
│                                     │                         │
│                                     ↓                         │
│  Do you need multiple CP instances in same cluster? ──┐     │
│                                                        │      │
│                                    YES ─────> Use Legacy DNS  │
│                                     │                         │
│                                    NO                         │
│                                     │                         │
│                                     ↓                         │
│  Do you need hybrid connectivity? ─────────────┐             │
│                                                 │             │
│                           YES ─────> Simplified DNS (Option 1)│
│                            │         with tunnel enabled      │
│                           NO                                  │
│                            │                                  │
│                            ↓                                  │
│                   Use Simplified DNS (Option 1)               │
│               Save resources - no hybrid-proxy needed         │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Comparison Table

| Feature | Simplified DNS (Option 1) | Legacy DNS (Option 2) |
|---------|---------------------------|------------------------|
| **Recommended For** | New 1.15.0 deployments | Upgrades from v1.14.x |
| **Admin URL** | `admin.example.com` | `admin.cp1-my.apps.example.com` |
| **Subscription URL** | `dev.example.com` | `dev.cp1-my.apps.example.com` |
| **Tunnel URL** | `tunnel.example.com` (optional) | `dev.cp1-tunnel.apps.example.com` |
| **Certificates** | 1 wildcard cert | 2 separate wildcard certs |
| **DNS Records** | Simple A records or 1 wildcard | 2 wildcard records |
| **Hybrid-Proxy** | Optional (disable to save resources) | Typically enabled |
| **Resource Usage** | Lower (no hybrid-proxy if disabled) | Higher (hybrid-proxy always running) |
| **DNS Management** | Simpler | More complex |
| **Corporate PKI** | Easier integration | More certificates to manage |

## Environment Variables Quick Reference

### Simplified DNS (Option 1)
```bash
# DNS Configuration
export TP_BASE_DNS_DOMAIN="apps.example.com"
export CP_ADMIN_HOST_PREFIX="admin"
export CP_SUBSCRIPTION="dev"
export CP_HYBRID_CONNECTIVITY="false"  # or "true" if needed

# Resulting URLs:
# Admin: https://admin.apps.example.com
# Subscription: https://dev.apps.example.com
# Tunnel (if enabled): https://tunnel.apps.example.com
```

### Legacy DNS (Option 2)
```bash
# DNS Configuration
export CP_INSTANCE_ID="cp1"
export TP_DOMAIN="apps.example.com"
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}"
export CP_HYBRID_CONNECTIVITY="true"

# Resulting URLs:
# Admin: https://admin.cp1-my.apps.example.com
# Subscription: https://dev.cp1-my.apps.example.com
# Tunnel: https://dev.cp1-tunnel.apps.example.com
```

## Certificate Generation Command Reference

### Simplified DNS (Option 1)
```bash
# Single wildcard certificate
certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL_FOR_CERTBOT} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${TP_BASE_DNS_DOMAIN}" \
  --config-dir "/tmp/cp-cert/config" \
  --work-dir "/tmp/cp-cert/work" \
  --logs-dir "/tmp/cp-cert/logs"
```

### Legacy DNS (Option 2)
```bash
# MY domain certificate
certbot certonly --manual \
  --preferred-challenges=dns \
  -d "*.${CP_MY_DNS_DOMAIN}" \
  # ... (see full guide for complete command)

# TUNNEL domain certificate (if needed)
certbot certonly --manual \
  --preferred-challenges=dns \
  -d "*.${CP_TUNNEL_DNS_DOMAIN}" \
  # ... (see full guide for complete command)
```

## Helm Values Key Differences

### Simplified DNS (Option 1)

**Router-Operator Ingress:**
```yaml
router-operator:
  ingress:
    tls:
      - secretName: cp-base-tls-cert  # Single certificate
        hosts:
          - '${CP_ADMIN_HOST_PREFIX}.${TP_BASE_DNS_DOMAIN}'
          - '${CP_SUBSCRIPTION}.${TP_BASE_DNS_DOMAIN}'
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

**Hybrid-Proxy (Optional):**
```yaml
hybrid-proxy:
  enabled: false  # Set to false to disable and save resources
```

**Global Configuration:**
```yaml
global:
  tibco:
    adminHostPrefix: ${CP_ADMIN_HOST_PREFIX}
    hybridConnectivity:
      enabled: false  # Matches hybrid-proxy.enabled
  external:
    dnsDomain: ${TP_BASE_DNS_DOMAIN}
    dnsTunnelDomain: ${TP_BASE_DNS_DOMAIN}  # Same domain
```

### Legacy DNS (Option 2)

**Router-Operator Ingress:**
```yaml
router-operator:
  ingress:
    tls:
      - secretName: ${CP_MY_TLS_SECRET_NAME}  # Separate certificate
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'  # Wildcard host
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

**Hybrid-Proxy (Typically Enabled):**
```yaml
hybrid-proxy:
  enabled: true
  ingress:
    enabled: true
    tls:
      - secretName: ${CP_TUNNEL_TLS_SECRET_NAME}
        hosts:
          - '*.${CP_TUNNEL_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_TUNNEL_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 105
```

**Global Configuration:**
```yaml
global:
  tibco:
    hybridConnectivity:
      enabled: true
  external:
    dnsDomain: ${CP_MY_DNS_DOMAIN}
    dnsTunnelDomain: ${CP_TUNNEL_DNS_DOMAIN}  # Different domain
```

## When to Enable Hybrid Connectivity

### Enable (`CP_HYBRID_CONNECTIVITY="true"`)
✅ Connecting Data Planes across different clouds (AWS, Azure, GCP)  
✅ Managing Data Planes in on-premises environments  
✅ Using TIBCO Cloud Control Plane with local Data Planes  
✅ Need secure tunneling between Control Plane and remote Data Planes  
✅ Data Planes behind corporate firewalls  

### Disable (`CP_HYBRID_CONNECTIVITY="false"`) 
✅ All components deployed in same Kubernetes cluster  
✅ All Data Planes in same cloud provider network  
✅ Workshop/evaluation environments  
✅ Simplified standalone Control Plane deployments  
✅ Want to save resources (no hybrid-proxy pods)  

## Resource Savings with Simplified DNS

### Simplified DNS + Hybrid Connectivity Disabled
- **Pods Saved:** 2-3 hybrid-proxy pods (depending on replica count)
- **CPU Saved:** ~200-300m CPU requests
- **Memory Saved:** ~256-384Mi memory requests
- **Certificates:** 1 certificate vs 2
- **DNS Records:** Simpler management

### Example Resource Comparison
```
Legacy DNS (with hybrid-proxy):
├── hybrid-proxy pods: 3 replicas × 100m CPU × 128Mi RAM
├── router-operator pods: 3 replicas × 100m CPU × 128Mi RAM
└── Total: 600m CPU, 768Mi RAM

Simplified DNS (without hybrid-proxy):
├── router-operator pods: 3 replicas × 100m CPU × 128Mi RAM
└── Total: 300m CPU, 384Mi RAM
    ↓
    SAVINGS: 50% CPU, 50% RAM
```

## Migration Path (Legacy → Simplified)

If you're currently using legacy DNS and want to migrate:

### Option A: During DNS Renewal
1. Generate new certificate for `*.${TP_BASE_DNS_DOMAIN}`
2. Create new DNS records (admin, subscription, tunnel)
3. Update helm values to use simplified structure
4. Upgrade Control Plane with new values
5. Remove old DNS records after validation

### Option B: Side-by-Side (Zero Downtime)
1. Keep existing certificates and DNS
2. Add new simplified DNS records alongside old ones
3. Generate new certificate for simplified structure
4. Update helm values to include both old and new hosts
5. Validate new URLs work
6. Gradually remove old DNS/certificates

### Both Structures Simultaneously (Transition)
```yaml
router-operator:
  ingress:
    hosts:
      # New simplified structure
      - host: "admin.${TP_BASE_DNS_DOMAIN}"
        paths:
          - path: /
            pathType: Prefix
            port: 100
      # Old legacy structure (backward compatibility)
      - host: "*.${CP_MY_DNS_DOMAIN}"
        paths:
          - path: /
            pathType: Prefix
            port: 100
```

## Troubleshooting Common Issues

### Issue: "Certificate doesn't match domain"
**Solution:** Ensure your certificate SAN matches the host entries in ingress

**Simplified DNS:**
```bash
# Certificate should cover:
*.apps.example.com  # Covers admin.apps.example.com, dev.apps.example.com, etc.
```

**Legacy DNS:**
```bash
# MY certificate should cover:
*.cp1-my.apps.example.com

# TUNNEL certificate should cover:
*.cp1-tunnel.apps.example.com
```

### Issue: "Hybrid-proxy pods not starting"
**Solution:** Hybrid-proxy is optional in v1.15.0. If not needed:
```yaml
hybrid-proxy:
  enabled: false

global:
  tibco:
    hybridConnectivity:
      enabled: false
```

### Issue: "DNS not resolving"
**Simplified DNS - Verify:**
```bash
dig +short admin.${TP_BASE_DNS_DOMAIN}
dig +short dev.${TP_BASE_DNS_DOMAIN}
```

**Legacy DNS - Verify:**
```bash
dig +short admin.${CP_MY_DNS_DOMAIN}
dig +short admin.${CP_TUNNEL_DNS_DOMAIN}
```

## Quick Start Commands

### Simplified DNS Setup (Complete Flow)
```bash
# 1. Choose variables
export TP_BASE_DNS_DOMAIN="apps.example.com"
export CP_ADMIN_HOST_PREFIX="admin"
export CP_SUBSCRIPTION="dev"
export CP_HYBRID_CONNECTIVITY="false"

# 2. Generate certificate
certbot certonly --manual -d "*.${TP_BASE_DNS_DOMAIN}" ...

# 3. Create secret
oc create secret tls cp-base-tls-cert -n ${CP_INSTANCE_ID}-ns ...

# 4. Create DNS records
az network dns record-set a add-record ... -n "admin.apps" ...
az network dns record-set a add-record ... -n "dev.apps" ...

# 5. Install Control Plane
helm upgrade --install ... -f simplified-values.yaml
```

### Legacy DNS Setup (Complete Flow)
```bash
# 1. Choose variables
export CP_INSTANCE_ID="cp1"
export CP_MY_DNS_DOMAIN="cp1-my.apps.example.com"
export CP_TUNNEL_DNS_DOMAIN="cp1-tunnel.apps.example.com"
export CP_HYBRID_CONNECTIVITY="true"

# 2. Generate certificates
certbot certonly --manual -d "*.${CP_MY_DNS_DOMAIN}" ...
certbot certonly --manual -d "*.${CP_TUNNEL_DNS_DOMAIN}" ...

# 3. Create secrets
oc create secret tls custom-my-tls -n ${CP_INSTANCE_ID}-ns ...
oc create secret tls custom-tunnel-tls -n ${CP_INSTANCE_ID}-ns ...

# 4. Create wildcard DNS records
az network dns record-set a add-record ... -n "*.cp1-my.apps" ...
az network dns record-set a add-record ... -n "*.cp1-tunnel.apps" ...

# 5. Install Control Plane
helm upgrade --install ... -f legacy-values.yaml
```

## Additional Resources

- **Full Guide:** See Step 8.2 and 8.4 in the main ARO v1.15.0 documentation
- **Changes Document:** `CHANGES-1.15.0-DNS-SIMPLIFICATION.md`
- **Official TIBCO Docs:** [Platform CP Installation Guide](https://docs.tibco.com/pub/platform-cp/latest/)
- **Helm Charts:** [tp-helm-charts v1.15.0](https://github.com/TIBCOSoftware/tp-helm-charts)

---

**Document Version:** 1.0  
**Last Updated:** March 17, 2026  
**Applies To:** TIBCO Platform Control Plane 1.15.0+
