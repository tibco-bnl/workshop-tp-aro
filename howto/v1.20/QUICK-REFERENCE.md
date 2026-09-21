---
layout: default
title: TIBCO Platform v1.20.0 Quick Reference (ARO)
---

# TIBCO Platform v1.20.0 Quick Reference — ARO

**TIBCO Platform Version**: 1.20.0 | **Platform**: Azure Red Hat OpenShift | **Status**: Current release

## Essential Commands

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform

oc get pods -n cp1-ns
helm list -n cp1-ns
helm history tibco-cp-base -n cp1-ns            # keep for rollback
oc get routes -n cp1-ns
oc get gatewayclass,gateway,httproute -A 2>/dev/null || echo "Gateway API not installed"
```

## Helm Charts

| Component | Version |
|-----------|---------|
| `tibco-cp-base` | `1.20.0` |
| `tibco-cp-bw` | `1.20.0` |
| `tibco-cp-flogo` | `1.20.0` |
| `tibco-cp-devhub` | `1.20.0` |
| `tibco-cp-hawk` | `1.20.8` |
| `tibco-cp-messaging` | `1.19.23` (no 1.20 release) |
| `tibco-developer-hub` | `1.20.8` |
| `tp-cp-proxy` | `1.20.2` |
| `tp-dp-monitor-agent` | `1.20.2` |
| `o11yservice` | `1.20.5` |
| `jaeger` | `4.8.3` |
| `dp-configure-namespace` | `1.20.0` |
| `dp-core-infrastructure` | `1.20.3` |

## New or Changed in v1.20.0

### Values File Checks

```bash
# Removed in 1.19.0 - must be absent
grep -n "createDeprecatedPolicies" ocp-tibco-cp-base-values.yaml && echo "REMOVE this key"
# Chart default is false in 1.20.0 - set explicitly
yq '.["otel-collector"].enabled' ocp-tibco-cp-base-values.yaml
# New in 1.20.0 (chart default [MFTADAPTER])
yq '.global.tibco.disabledInfraCapabilities' ocp-tibco-cp-base-values.yaml
```

### Control Plane Rollback

```bash
helm history tibco-cp-base -n cp1-ns
helm rollback tibco-cp-base <revision> -n cp1-ns --wait      # manageDbSchema: true
# manageDbSchema: false -> port-forward postgres in tibco-ext, run
#   postgres-helper.bash rollbackDbSchema <chart-version>, then helm rollback
```

### Gateway API Checks (hybrid-proxy route fixed since 1.19.0)

```bash
oc get crd | grep gateway.networking.k8s.io
oc get httproute -n cp1-ns hybrid-proxy \
  -o jsonpath='{.spec.hostnames}{"  "}{.spec.rules[*].matches[*].path.value}{"\n"}'
# simplified DNS expected: ["*.<base-domain>"]  /infra/tunnel
```

### SCC Status (ARO-Specific)

```bash
oc describe scc tp-scc | grep -A 10 "Users:"
oc adm policy who-can use scc tp-scc
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_INSTANCE_ID}-ns:<new-sa-name>
```

### Namespace-Level RBAC and MCP RBAC

```bash
oc get namespaces
oc get rolebinding,clusterrolebinding -A | grep -i tibco
oc get role,clusterrole -A | grep -i "infra-mcp\|mcp-gateway"
```

### Email Server Configuration

Configured in the Platform Console (since 1.18.0). MailDev: host `development-mailserver.tibco-ext.svc.cluster.local`, port `1025`, TLS disabled.

## OpenShift Routes

```bash
oc get routes -n cp1-ns
oc get routes -n dp1-ns
oc get route -n cp1-ns -o jsonpath='{.items[*].spec.host}' | tr ' ' '\n'
```

## Upgrade Order (from 1.19.0)

1. Back up Helm values, secrets, and database state; record `helm history`.
2. Verify `tp-scc` grants.
3. Upgrade `tibco-cp-base` to 1.20.0 (`scripts/1.20.0/upgrade.sh` or `helm upgrade --version 1.20.0`).
4. Upgrade BW, Flogo, Developer Hub to 1.20.0 and Hawk to `1.20.*`.
5. Upgrade Data Plane infrastructure from the Control Plane UI, then capabilities.
6. Re-check Gateway API endpoints (if used), namespace RBAC, and observability cards.
7. Validate with `scripts/verify-release.sh` (`CHECK_RELEASE_FOLDER=control-plane`, `CHECK_RELEASE_VERSION=1.20.0`).

From 1.18.0, upgrade to 1.19.0 first: [1.19.0 quick reference](../v1.19/QUICK-REFERENCE).

## ARO vs AKS Key Differences

| Feature | AKS | ARO |
|---------|-----|-----|
| CLI tool | `kubectl` | `oc` |
| Ingress | Traefik `Ingress` | OpenShift `Route` |
| List routes | `kubectl get ingress -A` | `oc get routes -A` |
| Storage (block) | `managed-premium` | `managed-premium` |
| Storage (file) | `azurefile-premium` | `azurefile` |
| Security | Pod Security Admission | Security Context Constraints (`tp-scc`) |
| SCC grant | N/A | `oc adm policy add-scc-to-user tp-scc ...` |

## Known Issues Quick Check

- PCP-23615: Data Plane observability configuration cannot be deleted after the 1.20.0 upgrade.
- PLTDX-1343: use Azure Disk, not Azure Files, for the Developer Hub PostgreSQL pod.
- BWCE-11205 / BWCE-11181: IPv6 disabled breaks CP file server and BW web server.
- FLOGO-18866: use `wss://` for WebSocket public endpoints.

## Official References

- [TIBCO Platform 1.20.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [Official 1.20.0 New Features](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.20.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/known-issues.htm)
- [Control Plane Rollback](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/UserGuide/control-plane-rollback.htm)
- [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [ARO Documentation](https://docs.microsoft.com/en-us/azure/openshift/)
