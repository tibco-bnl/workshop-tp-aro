# Firewall Requirements for TIBCO Platform Helm Charts Deployment on ARO

This document lists all external URLs and endpoints that need to be accessible for deploying TIBCO Platform on Azure Red Hat OpenShift (ARO) using the tp-helm-charts repository.

**Repository**: https://github.com/TIBCOSoftware/tp-helm-charts  
**Generated**: January 23, 2026

---

## Official TIBCO Documentation References

**📖 Before configuring your firewall, review the official TIBCO Platform documentation:**

- **[TIBCO Platform Whitelisting Requirements](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/whitelisting-requirements.htm)** - Official Control Plane firewall requirements
- **[Pushing Images to Custom Container Registry](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/pushing-images-to-registry.htm)** - Container registry authentication and access
- **[TIBCO Platform Helm Charts Repository](https://github.com/TIBCOSoftware/tp-helm-charts)** - Official Helm charts and deployment guides

---

## Summary

The TIBCO Platform deployment on ARO requires access to:
- **6 Container Registries** for pulling images (TIBCO JFrog, Red Hat, Docker Hub, Quay.io, GitHub)
- **5 Helm Chart Repositories** for downloading charts
- **8+ External Services** for Kubernetes, monitoring, and documentation
- **5 Azure-specific endpoints** for storage and management
- **4 Red Hat/OpenShift endpoints** for cluster operations
- **1 Go Module Proxy** for Flogo applications (if not using Flogo CLI)

**⚠️ CRITICAL REQUIREMENTS:**
1. **TIBCO JFrog Registry** (`csgprduswrepoedge.jfrog.io`) - All TIBCO Platform images
2. **TIBCO Helm Charts** (`tibcosoftware.github.io`) - Official Helm charts repository
3. **Go Module Proxy** (`proxy.golang.org`) - Required for Flogo applications unless built with Flogo CLI
4. **Red Hat Registries** (`registry.redhat.io`, `quay.io`) - OpenShift cluster images and updates

---

## 1. Container Registries

These registries host the container images used by TIBCO Platform, OpenShift, and dependencies.

### TIBCO Container Registry (CRITICAL)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `csgprduswrepoedge.jfrog.io` | 443 | HTTPS | **PRIMARY**: TIBCO Platform production images (CP, DP, capabilities) |

**⚠️ IMPORTANT:** This is the main TIBCO container registry. Access requires authentication with JFrog credentials.

**📖 Documentation**: [Pushing Images to Custom Container Registry](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/pushing-images-to-registry.htm)

---

### Red Hat Container Registries (CRITICAL for ARO)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `registry.redhat.io` | 443 | HTTPS | **Red Hat certified images** (requires Red Hat credentials) |
| `quay.io` | 443 | HTTPS | **Red Hat Quay** - OpenShift container images |
| `registry.connect.redhat.com` | 443 | HTTPS | Red Hat Container Catalog - Certified partner images |

**⚠️ IMPORTANT:** Red Hat registries require authentication. ARO clusters use pull secrets for access.

---

### Public Container Registries

| URL | Port | Protocol | Purpose | Images Used |
|-----|------|----------|---------|-------------|
| `docker.io` | 443 | HTTPS | Docker Hub - PostgreSQL and Jaeger tracing | PostgreSQL (bitnami/postgresql:16.4.0), Jaeger (jaegertracing/*) |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry - Message Gateway | TIBCO Message Gateway (tibco/msg-platform-cicd) |

---

### Microsoft Container Registry (for Azure)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `mcr.microsoft.com` | 443 | HTTPS | Microsoft Container Registry - Azure integration images |
| `*.azurecr.io` | 443 | HTTPS | Azure Container Registry (if using private registry) |

---

## 2. Helm Chart Repositories

These repositories host the Helm charts for TIBCO Platform and dependencies.

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `https://tibcosoftware.github.io/tp-helm-charts` | 443 | HTTPS | **PRIMARY**: TIBCO Platform official helm charts |
| `https://charts.jetstack.io` | 443 | HTTPS | cert-manager charts |
| `https://helm.elastic.co` | 443 | HTTPS | Elastic ECK operator charts |
| `https://kubernetes-sigs.github.io/external-dns` | 443 | HTTPS | External DNS charts |
| `https://prometheus-community.github.io/helm-charts` | 443 | HTTPS | Prometheus and Grafana stack charts |

---

## 3. Red Hat and OpenShift Services

### Red Hat API and Services

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `api.openshift.com` | 443 | HTTPS | OpenShift Cluster Manager API |
| `console.redhat.com` | 443 | HTTPS | Red Hat Hybrid Cloud Console |
| `sso.redhat.com` | 443 | HTTPS | Red Hat SSO authentication |
| `access.redhat.com` | 443 | HTTPS | Red Hat Customer Portal |

### OpenShift Update Services

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `*.quay.io` | 443 | HTTPS | OpenShift update payloads |
| `registry.access.redhat.com` | 443 | HTTPS | OpenShift base images and updates |

---

## 4. Azure-Specific Endpoints

### Azure Resource Manager and Authentication

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager API |
| `login.microsoftonline.com` | 443 | HTTPS | Azure AD authentication |
| `*.login.microsoftonline.com` | 443 | HTTPS | Azure AD multi-tenant authentication |

### Azure Storage and Services

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `*.blob.core.windows.net` | 443 | HTTPS | Azure Blob Storage |
| `*.file.core.windows.net` | 443 | HTTPS | Azure Files |
| `*.vault.azure.net` | 443 | HTTPS | Azure Key Vault (if used) |
| `*.azurecr.io` | 443 | HTTPS | Azure Container Registry |

### Azure Monitor and Logging

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `*.ods.opinsights.azure.com` | 443 | HTTPS | Azure Monitor data collection |
| `*.oms.opinsights.azure.com` | 443 | HTTPS | Azure Log Analytics |
| `*.monitoring.azure.com` | 443 | HTTPS | Azure Monitor metrics |

---

## 5. Monitoring and Observability

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `prometheus.io` | 443 | HTTPS | Prometheus documentation |
| `opentelemetry.io` | 443 | HTTPS | OpenTelemetry documentation |
| `elastic.co` | 443 | HTTPS | Elastic documentation and downloads |
| `grafana.com` | 443 | HTTPS | Grafana documentation and downloads |

---

## 6. Source Code and Documentation

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `github.com` | 443 | HTTPS | GitHub - Source code, releases, documentation |
| `*.githubusercontent.com` | 443 | HTTPS | GitHub raw content |
| `ubuntu.com` | 443 | HTTPS | Ubuntu package repositories (for base images) |
| `registry.access.redhat.com` | 443 | HTTPS | Red Hat base images |
| `kubernetes.io` | 443 | HTTPS | Kubernetes documentation and API references |
| `k8s.io` | 443 | HTTPS | Kubernetes documentation and tools |

---

## 7. Internal Cluster Communication (No Firewall Rules Needed)

These are internal cluster services that communicate within the OpenShift cluster:

- `*.svc.cluster.local` - Internal Kubernetes service DNS
- `*.apps.<cluster-name>.<domain>` - OpenShift application routes
- `otel-userapp-traces.<namespace>.svc.cluster.local` - OTEL trace collector
- `otel-userapp-metrics.<namespace>.svc.cluster.local` - OTEL metrics collector
- `dp-config-es-es-http.elastic-system.svc.cluster.local` - Elasticsearch
- `kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local` - Prometheus

---

## 8. TIBCO Flogo Go Module Proxy (CRITICAL for Flogo Apps)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `https://proxy.golang.org` | 443 | HTTPS | **CRITICAL**: Go module proxy for Flogo applications |
| `https://sum.golang.org` | 443 | HTTPS | Go checksum database for module verification |

**⚠️ IMPORTANT:** 
- **Required for TIBCO Flogo applications** that are NOT built using the Flogo CLI
- The Kubernetes cluster must have outbound access to `https://proxy.golang.org`
- This is the official Go module proxy that Flogo runtime uses to download dependencies
- Without access to this endpoint, Flogo applications will fail to start if they have external Go module dependencies
- If using the Flogo CLI to build applications, this endpoint may not be required as dependencies are bundled

**Workaround**: If you cannot allow access to `proxy.golang.org`, build all Flogo applications using the Flogo CLI which bundles dependencies.

---

## 9. Complete Firewall Rules Summary

### Outbound Rules (From ARO to Internet)

#### Required (CRITICAL)

```
Protocol: HTTPS (443)
Destinations:
  # TIBCO Platform
  - csgprduswrepoedge.jfrog.io              # TIBCO images
  - tibcosoftware.github.io                  # TIBCO helm charts
  
  # Red Hat/OpenShift (CRITICAL for ARO)
  - registry.redhat.io                       # Red Hat certified images
  - quay.io                                   # OpenShift images
  - *.quay.io                                 # OpenShift updates
  - api.openshift.com                         # OpenShift API
  - console.redhat.com                        # Red Hat console
  - sso.redhat.com                            # Red Hat SSO
  - registry.access.redhat.com                # Red Hat base images
  
  # Container Registries
  - docker.io                                 # PostgreSQL, Jaeger
  - ghcr.io                                   # Message Gateway
  
  # Helm Charts
  - charts.jetstack.io                        # cert-manager
  - helm.elastic.co                           # Elastic ECK
  - kubernetes-sigs.github.io                 # External DNS
  - prometheus-community.github.io            # Prometheus stack
  
  # Azure Services
  - management.azure.com                      # Azure ARM
  - login.microsoftonline.com                 # Azure AD
  - *.blob.core.windows.net                   # Azure Blob Storage
  
  # Go Module Proxy (Flogo)
  - proxy.golang.org                          # Go module proxy
  - sum.golang.org                            # Go checksum database
```

#### Recommended (HIGHLY RECOMMENDED)

```
Protocol: HTTPS (443)
Destinations:
  - mcr.microsoft.com                         # Microsoft Container Registry
  - *.azurecr.io                              # Azure Container Registry
  - github.com                                # GitHub
  - *.githubusercontent.com                   # GitHub raw content
  - *.file.core.windows.net                   # Azure Files
  - *.vault.azure.net                         # Azure Key Vault
  - *.ods.opinsights.azure.com               # Azure Monitor
  - *.oms.opinsights.azure.com               # Azure Log Analytics
  - registry.connect.redhat.com               # Red Hat partner catalog
  - access.redhat.com                         # Red Hat customer portal
  - kubernetes.io                             # Kubernetes docs
  - k8s.io                                    # Kubernetes docs
```

#### Optional (For Documentation and Troubleshooting)

```
Protocol: HTTPS (443)
Destinations:
  - prometheus.io                             # Prometheus docs
  - opentelemetry.io                          # OpenTelemetry docs
  - elastic.co                                # Elastic docs
  - grafana.com                               # Grafana docs
  - ubuntu.com                                # Ubuntu packages
```

---

## 10. Network Security Group (NSG) Rules for Azure

If using Azure Network Security Groups, create the following outbound rules:

### Priority 100: TIBCO Container Registry

```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow TIBCO JFrog container registry
```

### Priority 110: Red Hat and OpenShift Services

```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Red Hat registries and OpenShift services
```

### Priority 120: Helm Chart Repositories

```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Helm chart repositories (tibcosoftware, charts.jetstack, etc.)
```

### Priority 130: Azure Management

```
Source: VirtualNetwork
Destination: Service Tag - AzureCloud
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Azure Resource Manager and Azure AD
```

### Priority 140: Container Registries

```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Docker Hub, GitHub Container Registry, MCR
```

---

## 11. Azure Firewall Application Rules

If using Azure Firewall, create the following application rule collections:

### Rule Collection: TIBCO-Platform-ARO-Required

```yaml
Priority: 100
Action: Allow
Rules:
  - Name: TIBCO-Container-Registry
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - csgprduswrepoedge.jfrog.io
  
  - Name: TIBCO-Helm-Charts
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - tibcosoftware.github.io
  
  - Name: RedHat-OpenShift-Core
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - registry.redhat.io
      - quay.io
      - *.quay.io
      - api.openshift.com
      - console.redhat.com
      - sso.redhat.com
      - registry.access.redhat.com
      - registry.connect.redhat.com
  
  - Name: Third-Party-Helm-Charts
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - charts.jetstack.io
      - helm.elastic.co
      - kubernetes-sigs.github.io
      - prometheus-community.github.io
  
  - Name: Container-Registries
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - docker.io
      - ghcr.io
      - mcr.microsoft.com
      - *.azurecr.io
  
  - Name: Azure-Services
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - management.azure.com
      - login.microsoftonline.com
      - *.login.microsoftonline.com
      - *.blob.core.windows.net
      - *.file.core.windows.net
      - *.vault.azure.net
      - *.ods.opinsights.azure.com
      - *.oms.opinsights.azure.com
  
  - Name: Go-Module-Proxy-Flogo
    Source Addresses: <ARO_WORKER_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - proxy.golang.org
      - sum.golang.org
```

---

## 12. Proxy Configuration for Enterprise Environments

If your enterprise has a secure HTTP/HTTPS proxy already configured, you can configure TIBCO Platform to use it instead of opening all firewall rules.

### 12.1 Prerequisites

- HTTP/HTTPS proxy server already deployed and operational
- Proxy allows HTTPS traffic to required endpoints (see sections above)
- Proxy authentication credentials (if required)

### 12.2 Configure OpenShift Cluster-Wide Proxy

ARO/OpenShift supports cluster-wide proxy configuration:

```yaml
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  httpProxy: http://proxy.company.com:8080
  httpsProxy: http://proxy.company.com:8080
  noProxy: >-
    localhost,127.0.0.1,
    .svc,.svc.cluster.local,
    .apps.<cluster-name>.<domain>,
    api.<cluster-name>.<domain>,
    10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,
    169.254.169.254,
    <ARO_SERVICE_CIDR>,<ARO_POD_CIDR>,
    .azure.com
  # Optional: Proxy authentication
  trustedCA:
    name: user-ca-bundle
```

**NO_PROXY must include**:
- `localhost`, `127.0.0.1` - Local host
- `169.254.169.254` - Azure metadata service
- `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` - Private IP ranges
- `.svc`, `.svc.cluster.local` - Kubernetes service discovery
- `.apps.<cluster-name>.<domain>` - OpenShift application routes
- `api.<cluster-name>.<domain>` - OpenShift API server
- `<ARO_SERVICE_CIDR>` - Your ARO service CIDR (e.g., `172.30.0.0/16`)
- `<ARO_POD_CIDR>` - Your ARO pod CIDR (e.g., `10.128.0.0/14`)
- `.azure.com` - Azure service endpoints (or use Azure Private Link instead)

**Apply the proxy configuration**:
```bash
oc apply -f cluster-proxy.yaml

# Verify proxy configuration
oc get proxy/cluster -o yaml
```

### 12.3 Configure TIBCO Platform Control Plane Proxy Settings

After installing the TIBCO Platform Control Plane, configure proxy settings through the UI or via Helm values.

**Reference Documentation**: [TIBCO Platform - Updating Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)

#### Option 1: Configure via Control Plane UI

1. Login to TIBCO Platform Control Plane UI
2. Navigate to **Settings** → **Infrastructure** → **Proxy Configuration**
3. Configure the following settings:

```yaml
HTTP Proxy: http://proxy.company.com:8080
HTTPS Proxy: http://proxy.company.com:8080
No Proxy: localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8,.apps.<cluster-name>.<domain>
Proxy Username: <username> (if authentication required)
Proxy Password: <password> (if authentication required)
```

4. Click **Save** and **Apply Configuration**

#### Option 2: Configure via Helm Values

Include proxy configuration in your `tibco-cp-base` values file:

```yaml
# tibco-cp-base-values.yaml
global:
  tibco:
    # Proxy configuration
    proxy:
      enabled: true
      httpProxy: "http://proxy.company.com:8080"
      httpsProxy: "http://proxy.company.com:8080"
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8,.apps.<cluster-name>.<domain>"
      # Optional: Proxy authentication
      username: "<username>"
      password: "<password>"
```

Then upgrade the Control Plane:

```bash
helm upgrade --install -n ${CP_INSTANCE_ID}-ns tibco-cp-base tibco-platform-public/tibco-cp-base \
  --version "${CP_TIBCO_CP_BASE_VERSION}" \
  -f tibco-cp-base-values.yaml
```

### 12.4 Configure TIBCO Platform Data Plane Proxy Settings

Configure proxy settings for the Data Plane similarly:

```yaml
# dp-configure-namespace values
global:
  tibco:
    proxy:
      enabled: true
      httpProxy: "http://proxy.company.com:8080"
      httpsProxy: "http://proxy.company.com:8080"
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8,.apps.<cluster-name>.<domain>"
```

### 12.5 Configure Flogo Applications for Go Module Proxy

For TIBCO Flogo applications that are NOT built using the Flogo CLI, configure the Go module proxy:

#### Option 1: Use Corporate Proxy for proxy.golang.org

Ensure your corporate proxy allows access to:
- `https://proxy.golang.org`
- `https://sum.golang.org`

No additional configuration needed if ARO is already configured with cluster-wide proxy settings.

#### Option 2: Use Private Go Module Proxy (Athens or Artifactory)

If your enterprise has a private Go module proxy:

```yaml
# Flogo application environment variables
env:
  - name: GOPROXY
    value: "https://go-proxy.company.com,https://proxy.golang.org,direct"
  - name: GOSUMDB
    value: "sum.golang.org"
  - name: GOPRIVATE
    value: "github.com/company/*"  # Private modules
```

#### Option 3: Build with Flogo CLI (Recommended)

**Best Practice**: Build all Flogo applications using the Flogo CLI to bundle dependencies:

```bash
# Build Flogo application with bundled dependencies
flogo build --embed-config true --optimize true

# This eliminates the need for proxy.golang.org access at runtime
```

### 12.6 Verify Proxy Configuration

After configuring proxy settings, verify connectivity:

```bash
# Check cluster-wide proxy settings
oc get proxy/cluster -o yaml

# Test from a pod
oc run test-proxy --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c 'echo "HTTP_PROXY=$HTTP_PROXY"; curl -I https://proxy.golang.org'

# Check Control Plane proxy settings
oc get configmap -n ${CP_INSTANCE_ID}-ns -o yaml | grep -i proxy

# Check Data Plane proxy settings
oc get configmap -n ${DP_NAMESPACE} -o yaml | grep -i proxy
```

### 12.7 Proxy Configuration Best Practices

1. **Use cluster-wide proxy** configuration in OpenShift for consistent behavior
2. **Configure NO_PROXY carefully** to avoid routing internal traffic through proxy
3. **Test thoroughly** after proxy configuration changes
4. **Monitor proxy logs** for blocked connections or authentication issues
5. **Document proxy exceptions** required for TIBCO Platform
6. **Use Azure Private Link** for Azure services to bypass proxy
7. **Rotate proxy credentials** regularly if authentication is required
8. **Leverage OpenShift's built-in proxy support** for automatic propagation to pods

### 12.8 Troubleshooting Proxy Issues

**Issue**: Pods cannot pull images through proxy
```bash
# Check cluster-wide proxy configuration
oc get proxy/cluster -o yaml

# Check if CRI-O is using proxy settings
oc debug node/<node-name> -- chroot /host cat /etc/sysconfig/crio | grep -i proxy

# Restart CRI-O if needed (node restart may be required)
```

**Issue**: Flogo applications fail to download Go modules
```bash
# Check GOPROXY setting in pod
oc exec -it <flogo-pod> -- env | grep GOPROXY

# Test Go module proxy access
oc exec -it <flogo-pod> -- curl -v https://proxy.golang.org
```

**Issue**: Control Plane services cannot reach external APIs
```bash
# Check proxy configuration in Control Plane namespace
oc get configmap -n ${CP_INSTANCE_ID}-ns -o yaml | grep -A 5 proxy

# Check pod environment variables
oc exec -it <cp-pod> -n ${CP_INSTANCE_ID}-ns -- env | grep -i proxy

# Check OpenShift cluster proxy status
oc get clusteroperators | grep proxy
```

**Issue**: OpenShift cluster operators failing due to proxy
```bash
# Check cluster operator status
oc get clusteroperators

# Check proxy configuration status
oc get proxy/cluster -o jsonpath='{.status}'

# View operator logs
oc logs -n openshift-cluster-version deployments/cluster-version-operator
```

---

## 13. DNS Requirements

Ensure the following DNS resolutions work from within the ARO cluster:

### External DNS

#### TIBCO Platform
- `csgprduswrepoedge.jfrog.io`
- `tibcosoftware.github.io`
- `proxy.golang.org` (for Flogo)
- `sum.golang.org` (for Flogo)

#### Red Hat/OpenShift
- `registry.redhat.io`
- `quay.io`
- `api.openshift.com`
- `console.redhat.com`
- `sso.redhat.com`
- `registry.access.redhat.com`

#### Container Registries
- `docker.io`
- `ghcr.io`
- `mcr.microsoft.com`

#### Azure Services
- `management.azure.com`
- `login.microsoftonline.com`

### Azure-Specific DNS

- `*.blob.core.windows.net`
- `*.file.core.windows.net`
- `*.vault.azure.net`
- `*.ods.opinsights.azure.com`
- `*.oms.opinsights.azure.com`

### Internal DNS (CoreDNS/OpenShift DNS)

- `*.svc.cluster.local` (internal service discovery)
- `*.apps.<cluster-name>.<domain>` (OpenShift routes)
- `api.<cluster-name>.<domain>` (OpenShift API server)

---

## 14. Testing Connectivity

After configuring firewall rules, test connectivity from within the ARO cluster:

### Test Container Registry Access

```bash
# Test TIBCO JFrog registry
oc run test-jfrog --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://csgprduswrepoedge.jfrog.io

# Test Red Hat registry
oc run test-redhat --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://registry.redhat.io

# Test Quay.io
oc run test-quay --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://quay.io

# Test Docker Hub
oc run test-docker --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://docker.io

# Test GitHub Container Registry
oc run test-ghcr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://ghcr.io
```

### Test Helm Repository Access

```bash
# Test TIBCO Helm charts
oc run test-helm --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://tibcosoftware.github.io/tp-helm-charts/index.yaml

# Test cert-manager charts
oc run test-certmgr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://charts.jetstack.io/index.yaml
```

### Test Red Hat Services

```bash
# Test OpenShift API
oc run test-openshift --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://api.openshift.com

# Test Red Hat console
oc run test-console --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://console.redhat.com
```

### Test Azure Connectivity

```bash
# Test Azure management
oc run test-azure --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://management.azure.com

# Test Azure AD
oc run test-azuread --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://login.microsoftonline.com
```

### Test Go Module Proxy (Flogo)

```bash
# Test proxy.golang.org (critical for Flogo)
oc run test-goproxy --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://proxy.golang.org

# Test sum.golang.org
oc run test-gosum --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://sum.golang.org
```

---

## 15. Troubleshooting

### Common Issues

**Issue**: Cannot pull images from `registry.redhat.io`  
**Solution**: 
1. Verify firewall allows HTTPS (443) to `registry.redhat.io`
2. Check Red Hat pull secret is correctly configured in the cluster
3. Verify ARO cluster has valid Red Hat subscription
4. Test with: `oc get secret pull-secret -n openshift-config -o json`

**Issue**: Cannot pull images from `csgprduswrepoedge.jfrog.io`  
**Solution**: 
1. Verify firewall allows HTTPS (443) to `csgprduswrepoedge.jfrog.io`
2. Check JFrog credentials are correctly configured
3. Test with: `oc create secret docker-registry jfrog-secret --docker-server=csgprduswrepoedge.jfrog.io --docker-username=<user> --docker-password=<pass>`

**Issue**: Helm install fails with "failed to download chart"  
**Solution**:
1. Verify access to `tibcosoftware.github.io`
2. Check cluster-wide proxy settings if applicable: `oc get proxy cluster -o yaml`
3. Test with: `helm repo add tibco https://tibcosoftware.github.io/tp-helm-charts && helm repo update`

**Issue**: OpenShift cluster cannot access update services  
**Solution**:
1. Ensure access to `quay.io` and `*.quay.io`
2. Verify `registry.access.redhat.com` is accessible
3. Check cluster version operator logs: `oc logs -n openshift-cluster-version -l k8s-app=cluster-version-operator`

**Issue**: cert-manager certificates not issuing  
**Solution**:
1. Verify access to `charts.jetstack.io` for initial installation
2. For Let's Encrypt, ensure outbound port 80/443 to Let's Encrypt ACME servers
3. Check cert-manager logs: `oc logs -n cert-manager -l app=cert-manager`

**Issue**: Flogo applications fail to start with Go module errors
**Solution**:
1. **Most Common**: Verify access to `proxy.golang.org` and `sum.golang.org`
2. Check pod logs: `oc logs <flogo-pod> | grep -i "proxy.golang.org"`
3. Verify GOPROXY environment variable: `oc exec <flogo-pod> -- env | grep GOPROXY`
4. Check cluster-wide proxy configuration: `oc get proxy/cluster -o yaml`
5. **Workaround**: Build Flogo applications using Flogo CLI to bundle dependencies

**Issue**: Azure CSI drivers not working  
**Solution**:
1. Verify Azure managed identity or service principal has correct permissions
2. Check ARO cluster has access to Azure Resource Manager
3. Review OpenShift logs: `oc logs -n openshift-cluster-csi-drivers`

---

## 16. Security Considerations

### Least Privilege Access
- Only allow outbound traffic to required destinations
- Use Azure Private Link for Azure services where possible
- Implement Network Policies within the cluster using OpenShift SDN or OVN

### Credential Management
- Store JFrog credentials in OpenShift secrets
- Store Red Hat pull secrets in `openshift-config` namespace
- Use managed identities for Azure service authentication
- Rotate credentials regularly

### Monitoring
- Enable Azure Firewall logs
- Monitor NSG flow logs
- Enable OpenShift audit logging
- Set up alerts for blocked connections

### OpenShift-Specific Security
- Use OpenShift Security Context Constraints (SCCs)
- Enable OpenShift container runtime security
- Use OpenShift Network Policies for micro-segmentation
- Enable OpenShift compliance operator for security scanning

---

## 17. Simplified Firewall Request Template

For enterprise environments with strict firewall policies, use this template to submit a firewall request that covers most TIBCO Platform deployment requirements on ARO.

### Generic Internet Access on Port 443 (Recommended Approach)

**Request Type**: Outbound Internet Access  
**Protocol**: HTTPS  
**Port**: 443  
**Direction**: Outbound (from ARO cluster to Internet)  
**Platform**: Azure Red Hat OpenShift (ARO)

#### Option 1: Broad Access (Simplest)

```
Source: <ARO_WORKER_SUBNET_CIDR> (e.g., 10.1.0.0/24)
Destination: Any (0.0.0.0/0)
Port: 443
Protocol: TCP
Action: Allow
Justification: Required for ARO cluster operations, TIBCO Platform deployment - 
container image pulls from Red Hat/TIBCO registries, helm chart downloads, and 
cloud provider API access
```

**Pros**: Covers all required and optional endpoints, simplifies ARO operations  
**Cons**: Less secure, may not meet compliance requirements  
**Use Case**: Development/test environments, PoC deployments

#### Option 2: Service Tag Based (Azure Recommended)

```yaml
Source: <ARO_WORKER_SUBNET_CIDR>
Destination Service Tags:
  - Internet (for TIBCO JFrog, Red Hat registries, Helm repos, Docker Hub, GitHub)
  - AzureCloud (for Azure management and authentication)
  - RedHatOpenShift (if available)
Port: 443
Protocol: TCP
Action: Allow
```

**Pros**: Better security, uses Azure service tags  
**Cons**: Still broad Internet access  
**Use Case**: Production environments with moderate security requirements

#### Option 3: FQDN-Based (Most Secure)

For maximum security, request access to specific FQDNs only:

```yaml
Rule Name: TIBCO-Platform-ARO-HTTPS-Access
Source: <ARO_WORKER_SUBNET_CIDR>
Destination Type: FQDN
Port: 443
Protocol: HTTPS

Required FQDNs (CRITICAL - Must be approved):
  # TIBCO Platform
  - csgprduswrepoedge.jfrog.io          # TIBCO container images
  - tibcosoftware.github.io              # TIBCO helm charts
  
  # Red Hat/OpenShift (CRITICAL for ARO)
  - registry.redhat.io                   # Red Hat certified images
  - quay.io                              # OpenShift images
  - *.quay.io                            # OpenShift updates
  - api.openshift.com                    # OpenShift API
  - console.redhat.com                   # Red Hat console
  - sso.redhat.com                       # Red Hat SSO
  - registry.access.redhat.com           # Red Hat base images
  
  # Container Registries
  - docker.io                            # Docker Hub
  - ghcr.io                              # GitHub Container Registry
  - mcr.microsoft.com                    # Microsoft Container Registry
  
  # Helm Charts
  - charts.jetstack.io                   # cert-manager
  - helm.elastic.co                      # Elastic ECK
  - kubernetes-sigs.github.io            # External DNS
  - prometheus-community.github.io       # Prometheus
  
  # Azure Services
  - management.azure.com                 # Azure Resource Manager
  - login.microsoftonline.com           # Azure AD
  - *.login.microsoftonline.com         # Azure AD multi-tenant
  - *.blob.core.windows.net             # Azure Blob Storage
  
  # Go Module Proxy (Flogo)
  - proxy.golang.org                     # Go module proxy
  - sum.golang.org                       # Go checksum database

Optional FQDNs (Recommended):
  - github.com                           # Source code and releases
  - *.githubusercontent.com              # GitHub raw content
  - k8s.io                               # Kubernetes
  - kubernetes.io                        # Kubernetes
  - *.azurecr.io                         # Azure Container Registry
  - *.vault.azure.net                    # Azure Key Vault
  - *.file.core.windows.net              # Azure Files
  - *.ods.opinsights.azure.com          # Azure Monitor
  - *.oms.opinsights.azure.com          # Azure Log Analytics
  - registry.connect.redhat.com          # Red Hat partner catalog
  - access.redhat.com                    # Red Hat customer portal
```

**Pros**: Most secure, explicit FQDN allow-list  
**Cons**: Requires Azure Firewall Premium for FQDN filtering with TLS inspection  
**Use Case**: Production ARO environments with strict security requirements

### Sample Firewall Request Form

Use this template when submitting to your network/security team:

```
FIREWALL REQUEST - TIBCO PLATFORM ON AZURE RED HAT OPENSHIFT (ARO)

Request ID: [Auto-generated or manual]
Requested By: [Your Name]
Team: [Your Team]
Date: [Current Date]
Environment: [Production/Staging/Development]
Platform: Azure Red Hat OpenShift (ARO) Cluster

1. BUSINESS JUSTIFICATION
   Deployment of TIBCO Platform Control Plane and Data Plane on Azure Red Hat 
   OpenShift (ARO) cluster for [business purpose]. Requires outbound Internet 
   access to pull container images from Red Hat and TIBCO registries, download 
   Helm charts, access OpenShift update services, and communicate with Azure 
   cloud services.

2. SOURCE
   - Type: Azure Subnet (ARO Worker Nodes)
   - CIDR: [e.g., 10.1.0.0/24]
   - Description: ARO cluster worker node subnet
   - Resource Group: [e.g., rg-aro-tibco-platform-prod]
   - Subscription: [Azure Subscription ID]
   - ARO Cluster: [ARO cluster name]

3. DESTINATION
   - Option A (Recommended): Internet (0.0.0.0/0) with Azure Service Tags
   - Option B (Secure): FQDN-based (see attached FQDN list)
   - Option C (Most Secure): Specific IP ranges (requires IP resolution)

4. PORTS AND PROTOCOLS
   - Port: 443
   - Protocol: TCP/HTTPS
   - Direction: Outbound only

5. REQUIRED ENDPOINTS (Critical - Cannot deploy without these)
   
   TIBCO Platform:
   - csgprduswrepoedge.jfrog.io (TIBCO container registry)
   - tibcosoftware.github.io (TIBCO Helm charts)
   
   Red Hat/OpenShift (CRITICAL for ARO operations):
   - registry.redhat.io (Red Hat certified images)
   - quay.io (OpenShift container images)
   - api.openshift.com (OpenShift Cluster Manager)
   - console.redhat.com (Red Hat Hybrid Cloud Console)
   - sso.redhat.com (Red Hat SSO)
   - registry.access.redhat.com (OpenShift base images)
   
   Azure Services:
   - management.azure.com (Azure Resource Manager)
   - login.microsoftonline.com (Azure AD)
   
   Container Registries:
   - docker.io (Docker Hub)

6. OPTIONAL ENDPOINTS (Highly recommended for full functionality)
   - charts.jetstack.io, helm.elastic.co, prometheus-community.github.io
   - mcr.microsoft.com, ghcr.io
   - *.blob.core.windows.net, *.file.core.windows.net
   - *.ods.opinsights.azure.com (Azure Monitor)
   - registry.connect.redhat.com (Red Hat partner catalog)

7. DURATION
   - Permanent (required for ongoing ARO cluster and platform operations)

8. SECURITY CONSIDERATIONS
   - All traffic is HTTPS (encrypted)
   - Authentication required for TIBCO JFrog and Red Hat registries
   - Managed identities used for Azure service authentication
   - OpenShift Network Policies and SCCs implemented within cluster
   - OpenShift audit logging enabled

9. COMPLIANCE & AUDIT
   - Azure Firewall logs enabled: [Yes/No]
   - NSG flow logs enabled: [Yes/No]
   - OpenShift audit logs enabled: [Yes/No]
   - Log Analytics workspace: [Workspace ID]

10. ROLLBACK PLAN
    If firewall rules cause issues:
    1. Disable TIBCO-specific rules while keeping Red Hat/Azure endpoints active
    2. ARO cluster will continue operating with Red Hat registry access
    3. Revert to previous known-good firewall configuration
    4. Monitor OpenShift cluster version operator for update failures

11. TESTING PLAN
    Post-approval, validate connectivity using oc (OpenShift CLI):
    - Test TIBCO JFrog: oc run test --image=curlimages/curl --rm -it -- curl -I https://csgprduswrepoedge.jfrog.io
    - Test Red Hat registry: oc run test --image=curlimages/curl --rm -it -- curl -I https://registry.redhat.io
    - Test Helm repos: oc run test --image=curlimages/curl --rm -it -- curl -I https://tibcosoftware.github.io
    - Test Azure: oc run test --image=curlimages/curl --rm -it -- curl -I https://management.azure.com
    - Verify cluster operators: oc get clusteroperators

12. ARO-SPECIFIC CONSIDERATIONS
    - ARO requires access to Red Hat services for cluster health and updates
    - Blocking Red Hat endpoints will prevent cluster updates and may affect stability
    - Red Hat SRE team requires access to monitor and manage ARO infrastructure
    - OpenShift console requires access to console.redhat.com for some features

13. ATTACHMENTS
    - Full FQDN list (see Section 9 of this document)
    - NSG rules (see Section 10)
    - Azure Firewall rules (see Section 11)
    - ARO cluster architecture diagram
```

### Quick Tips for ARO Firewall Request Approval

1. **Emphasize ARO requirements**: Red Hat endpoints are CRITICAL for cluster health and updates
2. **Start broad, refine later**: Request Internet access on 443 initially, especially for ARO
3. **Highlight encryption**: All traffic is HTTPS (encrypted), reducing security concerns
4. **Note Red Hat SRE**: ARO is managed by Red Hat SRE, blocking endpoints may void support
5. **Provide business value**: Tie request to business objectives and project timelines
6. **Offer monitoring**: Commit to enabling firewall and OpenShift audit logs
7. **Include compliance**: OpenShift has security certifications (PCI-DSS, HIPAA-ready, etc.)
8. **Test quickly**: Schedule connectivity testing immediately after approval

### Alternative: Private ARO with Restricted Egress

If firewall approval is denied or extremely limited:

1. **Private ARO cluster**: Deploy ARO in private mode with no Internet access
2. **Mirror container images**: 
   - Mirror Red Hat images to internal registry using `oc adm release mirror`
   - Copy TIBCO images to Azure Container Registry
3. **Disconnected OpenShift**: Configure ARO for disconnected operation
4. **Local Helm charts**: Clone tp-helm-charts repo to internal Git/Artifactory
5. **Disable telemetry**: Configure cluster to not send telemetry data
6. **Manual updates**: Download OpenShift updates on bastion, transfer to cluster

**Note**: Private ARO requires:
- Azure Private Link for Azure services
- Internal DNS resolution
- Jump box/bastion for cluster access
- Significantly more operational overhead
- May impact Red Hat support capabilities

---

## 18. References

- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [TIBCO Platform Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)
- [Azure Red Hat OpenShift Documentation](https://learn.microsoft.com/en-us/azure/openshift/)
- [ARO Network Requirements](https://learn.microsoft.com/en-us/azure/openshift/support-policies-v4#network-connectivity)
- [OpenShift Container Platform Network Configuration](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)
- [OpenShift Cluster-Wide Proxy Configuration](https://docs.openshift.com/container-platform/latest/networking/enable-cluster-wide-proxy.html)
- [Azure Firewall Application Rules](https://learn.microsoft.com/en-us/azure/firewall/rule-processing)
- [Red Hat Container Registry Authentication](https://access.redhat.com/RegistryAuthentication)
- [Go Module Proxy](https://proxy.golang.org)

---

**Document Version**: 1.1  
**Last Updated**: January 29, 2026  
**Platform**: Azure Red Hat OpenShift (ARO)  
**Generated From**: /Users/kul/git/tib/tp-helm-charts

