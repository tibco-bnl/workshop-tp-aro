# TIBCO Platform v1.16.0 on ARO - Quick Reference

**Last Updated:** April 10, 2026  
**TIBCO Platform Version:** 1.16.0  
**Minimum OpenShift Version:** 4.12 (4.14+ recommended for ARO)

## Quick Commands

### Cluster Information
```bash
# Check OpenShift version
oc version

# Check ARO cluster info
oc cluster-info

# List all nodes
oc get nodes

# Check cluster operators
oc get clusteroperators
```

### Container Registry Setup
```bash
# Create image pull secret (v1.16.0 registry)
oc create secret docker-registry tibco-container-registry-credentials \
  -n cp1-ns \
  --docker-server=csgprdusw2reposaas.jfrog.io \
  --docker-username=tibco-platform-devqa \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}"
```

### Control Plane Installation
```bash
# Add TIBCO Helm repository
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update

# Install Control Plane base
helm install tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -n cp1-ns \
  -f cp1-values.yaml

# Check installation
oc get pods -n cp1-ns
helm list -n cp1-ns
```

### OpenShift Routes
```bash
# List all routes
oc get routes -n cp1-ns

# Describe a route
oc describe route <route-name> -n cp1-ns

# Get route URL
oc get route admin-route -n cp1-ns -o jsonpath='{.spec.host}'
```

### Monitoring
```bash
# Check pod logs
oc logs <pod-name> -n cp1-ns

# Follow logs
oc logs -f <pod-name> -n cp1-ns

# Check events
oc get events -n cp1-ns --sort-by='.lastTimestamp'

# Pod status
oc get pods -n cp1-ns -o wide
```

### Troubleshooting
```bash
# Check pod details
oc describe pod <pod-name> -n cp1-ns

# Check Security Context Constraints
oc get scc
oc describe scc <scc-name>

# Check service accounts
oc get sa -n cp1-ns

# Check secrets
oc get secrets -n cp1-ns

# Check config maps
oc get cm -n cp1-ns
```

### Storage
```bash
# List storage classes
oc get sc

# List persistent volume claims
oc get pvc -n cp1-ns

# Describe PVC
oc describe pvc <pvc-name> -n cp1-ns
```

### Helm Operations
```bash
# List installed charts
helm list -n cp1-ns

# Get values for a release
helm get values tibco-cp-base -n cp1-ns

# Upgrade a release
helm upgrade tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -n cp1-ns \
  -f updated-values.yaml

# Rollback
helm rollback tibco-cp-base 0 -n cp1-ns

# Uninstall
helm uninstall tibco-cp-base -n cp1-ns
```

## Key Differences from AKS

### CLI Commands
| Task | AKS | ARO |
|------|-----|-----|
| CLI Tool | `kubectl` | `oc` |
| Get Pods | `kubectl get pods` | `oc get pods` |
| Logs | `kubectl logs` | `oc logs` |
| Exec | `kubectl exec` | `oc exec` |

### Ingress vs Routes
| Feature | AKS (Ingress) | ARO (Routes) |
|---------|---------------|--------------|
| Resource Type | Ingress | Route |
| TLS Termination | Ingress Controller | Edge/Reencrypt/Passthrough |
| Annotations | Ingress-specific | Route-specific |
| Create Command | `kubectl create ingress` | `oc create route` |

### Storage Classes
| Storage Type | AKS | ARO |
|--------------|-----|-----|
| Files | `azure-files-sc` | `azure-files` / `managed-nfs-storage` |
| Disk | `azure-disk-sc` | `managed-premium` / `azure-disk` |
| Default | Varies | `managed-premium` (typically) |

### Security
| Feature | AKS | ARO |
|---------|-----|-----|
| Pod Security | Pod Security Standards | Security Context Constraints (SCC) |
| Network | Network Policies | NetworkPolicy + OpenShift SDN/OVN |
| RBAC | Standard K8s RBAC | Extended RBAC + Projects |

## Common Values File Snippets

### Router Configuration (ARO)
```yaml
router-operator:
  route:
    enabled: true
    domain: "apps.cluster.region.aroapp.io"
  ingress:
    enabled: false  # Use Routes, not Ingress
```

### Storage Configuration (ARO)
```yaml
storage:
  storageClassName: "managed-premium"  # Or azure-files
  resources:
    requests:
      storage: "10Gi"
```

### Container Registry (v1.16.0)
```yaml
global:
  tibco:
    containerRegistry:
      url: "csgprdusw2reposaas.jfrog.io"
      username: "tibco-platform-devqa"
      password: ""  # Set via secret or environment variable
      repository: "tibco-platform-docker-dev"
```

## Environment Variables Template

```bash
# ARO Cluster
export ARO_CLUSTER_NAME="aro-cluster-name"
export ARO_RESOURCE_GROUP="aro-rg"
export ARO_DOMAIN="apps.cluster.region.aroapp.io"

# TIBCO Platform v1.16.0
export CP_NAMESPACE="cp1-ns"
export CP_INSTANCE_ID="cp1"
export TP_CHART_VERSION="1.16.0"

# Container Registry (v1.16.0)
export TP_CONTAINER_REGISTRY="csgprdusw2reposaas.jfrog.io"
export TP_CONTAINER_REGISTRY_REPO="tibco-platform-docker-dev"
export TP_CONTAINER_REGISTRY_USERNAME="tibco-platform-devqa"
export TP_CONTAINER_REGISTRY_PASSWORD=""  # Set your password

# Admin DNS
export CP_ADMIN_DNS="admin.${CP_INSTANCE_ID}.${ARO_DOMAIN}"
```

## New Features in v1.16.0

### License Management
- 90/30/7 day expiration alerts
- Enhanced license dashboard in UI
- Automated notification system

### BW6 AI Plugin 6.0.0
- RAG (Retrieval-Augmented Generation) support
- AI-powered data processing
- Natural language query capabilities
- Vector database integration

### BW5 Monitoring Enhancements
- Real-time metrics
- Advanced alerting
- Better Hawk integration
- Process visibility improvements

### Flogo Improvements
- Init container support for pre-initialization
- Sidecar container support for auxiliary processes
- Better OpenShift Router integration

## Useful Links

- [v1.16.0 Release Notes](../releases/v1.16.0.md)
- [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm)
- [OpenShift Documentation](https://docs.openshift.com/)
- [ARO Documentation](https://learn.microsoft.com/en-us/azure/openshift/)

---

**Version:** 1.16.0  
**Platform:** Azure Red Hat OpenShift (ARO)  
**Last Updated:** April 10, 2026
