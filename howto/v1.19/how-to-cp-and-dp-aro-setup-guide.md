---
layout: default
title: TIBCO Platform 1.19.0 CP and DP Setup Overlay on ARO
---

# TIBCO Platform 1.19.0 CP and DP Setup Overlay on ARO

Use this guide as the 1.19.0 overlay for the common ARO CP+DP setup. The base ARO cluster preparation, Azure environment, SCC configuration, PostgreSQL, Azure DNS, certificates, and OpenShift Router setup remain in the shared [CP and DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide).

1.19.0 is the mandatory intermediate step between 1.18.0 and the current 1.20.0 release. For new installations go straight to the [1.20.0 overlay](../v1.20/how-to-cp-and-dp-aro-setup-guide).

## Start Here

1. Complete the shared baseline: [shared ARO CP + DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide).
2. Use 1.18.0 as the direct upgrade source: [1.18.0 release notes](../../releases/v1.18.0).
3. Apply the 1.19.0-specific changes below, then continue with the [1.20.0 overlay](../v1.20/how-to-cp-and-dp-aro-setup-guide).

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.19.0 Chart Versions

From the 1.19.0 artifact manifests in the official `tp-helm-charts` repository.

| Area | Chart | Version |
|------|-------|---------|
| Control Plane | `tibco-cp-base` | `1.19.0` |
| Control Plane | `tp-cp-proxy` | `1.19.1` |
| Control Plane | `artifactmanager` | `1.19.4` |
| Control Plane | `o11yservice` | `1.19.16` |
| Control Plane | `tp-dp-monitor-agent` | `1.19.11` |
| Control Plane | `jaeger` | `4.8.2` |
| Data Plane | `dp-configure-namespace` | `1.19.10` |
| Data Plane | `dp-core-infrastructure` | `1.19.5` |
| BW | `tibco-cp-bw` | `1.19.0` |
| BW | `bwprovisioner` / `bw5provisioner` | `1.19.7` |
| BW | `dp-bwce-app` / `dp-bw5ce-app` | `1.19.6` |
| Flogo | `tibco-cp-flogo` | `1.19.0` |
| Flogo | `flogoprovisioner` | `1.19.11` |
| Flogo | `dp-flogo-app` | `1.19.13` |
| Developer Hub | `tibco-cp-devhub` | `1.19.0` |
| Developer Hub | `tibco-developer-hub` | `1.19.8` |
| Hawk | `tibco-cp-hawk` / `tp-dp-hawk-console` | `1.19.23` |
| Messaging | `tibco-cp-messaging` / `msg-ems-tp` / `msg-activespaces-tp` | `1.19.23` |
| MCP | `tp-dp-infra-mcp-server` | `1.19.0` |

## ARO Changes from 1.18.0

### Control Plane Base Chart

Verify the SCC grant, then upgrade:

```bash
export CP_TIBCO_CP_BASE_VERSION="1.19.0"

oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${CP_INSTANCE_ID}-ns:default

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-base ${HELM_URL}/tibco-cp-base \
  --labels layer=1 \
  --version "${CP_TIBCO_CP_BASE_VERSION}" \
  -f ${CP_VALUES_FILE}
```

Or run the assistant from `tp-helm-charts`, which validates that the release is `deployed` at `app_version` 1.18.0:

```bash
cd tp-helm-charts/scripts/1.19.0 && ./upgrade.sh
```

### Remove `createDeprecatedPolicies`

`tibco-cp-base` 1.19.0 removes `global.tibco.networkPolicy.createDeprecatedPolicies` and the deprecated policy templates. Delete the key from `tibco-cp-base-*.yaml`:

```yaml
global:
  tibco:
    networkPolicy:
      # createDeprecatedPolicies: true   # REMOVED in 1.19.0
      createClusterScopePolicies: true
```

The upgrade assistant does not remove it for you.

### otel-collector Default

The chart default for `otel-collector.enabled` changes from `false` to `true` in 1.19.0 (and back to `false` in 1.20.0). The shared guide sets it explicitly to `true`. If your values file omits the key and you have no log server, add `otel-collector.enabled: false` before upgrading.

### Jaeger v2

The observability recipe moves Jaeger from chart 0.72.41 (Jaeger 1.66.0) to chart 4.8.2 (Jaeger 2.19.0) and OpenTelemetry Collector to 0.156.2. Traces recorded before the upgrade appear as red dots (PCP-20148). Elasticsearch 8.15.2 and OpenSearch 2.14.0 remain the tested backends.

### Elasticsearch Log Export After Upgrade (PCP-23331)

On self-hosted Control Planes, CP service logs can stop reaching Elasticsearch after the 1.18.0 to 1.19.0 upgrade (`document_parsing_exception`, HTTP 400). Workaround:

```bash
oc edit configmap otel-services -n ${CP_INSTANCE_ID}-ns
# 1. under exporters.elasticsearch/log set   mapping: { mode: none }
# 2. remove transform/es-bodymap from service.pipelines.logs.processors
oc rollout restart deployment cp-otel-services -n ${CP_INSTANCE_ID}-ns
```

Fixed in 1.20.0.

### Gateway API on OpenShift: hybrid-proxy Route Fixed

OpenShift Routes remain the primary ingress. If you evaluate Gateway API, `tibco-cp-base` 1.19.0 changes the `hybrid-proxy` HTTPRoute template: it always renders `PathPrefix: /infra/tunnel` and only adds `PathPrefix: /` when `dnsDomain != dnsTunnelDomain` (fixes PCP-21362). With simplified DNS both `hybrid-proxy` and `router-operator` HTTPRoutes can use `*.${TP_BASE_DNS_DOMAIN}` on the same Gateway. The chart never reads `gatewayRoute.rules`, so remove the explicit rules from the 1.18 workaround. See the [1.20.0 overlay](../v1.20/how-to-cp-and-dp-aro-setup-guide#gateway-api-on-openshift-hybrid-proxy-route-fixed-since-1190) for the values snippet.

### Data Plane Infrastructure

Use the commands generated by the Control Plane UI (`dp-configure-namespace` 1.19.10, `dp-core-infrastructure` 1.19.5). `dp-configure-namespace` 1.19.10 removes `networkPolicy.createDeprecatedPolicies` and adds RBAC for the Infra MCP Server, MCP Gateway, and Spring Boot (`rbac.infraMcp`, `rbac.infraMcpClusterScoped`, `rbac.infraMcpServiceAccountName`, `rbac.infraMcpExtraRules`, `rbac.mcpGateway`, `rbac.springboot`). Grant `tp-scc` to the Data Plane service account first.

### Infra MCP Server Capability

The TIBCO Platform Infra MCP Server can be provisioned from Data Planes > Capabilities > Add Capability. It provides read-only `kubectl get/describe/logs` and `helm list/status/get/history` through the Data Plane proxy. It exists to serve TESSA, which in 1.19.0 is only available on TIBCO Operated Control Plane (US region), so it is optional for self-hosted ARO. Its service account needs the usual `tp-scc` grant.

### Flogo App-Init Resources

If Flogo app pods are slow to start on smaller machine sets, tune the new `flogoprovisioner` chart `config` values `APP_INIT_CPU_REQUEST` (100m), `APP_INIT_MEMORY_REQUEST` (100Mi), `APP_INIT_CPU_LIMIT` (200m), `APP_INIT_MEMORY_LIMIT` (400Mi).

### SCC Compatibility Notes

There are no SCC changes in 1.19.0. The `tp-scc` SCC and all service account bindings from 1.18.0 carry forward without modification.

### Developer Hub Storage

Use Azure Disk (`managed-premium`) for the Developer Hub PostgreSQL pod; Azure Files fails on `chmod` (PLTDX-1343).

### Email, DNS

Unchanged from 1.18.0: email is configured in the Platform Console (MailDev host `development-mailserver.tibco-ext.svc.cluster.local`, port `1025`), and simplified DNS uses one base domain with one wildcard certificate.

## Upgrade Checklist from 1.18.0

- [ ] Back up Helm values, Kubernetes secrets, and database state.
- [ ] `tp-scc` grants verified.
- [ ] Remove `createDeprecatedPolicies`; set `otel-collector.enabled` explicitly.
- [ ] Upgrade `tibco-cp-base` to 1.19.0.
- [ ] Upgrade BW, Flogo, Developer Hub to 1.19.0; Hawk and Messaging to 1.19.23.
- [ ] Upgrade Data Plane infrastructure (`dp-configure-namespace` 1.19.10, `dp-core-infrastructure` 1.19.5), then capabilities.
- [ ] CP logs still arrive in Elasticsearch (apply the PCP-23331 workaround if not).
- [ ] Validate HTTPRoutes if Gateway API is used.
- [ ] Continue to [1.20.0](../v1.20/how-to-cp-and-dp-aro-setup-guide).

## Known Issues to Watch on ARO

- PCP-23331: CP logs stop reaching Elasticsearch after the upgrade (workaround above).
- PCP-20148: traces older than the Jaeger v2 move show as red dots.
- PCP-19687: cards show wrong data for Data Planes still on 1.18.0 until upgraded.
- PLTDX-1343: use Azure Disk, not Azure Files, for Developer Hub PostgreSQL.
- SCC grants must be re-applied to any new service accounts created during capability provisioning.

## References

- [TIBCO Platform 1.19.0 Release Notes](../../releases/v1.19.0)
- [TIBCO Platform 1.19.0 Quick Reference](./QUICK-REFERENCE)
- [TIBCO Platform 1.20.0 Setup Overlay](../v1.20/how-to-cp-and-dp-aro-setup-guide)
- [Shared ARO CP + DP Setup Guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide)
- [Troubleshooting Guide](../troubleshooting)
- [TIBCO Platform Control Plane 1.19.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Default.htm)
- [Official 1.19.0 New Features](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.19.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
