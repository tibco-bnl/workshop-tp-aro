# TIBCO Platform v1.17.0 on ARO - Quick Reference

**Last Updated:** May 18, 2026  
**TIBCO Platform Version:** 1.17.0  
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
# Create image pull secret (v1.17.0 registry)
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
  --version 1.17.0 \
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
  --version 1.17.0 \
  -n cp1-ns \
  -f updated-values.yaml

# Rollback
helm rollback tibco-cp-base 0 -n cp1-ns

# Uninstall
helm uninstall tibco-cp-base -n cp1-ns
```

## New in v1.17.0 - Quick Notes

### OpenSearch for Observability
```bash
# Apply OpenSearch index templates for Jaeger traces
# See: https://docs.tibco.com/pub/platform-cp/latest/doc/html/UserGuide/jaeger-opensearch-index-template.htm

# Create OpenShift Route for OpenSearch (edge TLS termination example)
oc create route edge opensearch-route \
  --service=opensearch-service \
  --port=9200 \
  -n observability-ns

# Verify OpenSearch route
oc get route opensearch-route -n observability-ns
```

### Webhook Receiver Configuration
```bash
# After enabling webhook receiver in Control Plane UI,
# verify egress connectivity to your webhook endpoint
curl -k -X POST <your-webhook-url> \
  -H "Content-Type: application/json" \
  -d '{"test": "tibco-platform-webhook-test"}'

# Check network policy allows egress from cp1-ns to external webhook
oc get networkpolicy -n cp1-ns
```

### BW5CE Hawk REST API (New Port 8090)
```bash
# Test Hawk REST API endpoint in BW5CE pod
oc exec -it <bw5ce-pod-name> -n dp1-ns -- \
  curl -s http://localhost:8090/commands

# If NetworkPolicy is restrictive, add port 8090 rule
# Example NetworkPolicy patch for BW5CE pods
oc patch networkpolicy <bw5ce-networkpolicy> -n dp1-ns \
  --type=json \
  -p='[{"op":"add","path":"/spec/ingress/-","value":{"ports":[{"port":8090,"protocol":"TCP"}]}}]'
```

### Fluentbit Custom Configuration (BW5/BW6 Containers)
```yaml
# Example Helm values for custom Fluentbit config in BW6 Capability
# Set during provisioning or via helm upgrade of the capability
fluentbit:
  customConfig: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        Parser docker
        Tag bw6.*
    [OUTPUT]
        Name  es
        Match bw6.*
        Host  ${ELASTICSEARCH_HOST}
        Port  9200
        Index bw6-logs
```

### Flogo Recipe Customization
```yaml
# Example: Customize Flogo capability recipe via Control Plane UI
# Navigate to: Control Plane → Data Planes → <DP> → Capabilities → Flogo → Provision/Update
# Use the Recipe Editor to modify:
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
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
| Block Storage | `managed-premium` | `managed-premium` |
| File Storage | `azurefile-premium` | `azurefile` |
| Default | `default` | `thin` |

## v1.17.0 Component Versions

| Component | Version |
|-----------|---------|
| tibco-cp-base | 1.17.0 |
| tibco-cp-bw | 1.17.0 |
| tibco-cp-flogo | 1.17.0 |
| tibco-cp-devhub | 1.17.0 |
| tibco-cp-addon-eventprocessing | 1.17.0 |
| tp-dp-monitor-agent | 1.17.13 |
| tp-dp-license-file | 1.17.0 |
| tp-cp-proxy | 1.17.4 |
