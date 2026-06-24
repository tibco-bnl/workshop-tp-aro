---
layout: default
title: TIBCO Platform v1.18.0 Quick Reference (ARO)
---

# TIBCO Platform v1.18.0 Quick Reference — ARO

**TIBCO Platform Version**: 1.18.0 | **Platform**: Azure Red Hat OpenShift | **Status**: Current release

## Essential Commands

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform

oc get pods -n cp1-ns
helm list -n cp1-ns
oc get routes -n cp1-ns
oc get gatewayclass,gateway,httproute -A 2>/dev/null || echo "Gateway API not installed"
```

## Helm Charts

| Component | Version |
|-----------|---------|
| `tibco-cp-base` | `1.18.0` |
| `tibco-cp-bw` | `1.18.0` |
| `tibco-cp-flogo` | `1.18.0` |
| `tibco-cp-devhub` | `1.18.0` |
| `tibco-cp-hawk` | `1.18.12` |
| `tibco-developer-hub` | `1.18.12` |
| `tp-cp-proxy` | `1.18.0` |
| `tp-dp-monitor-agent` | `1.18.9` |
| `o11yservice` | `1.18.13` |

## New in v1.18.0

### Email Server Configuration

Email server settings are configured in TIBCO Platform Console in 1.18.0 — not in Helm values. For ARO workshop MailDev setups, keep the service running and configure the Console with:

| Field | Example |
|-------|---------|
| SMTP host | `development-mailserver.tibco-ext.svc.cluster.local` |
| SMTP port | `1025` |
| TLS | Disabled for MailDev |

**Remove these deprecated values from your `tibco-cp-base` values file before upgrading:**

```bash
# Check for deprecated email values
grep -E "emailServerType|fromAndReply|cronJobReports|emailServer:" ocp-tibco-cp-base-values.yaml
```

### Gateway API Checks

OpenShift Routes are the primary ingress mechanism for ARO. If the Gateway API CRDs are installed, you can evaluate Gateway API for application endpoints:

```bash
# Check if Gateway API CRDs are present
oc get crd | grep gateway.networking.k8s.io

# Check GatewayClass, Gateway, and HTTPRoute objects
oc get gatewayclass
oc get gateway -A
oc get httproute -A
oc describe gatewayclass <gateway-class-name>
```

Use this when testing Gateway API endpoint exposure for BW5, BW6, or Flogo capabilities.

### Namespace-Level RBAC Checks

```bash
oc get namespaces
oc get rolebinding,clusterrolebinding -A | grep -i tibco
```

After upgrade, review Application Manager and Application Viewer role assignments in the TIBCO Platform Console — namespace-level access is explicit in 1.18.0.

### Alert Audit Trail

After configuring alerts, validate audit trail entries from the Console UI and confirm alert pods are healthy:

```bash
oc get pods -n cp1-ns | grep -i alert
oc logs -n cp1-ns -l app=alerts-service --tail=100
oc get events -n cp1-ns --sort-by='.lastTimestamp' | grep -i alert
```

### SCC Status (ARO-Specific)

Verify SCC bindings are in place before any Helm install or upgrade:

```bash
oc describe scc tp-scc | grep -A 10 "Users:"
oc adm policy who-can use scc tp-scc
```

Grant SCC to new service accounts created during 1.18.0 capability provisioning:

```bash
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${DP_INSTANCE_ID}-ns:<new-sa-name>
```

## OpenShift Routes

```bash
# List all Control Plane routes
oc get routes -n cp1-ns

# List all Data Plane routes
oc get routes -n dp1-ns

# Get route URL
oc get route -n cp1-ns -o jsonpath='{.items[*].spec.host}' | tr ' ' '\n'

# Check route TLS termination
oc get routes -n cp1-ns -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.tls.termination}{"\n"}{end}'
```

## Upgrade Order

1. Back up Helm values and database state.
2. Remove deprecated email Helm values.
3. Upgrade Control Plane infrastructure (`tibco-cp-base` → 1.18.0).
4. Upgrade Data Plane components.
5. Upgrade BW, Flogo, Developer Hub, Hawk, and other capabilities.
6. Configure email in the TIBCO Platform Console.
7. Re-check namespace-level RBAC and Gateway API endpoints (if used).

## ARO vs AKS Key Differences

| Feature | AKS | ARO |
|---------|-----|-----|
| CLI tool | `kubectl` | `oc` |
| Ingress | Kubernetes `Ingress` | OpenShift `Route` |
| List routes | `kubectl get ingress -A` | `oc get routes -A` |
| Storage (block) | `managed-premium` | `managed-premium` |
| Storage (file) | `azurefile-premium` | `azurefile` |
| Security | Pod Security Admission | Security Context Constraints (`tp-scc`) |
| SCC grant | N/A | `oc adm policy add-scc-to-user tp-scc ...` |
| Create route | `kubectl create ingress` | `oc create route edge` |

## Cluster Health

```bash
# OpenShift version and cluster info
oc version
oc cluster-info

# Node status
oc get nodes -o wide

# Cluster operators
oc get clusteroperators

# Check pod status across namespaces
oc get pods -n cp1-ns
oc get pods -n dp1-ns
oc get events -n cp1-ns --sort-by='.lastTimestamp'
```

## Official References

- [TIBCO Platform 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [ARO Documentation](https://docs.microsoft.com/en-us/azure/openshift/)
