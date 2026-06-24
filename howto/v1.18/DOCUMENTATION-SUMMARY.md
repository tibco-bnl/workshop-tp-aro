---
layout: default
title: TIBCO Platform v1.18.0 Documentation Summary (ARO)
---

# TIBCO Platform v1.18.0 Documentation Summary — ARO

**Date**: June 2026
**Status**: Documentation updated for 1.18.0 release

## Files Added

```text
howto/v1.18/
├── how-to-cp-and-dp-aro-setup-guide.md
├── QUICK-REFERENCE.md
└── DOCUMENTATION-SUMMARY.md

releases/
└── v1.18.0.md
```

## Key Changes from v1.17.0 to v1.18.0

| Area | 1.18.0 Change | ARO Impact |
|------|---------------|------------|
| Gateway API | Gateway API Controller support for Control Tower data planes | OpenShift Routes remain primary; evaluate Gateway API via `Other` type if Gateway API CRDs are installed (OCP 4.14+) |
| BW5/BW6 | Traefik Gateway API support and `Other` Gateway API controller option | ARO users can select `Other` for third-party Gateway API controllers |
| Flogo | Traefik Gateway API, NetScaler Gateway, and namespace-level RBAC enforcement | Review application endpoint and namespace permission behavior |
| RBAC | Namespace-level RBAC for Application Manager and Application Viewer | Inventory namespaces and update role assignments after upgrade |
| Email | Email server configuration moved to Platform Console | Remove deprecated Helm values; configure MailDev or SMTP from Console after install/upgrade |
| Alerts | Alerts Audit Trail page | Add alert audit validation to post-upgrade checks |
| Developer Hub | Self-service flows | Upgrade Developer Hub charts with the release |
| SCC | No breaking changes to SCC | Existing `tp-scc` bindings carry forward; re-grant for new capability service accounts |

## Component Versions

| Component | v1.17.0 | v1.18.0 |
|-----------|---------|---------|
| `tibco-cp-base` | `1.17.0` | `1.18.0` |
| `tibco-cp-bw` | `1.17.0` | `1.18.0` |
| `tibco-cp-flogo` | `1.17.0` | `1.18.0` |
| `tibco-cp-devhub` | `1.17.0` | `1.18.0` |
| `tibco-cp-hawk` | `1.17.x` | `1.18.12` |
| `tibco-developer-hub` | `1.17.12` | `1.18.12` |
| `tp-cp-proxy` | `1.17.4` | `1.18.0` |
| `tp-dp-monitor-agent` | `1.17.13` | `1.18.9` |
| `o11yservice` | `1.17.16` | `1.18.13` |

## ARO-Specific Updates

### Azure DNS / Simplified DNS

The 1.17.0 simplified DNS model continues unchanged in 1.18.0. Use one Azure DNS wildcard A record for `*.platform.ocp-tibco.azure.example.com` pointing to the OpenShift Router external IP. Set `global.external.dnsDomain` and `global.external.dnsTunnelDomain` to the same base domain in `tibco-cp-base` values.

### Email Server Configuration

Email configuration moves from `tibco-cp-base` Helm values to the TIBCO Platform Console. Before upgrading, remove these deprecated values from your values files:

```yaml
# Remove before upgrading to 1.18.0
global:
  external:
    emailServerType: "..."
    fromAndReplyToEmailAddress: "..."
    cronJobReportsEmailAlias: "..."
    platformEmailNotificationCcAddresses: "..."
    emailServer: {}
```

After install or upgrade, configure MailDev (or your SMTP/SES provider) in the Platform Console. `global.tibco.networkPolicy.emailServer` remains for optional egress NetworkPolicy only.

### Gateway API (Optional Evaluation)

The primary ingress mechanism for ARO remains OpenShift Routes. If Gateway API CRDs are installed in the cluster (OpenShift 4.14+ with the Gateway API feature gate enabled), capabilities can use the `Other Gateway API Controller` provisioning option. Standard ARO workshop deployments do not require Gateway API.

### SCC — No Breaking Changes

The `tp-scc` SCC and all 1.17.0 service account bindings carry forward to 1.18.0 without modification. New capability service accounts created during 1.18.0 provisioning require the usual `oc adm policy add-scc-to-user tp-scc` grant. See the [Troubleshooting Guide](../troubleshooting) for SCC-related failure resolution.

## Updated Files

The following files were modified or created for this release:

| File | Change |
|------|--------|
| `README.md` | Promotes 1.18.0 as current release; adds v1.18 version section and documentation links |
| `howto/v1.18/how-to-cp-and-dp-aro-setup-guide.md` | New 1.18.0 overlay guide (this release) |
| `howto/v1.18/QUICK-REFERENCE.md` | New 1.18.0 quick reference (this release) |
| `howto/v1.18/DOCUMENTATION-SUMMARY.md` | This file |
| `releases/v1.18.0.md` | New release notes (this release) |
| `howto/aks-aro-openshift-env-variables.sh` | Updated `CP_TIBCO_CP_BASE_VERSION` to `1.18.0`; removed deprecated email variable placeholders |

## Validation Checklist

- [ ] `tibco-cp-base` is upgraded to 1.18.0.
- [ ] Deprecated email Helm values are removed from all values files.
- [ ] Email provider is configured from the Platform Console.
- [ ] Namespace-level RBAC assignments are reviewed in the Platform Console.
- [ ] SCC grants are verified for all active service accounts.
- [ ] Alerts Audit Trail is visible and recording events.

## Official Sources

- [TIBCO Platform Control Plane 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
