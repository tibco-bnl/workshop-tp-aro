---
layout: default
title: TIBCO Platform 1.20.0 CP and DP Setup Overlay on ARO
---

# TIBCO Platform 1.20.0 CP and DP Setup Overlay on ARO

Use this guide as the 1.20.0 overlay for the common ARO CP+DP setup. The base ARO cluster preparation, Azure environment, SCC configuration, PostgreSQL, Azure DNS, certificates, and OpenShift Router setup remain in the shared [CP and DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide). Apply the differences below when deploying or upgrading to TIBCO Platform Control Plane 1.20.0.

## Start Here

1. Complete the shared baseline through ARO cluster creation, Azure infrastructure, SCC setup, storage classes, PostgreSQL, DNS, and ingress: [shared ARO CP + DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide).
2. If upgrading, 1.19.0 is the only supported direct upgrade source. From 1.18.0, apply the [1.19.0 overlay](../v1.19/how-to-cp-and-dp-aro-setup-guide) first.
3. Apply the 1.20.0-specific changes below.
4. Refresh Helm repositories:

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.20.0 Chart Versions

These versions are from the 1.20.0 artifact manifests in the official `tp-helm-charts` repository.

| Area | Chart | Version |
|------|-------|---------|
| Control Plane | `tibco-cp-base` | `1.20.0` |
| Control Plane | `tp-cp-proxy` | `1.20.2` |
| Control Plane | `artifactmanager` | `1.20.0` |
| Control Plane | `o11yservice` | `1.20.5` |
| Control Plane | `tp-dp-monitor-agent` | `1.20.2` |
| Control Plane | `jaeger` | `4.8.3` |
| Data Plane | `dp-configure-namespace` | `1.20.0` |
| Data Plane | `dp-core-infrastructure` | `1.20.3` |
| BW | `tibco-cp-bw` | `1.20.0` |
| BW | `bwprovisioner` / `bw5provisioner` | `1.20.2` |
| BW | `dp-bwce-app` / `dp-bw5ce-app` | `1.20.4` |
| Flogo | `tibco-cp-flogo` | `1.20.0` |
| Flogo | `flogoprovisioner` | `1.20.10` |
| Flogo | `dp-flogo-app` | `1.20.8` |
| Developer Hub | `tibco-cp-devhub` | `1.20.0` |
| Developer Hub | `tibco-developer-hub` | `1.20.8` |
| Hawk | `tibco-cp-hawk` / `tp-dp-hawk-console` | `1.20.8` |
| Messaging | `tibco-cp-messaging` / `msg-ems-tp` | `1.19.23` (no 1.20.0 release) |
| MCP | `tp-dp-infra-mcp-server` | `1.20.0` |
| MCP | `tp-mcp-gateway` | `1.20.0` (MCP Hub, TIBCO Operated CP only) |

## ARO Changes from 1.18.0

### Control Plane Base Chart

Set the chart version and verify the SCC grant before installing (the most common cause of pod startup failures on ARO):

```bash
export CP_TIBCO_CP_BASE_VERSION="1.20.0"

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

### Values File Changes Since 1.18.0

Review `tibco-cp-base-*.yaml` for these keys before installing or upgrading:

```yaml
global:
  tibco:
    networkPolicy:
      # REMOVED in 1.19.0 - delete this key if present
      # createDeprecatedPolicies: true
      createClusterScopePolicies: true

    # NEW in 1.20.0 (chart default shown). MFT adapter is disabled by default.
    # Set to [] to keep every mandatory infra capability enabled.
    disabledInfraCapabilities: [MFTADAPTER]

otel-collector:
  # Chart default: false in 1.18.0, true in 1.19.0, false again in 1.20.0.
  # Set it explicitly. true requires a reachable log server (audit log, CP Fluent Bit logging).
  enabled: true
```

The shared guide's generated values files already set `otel-collector.enabled: true`; make sure the Elasticsearch/OpenSearch log server from the observability guide is reachable, or set it to `false`.

### Email Server Configuration

Unchanged since 1.18.0: do not include `global.external.emailServerType`, `emailServer`, `fromAndReplyToEmailAddress`, `cronJobReportsEmailAlias`, or `platformEmailNotificationCcAddresses`. For MailDev configure the Console with host `development-mailserver.tibco-ext.svc.cluster.local`, port `1025`, TLS disabled. `global.tibco.networkPolicy.emailServer` is only an optional egress NetworkPolicy.

### Simplified DNS Continues

Use one Control Plane base domain, for example `platform.ocp-tibco.azure.example.com`, with `global.external.dnsDomain` and `global.external.dnsTunnelDomain` set to the same value, one Azure DNS wildcard record, and one wildcard certificate. Split `cp1-my` / `cp1-tunnel` domains remain supported for legacy installations.

### Gateway API on OpenShift: hybrid-proxy Route Fixed Since 1.19.0

OpenShift Routes remain the primary and recommended ingress mechanism on ARO. If you evaluate Gateway API (NGINX Gateway Fabric, or the OpenShift Gateway API where available), note that `tibco-cp-base` 1.19.0 changed the `hybrid-proxy` HTTPRoute template: it always renders `PathPrefix: /infra/tunnel` and adds `PathPrefix: /` only when `dnsDomain != dnsTunnelDomain` (fix for PCP-21362). With simplified DNS both `hybrid-proxy` and `router-operator` can attach to `*.${TP_BASE_DNS_DOMAIN}` on the same Gateway.

The chart never reads `gatewayRoute.rules` from values. Remove the explicit rules that the 1.18 workaround added:

```yaml
hybrid-proxy:
  enabled: true
  ingress:
    enabled: false
  gatewayRoute:
    enabled: true
    controllerName: ${TP_GATEWAY_CLASS}
    hostnames:
    - '*.${TP_BASE_DNS_DOMAIN}'
    parentRefs:
    - name: ${TP_GATEWAY_NAME}
      namespace: ${TP_GATEWAY_NAMESPACE}

router-operator:
  ingress:
    enabled: false
  gatewayRoute:
    enabled: true
    controllerName: ${TP_GATEWAY_CLASS}
    hostnames:
    - '*.${TP_BASE_DNS_DOMAIN}'
    parentRefs:
    - name: ${TP_GATEWAY_NAME}
      namespace: ${TP_GATEWAY_NAMESPACE}

global:
  external:
    dnsDomain: ${TP_BASE_DNS_DOMAIN}
    dnsTunnelDomain: ${TP_BASE_DNS_DOMAIN}
```

Verify:

```bash
oc get crd | grep gateway.networking.k8s.io
oc get httproute -n ${CP_INSTANCE_ID}-ns hybrid-proxy \
  -o jsonpath='{.spec.hostnames}{"  "}{.spec.rules[*].matches[*].path.value}{"\n"}'
# expected with simplified DNS: /infra/tunnel
```

### Data Plane Infrastructure

Use the commands generated by the Control Plane UI. For 1.20.0 they reference `dp-configure-namespace` 1.20.0 and `dp-core-infrastructure` 1.20.3. `dp-configure-namespace` no longer accepts `networkPolicy.createDeprecatedPolicies`; remove that `--set` from saved commands. New RBAC toggles `rbac.infraMcp`, `rbac.mcpGateway`, `rbac.springboot` default to `true`; `rbac.infraMcpClusterScoped` defaults to `false`. Grant `tp-scc` to the Data Plane service account before installing:

```bash
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${DP_INSTANCE_ID}-ns:${DP_SERVICE_ACCOUNT}
```

### Control Plane Rollback

New in 1.20.0. Record the current revision before upgrading:

```bash
helm history tibco-cp-base -n ${CP_INSTANCE_ID}-ns
```

If the upgrade fails and `global.tibco.manageDbSchema` is `true` (workshop default):

```bash
helm rollback tibco-cp-base <revision> -n ${CP_INSTANCE_ID}-ns --wait
```

If `manageDbSchema` is `false`, port-forward the PostgreSQL pod in `tibco-ext` and run `postgres-helper.bash rollbackDbSchema <chart-version>` from `tp-helm-charts/scripts/database` first. Roll back the Control Plane before upgrading any Data Plane or capability.

### SCC Compatibility Notes

There are no SCC changes in 1.19.0 or 1.20.0. The `tp-scc` SCC and all service account bindings from 1.18.0 carry forward. New capability service accounts created during provisioning (Infra MCP Server, ActiveSpaces, Flogo build Jobs) need the usual grant:

```bash
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${DP_INSTANCE_ID}-ns:<new-sa-name>
```

### Developer Hub Storage

Use Azure Disk (`managed-premium`) for the Developer Hub PostgreSQL pod; Azure Files fails on `chmod` (PLTDX-1343).

### OTLP Exporters with Custom Headers

When an OTLP exporter or query service in Data Plane Configuration > Observability needs tenant or authorization headers, add them in the new Custom Header fields. The secondary exporter supports OTLP only.

### MCP Hub, Infra MCP Server, and TESSA

MCP Hub and TESSA are TIBCO Operated Control Plane features in 1.20.0 and do not apply to a self-hosted ARO Control Plane. The Infra MCP Server can still be provisioned as a Data Plane capability (Data Planes > Capabilities > Add Capability); it exposes read-only `kubectl` and `helm` diagnostics through the Data Plane proxy and its service account needs `tp-scc`.

### Upstream ARO Tooling Changes

The upstream `tp-helm-charts` ARO workshop for 1.20.0 lists Azure CLI 2.88.0, kubectl v1.34.3, Helm v3.18.0, and `oc` 4.18.17. The highest OpenShift Container Platform version certified by TIBCO for the Control Plane cluster in 1.20.0 is 4.16.30.

## Upgrade Checklist from 1.19.0

- [ ] Back up Helm values, Kubernetes secrets, and database state; record `helm history`.
- [ ] `tp-scc` grants verified for CP and DP service accounts.
- [ ] `createDeprecatedPolicies` is absent; `otel-collector.enabled` and `disabledInfraCapabilities` are set intentionally.
- [ ] Upgrade `tibco-cp-base` to 1.20.0 (or run `scripts/1.20.0/upgrade.sh`).
- [ ] Upgrade `tibco-cp-bw`, `tibco-cp-flogo`, `tibco-cp-devhub` to 1.20.0 and `tibco-cp-hawk` to `1.20.*`; leave `tibco-cp-messaging` at 1.19.23.
- [ ] Upgrade Data Plane infrastructure (`dp-configure-namespace` 1.20.0, `dp-core-infrastructure` 1.20.3), then capabilities; do not leave capabilities behind.
- [ ] Validate HTTPRoutes if Gateway API is used.
- [ ] Run `scripts/verify-release.sh` from `tp-helm-charts` for `control-plane` 1.20.0.
- [ ] Review 1.20.0 known issues before production use.

## Known Issues to Watch on ARO

- PCP-23615: deleting a Data Plane's observability configuration fails after upgrading to 1.20.0 (no workaround).
- PCP-20148: traces older than the Jaeger v2 move show as red dots.
- BWCE-11205 / BWCE-11181: with IPv6 disabled the CP file server and BW web server fail to start; remove `listen [::]:8080;` from the tenant-integration-fileserver configmap.
- PLTDX-1343: Azure Files breaks the Developer Hub PostgreSQL pod; use Azure Disk.
- SCC grants must be re-applied to any new service accounts created during capability provisioning.

## References

- [TIBCO Platform 1.20.0 Release Notes](../../releases/v1.20.0)
- [TIBCO Platform 1.20.0 Quick Reference](./QUICK-REFERENCE)
- [TIBCO Platform 1.19.0 Setup Overlay](../v1.19/how-to-cp-and-dp-aro-setup-guide)
- [Shared ARO CP + DP Setup Guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide)
- [ARO DNS Records Guide](../how-to-add-dns-records-aro-azure)
- [Troubleshooting Guide](../troubleshooting)
- [TIBCO Platform Control Plane 1.20.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [Official 1.20.0 New Features](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.20.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
