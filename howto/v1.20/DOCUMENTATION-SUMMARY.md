---
layout: default
title: TIBCO Platform v1.20.0 Documentation Summary (ARO)
---

# TIBCO Platform v1.20.0 Documentation Summary — ARO

**Date**: September 21, 2026
**Status**: Documentation updated for the 1.20.0 release (and the skipped 1.19.0 release)

## Files Added

```text
howto/v1.19/
├── how-to-cp-and-dp-aro-setup-guide.md
├── QUICK-REFERENCE.md
└── DOCUMENTATION-SUMMARY.md

howto/v1.20/
├── how-to-cp-and-dp-aro-setup-guide.md
├── QUICK-REFERENCE.md
└── DOCUMENTATION-SUMMARY.md

releases/
├── v1.19.0.md
└── v1.20.0.md
```

## Key Changes from v1.18.0 to v1.20.0

| Area | Change | Release | ARO Impact |
|------|--------|---------|------------|
| Helm values | `global.tibco.networkPolicy.createDeprecatedPolicies` removed | 1.19.0 | Delete from `tibco-cp-base-*.yaml` before upgrading |
| Helm values | `otel-collector.enabled` default `false` -> `true` -> `false` | 1.19.0 / 1.20.0 | Set explicitly; `true` needs a reachable log server |
| Helm values | `global.tibco.disabledInfraCapabilities: [MFTADAPTER]` added | 1.20.0 | MFT off by default; set `[]` to enable all |
| Gateway API | `hybrid-proxy` HTTPRoute renders `/infra/tunnel`; `/` only when `dnsDomain != dnsTunnelDomain` (PCP-21362 fixed) | 1.19.0 | Shared wildcard hostname with simplified DNS; OpenShift Routes remain primary |
| Observability | Jaeger v2 (chart 4.8.x), OpenTelemetry Collector 0.156.2, PromQL cards, OTLP custom headers | 1.19.0 / 1.20.0 | Old traces show as red dots (PCP-20148) |
| Rollback | Control Plane rollback via `helm rollback` | 1.20.0 | Record `helm history` before upgrading |
| Data Plane RBAC | `dp-configure-namespace` adds `rbac.infraMcp*`, `rbac.mcpGateway`, `rbac.springboot`; drops `networkPolicy.createDeprecatedPolicies` | 1.19.10 | Update saved DP install commands; grant `tp-scc` to new service accounts |
| AI / MCP | TESSA (Preview), Infra MCP Server, MCP Hub with MCP Gateway (Preview) | 1.19.0 / 1.20.0 | TESSA and MCP Hub are TIBCO Operated CP only; Infra MCP Server can be provisioned on ARO Data Planes |
| Capabilities | ActiveSpaces capability; Flogo build Jobs and app-init resources; Developer Hub Backstage 1.51.0, MCP server, MCP Catalog | 1.19.0 / 1.20.0 | Upgrade capability charts with the release |
| Ingress | NGINX Ingress Controller support removed (wording unchanged since 1.18.0) | 1.19.0 / 1.20.0 | OpenShift Router `ocp-v4.0` |
| SCC | No changes | 1.19.0 / 1.20.0 | Existing `tp-scc` bindings carry forward |
| Tooling | Upstream ARO workshop: az 2.88.0, kubectl v1.34.3, Helm v3.18.0, `oc` 4.18.17 | 1.20.0 docs | TIBCO certifies OCP 4.16.30 for the Control Plane cluster |

## Component Versions

| Component | v1.18.0 | v1.19.0 | v1.20.0 |
|-----------|---------|---------|---------|
| `tibco-cp-base` | `1.18.0` | `1.19.0` | `1.20.0` |
| `tibco-cp-bw` | `1.18.0` | `1.19.0` | `1.20.0` |
| `tibco-cp-flogo` | `1.18.0` | `1.19.0` | `1.20.0` |
| `tibco-cp-devhub` | `1.18.0` | `1.19.0` | `1.20.0` |
| `tibco-cp-hawk` | `1.18.12` | `1.19.23` | `1.20.8` |
| `tibco-developer-hub` | `1.18.12` | `1.19.8` | `1.20.8` |
| `tibco-cp-messaging` | `1.15.31` | `1.19.23` | `1.19.23` |
| `tp-cp-proxy` | `1.18.0` | `1.19.1` | `1.20.2` |
| `tp-dp-monitor-agent` | `1.18.9` | `1.19.11` | `1.20.2` |
| `o11yservice` | `1.18.13` | `1.19.16` | `1.20.5` |
| `jaeger` | `0.72.41` | `4.8.2` | `4.8.3` |
| `dp-configure-namespace` | `1.18.3` | `1.19.10` | `1.20.0` |
| `dp-core-infrastructure` | `1.18.4` | `1.19.5` | `1.20.3` |
| `tp-dp-infra-mcp-server` | n/a | `1.19.0` | `1.20.0` |
| `tp-mcp-gateway` | n/a | n/a | `1.20.0` |

## Updated Files

| File | Change |
|------|--------|
| `README.md` | Promotes 1.20.0 as current release; adds v1.19 and v1.20 sections and upgrade paths |
| `howto/v1.20/*`, `howto/v1.19/*`, `releases/v1.19.0.md`, `releases/v1.20.0.md` | New (this release) |
| `howto/how-to-cp-and-dp-openshift-aro-aks-setup-guide.md` | `CP_TIBCO_CP_BASE_VERSION` 1.20.0, Gateway API configuration rewritten for the fixed hybrid-proxy route, Data Plane example commands updated to 1.20.0 charts |
| `howto/how-to-dp-openshift-aro-aks-setup-guide.md` | Data Plane example commands updated to 1.20.0 charts; removed `createDeprecatedPolicies` |
| `howto/aks-aro-openshift-env-variables.sh` | `CP_TIBCO_CP_BASE_VERSION` 1.20.0 |
| `howto/topology-options.md` | 1.19 and 1.20 links |
| `releases/v1.18.0.md`, `howto/v1.18/QUICK-REFERENCE.md` | Status changed to previous release |

## Validation Checklist

- [ ] `tibco-cp-base` is upgraded to 1.20.0 and `helm history` shows the previous revision.
- [ ] `createDeprecatedPolicies` is absent; `otel-collector.enabled` and `disabledInfraCapabilities` are set intentionally.
- [ ] SCC grants verified for all active service accounts.
- [ ] Data Plane infrastructure at `dp-configure-namespace` 1.20.0 and `dp-core-infrastructure` 1.20.3.
- [ ] Email provider configured from the Platform Console.
- [ ] `scripts/verify-release.sh` passes for `control-plane` 1.20.0.

## Official Sources

- [TIBCO Platform Control Plane 1.20.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [Official 1.20.0 New Features](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.20.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
