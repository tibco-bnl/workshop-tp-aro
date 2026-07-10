---
layout: default
title: TIBCO Platform 1.18.0 CP and DP Setup Overlay on ARO
---

# TIBCO Platform 1.18.0 CP and DP Setup Overlay on ARO

Use this guide as the 1.18.0 overlay for the common ARO CP+DP setup. The base ARO cluster preparation, Azure environment, SCC configuration, PostgreSQL, Azure DNS, certificates, and OpenShift Router setup remain in the shared [CP and DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide). Apply the differences below when deploying or upgrading to TIBCO Platform Control Plane 1.18.0.

## Start Here

1. Complete the shared baseline through ARO cluster creation, Azure infrastructure, SCC setup, storage classes, PostgreSQL, DNS, and ingress: [shared ARO CP + DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide).
2. Use 1.17.0 as the direct upgrade source when upgrading an existing environment: [1.17.0 release notes](../../releases/v1.17.0).
3. Apply the 1.18.0-specific changes below.
4. Refresh Helm repositories:

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.18.0 Chart Versions

These versions are from the 1.18.0 artifacts in the official `tp-helm-charts` repository.

| Area | Chart | Version |
|------|-------|---------|
| Control Plane | `tibco-cp-base` | `1.18.0` |
| Control Plane | `tp-cp-proxy` | `1.18.0` |
| Control Plane | `artifactmanager` | `1.18.1` |
| Control Plane | `o11yservice` | `1.18.13` |
| Control Plane | `tp-dp-monitor-agent` | `1.18.9` |
| BW | `tibco-cp-bw` | `1.18.0` |
| BW | `bwprovisioner` | `1.18.4` |
| BW | `bw5provisioner` | `1.18.4` |
| BW | `dp-bwce-app` | `1.18.4` |
| BW | `dp-bw5ce-app` | `1.18.4` |
| Flogo | `tibco-cp-flogo` | `1.18.0` |
| Flogo | `flogoprovisioner` | `1.18.4` |
| Flogo | `dp-flogo-app` | `1.18.10` |
| Developer Hub | `tibco-cp-devhub` | `1.18.0` |
| Developer Hub | `tibco-developer-hub` | `1.18.12` |
| Hawk | `tibco-cp-hawk` | `1.18.12` |
| Hawk | `tp-dp-hawk-console` | `1.18.12` |

## ARO Changes from 1.17.0

### Simplified DNS Continues in 1.18.0

The simplified DNS model remains the recommended ARO pattern for 1.18.0. Use one Control Plane base domain, for example `platform.ocp-tibco.azure.example.com`, instead of separate `cp1-my` and `cp1-tunnel` base domains when your environment allows it.

Recommended 1.18.0 pattern:

- Platform Console: `https://admin.platform.ocp-tibco.azure.example.com`
- Subscription URL: `https://<hostPrefix>.platform.ocp-tibco.azure.example.com`
- Control Plane chart values: set `global.external.dnsDomain` and `global.external.dnsTunnelDomain` to the same base domain
- DNS and certificate: one Azure DNS wildcard record and one wildcard certificate for `*.platform.ocp-tibco.azure.example.com`
- Tunnel routing: handled by the `hybrid-proxy` `/infra/tunnel` route on the same base domain

Use split `cp1-my` and `cp1-tunnel` domains only for legacy installations or environments that require separate DNS/certificate ownership.

### Email Server Configuration Moves to Console

Email server configuration is moved from `tibco-cp-base` chart values to the TIBCO Platform Console UI. After a fresh install or upgrade to 1.18.0, configure the email server in the Platform Console.

**Remove these deprecated values if they exist in your values files before upgrading:**

```yaml
global:
  external:
    emailServerType: "..."
    fromAndReplyToEmailAddress: "..."
    cronJobReportsEmailAlias: "..."
    platformEmailNotificationCcAddresses: "..."
    emailServer: {}
```

For ARO workshop environments that use MailDev, keep the MailDev service running and configure the Console with:

| Field | Value |
|-------|-------|
| SMTP host | `development-mailserver.tibco-ext.svc.cluster.local` |
| SMTP port | `1025` |
| TLS | Disabled |

The `global.tibco.networkPolicy.emailServer` block in `tibco-cp-base` values is NetworkPolicy-only — it creates an optional egress rule to allow traffic to an email CIDR. It does not configure the email provider itself. Leave its CIDR empty unless you need an explicit egress allow rule.

### Control Plane Base Chart

Use the 1.18.0 chart version. The install command follows the same pattern as earlier releases:

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-base tibco-platform/tibco-cp-base \
  --labels layer=1 \
  --version "1.18.0" \
  -f ocp-tibco-cp-base-values.yaml
```

Verify the SCC grant is in place before running the Helm install — this is the most common cause of pod startup failures on ARO:

```bash
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

### Gateway API on OpenShift

1.18.0 adds Gateway API Controller support for Control Plane and Control Tower data planes. On ARO, OpenShift Routes remain the primary and recommended ingress mechanism.

If your ARO cluster has the Gateway API CRDs installed (available in OpenShift 4.14+ via the Gateway API feature gate), BW5, BW6, and Flogo capabilities can evaluate Gateway API endpoint exposure. During capability provisioning, select the `Other Gateway API Controller` type and provide the GatewayClass name of the installed controller.

For standard ARO workshops, keep OpenShift Route-based ingress for all routes. Evaluate Gateway API only when you intentionally want to migrate application endpoint exposure.

Check if Gateway API CRDs are available:

```bash
oc get crd | grep gateway.networking.k8s.io
oc get gatewayclass 2>/dev/null || echo "No GatewayClass found — Gateway API not installed"
```

### Namespace-Level RBAC

Namespace-level RBAC is introduced for Kubernetes data planes. Namespaces become Data Plane resources under Data Plane Configuration > Resources, and Application Manager/Application Viewer permissions can be scoped by capability and namespace.

Before upgrading shared ARO clusters:

- Inventory namespaces that host BW, Flogo, EMS, and other applications.
- Confirm Application Manager and Application Viewer role assignments after upgrade in the TIBCO Platform Console.
- Avoid assuming a user with application permissions can deploy into newly created namespaces unless that namespace is explicitly granted.

Verify RBAC state after upgrade:

```bash
oc get namespaces
oc get rolebinding,clusterrolebinding -A | grep -i tibco || true
```

### Alert Audit Trail

1.18.0 adds an Alerts Audit Trail page in the TIBCO Platform Console. After upgrade, validate that audit trail entries appear and that Control Plane namespace pods are healthy:

```bash
oc get pods -n ${CP_INSTANCE_ID}-ns | grep -i alert
oc logs -n ${CP_INSTANCE_ID}-ns -l app=alerts-service --tail=100
```

### Developer Hub Self-Service Flows

Developer Hub adds self-service flows for reusable platform automation. No ARO infrastructure change is required. Upgrade Developer Hub chart versions together with the Control Plane release — do not leave capability charts at 1.17.x after upgrading the Control Plane to 1.18.0.

### SCC Compatibility Notes

There are no breaking SCC changes in 1.18.0. The `tp-scc` SCC and all service account bindings from 1.17.0 carry forward without modification.

If new capability service accounts are created during provisioning, grant `tp-scc` as needed:

```bash
oc adm policy add-scc-to-user tp-scc \
  system:serviceaccount:${DP_INSTANCE_ID}-ns:<new-sa-name>
```

Refer to the [Troubleshooting Guide](../troubleshooting) for common SCC-related pod failures.

## Upgrade Checklist from 1.17.0

- [ ] Back up Helm values, Kubernetes secrets, and database state.
- [ ] Remove deprecated email Helm values (`emailServerType`, `emailServer`, etc.) from values files.
- [ ] Upgrade Control Plane infrastructure charts to 1.18.0-compatible versions.
- [ ] Upgrade Data Plane and capabilities to 1.18.0-compatible versions; do not leave capabilities behind after infrastructure upgrade.
- [ ] Configure email server in TIBCO Platform Console (MailDev or SMTP/SES).
- [ ] Review namespace-level RBAC assignments for Application Manager and Application Viewer roles.
- [ ] If using Gateway API, validate GatewayClass, Gateway, HTTPRoute, and application endpoint behavior.
- [ ] Validate Alert Audit Trail events are recorded.
- [ ] Review 1.18.0 known issues before production use.

## Known Issues to Watch on ARO

- Existing 1.17.0 Data Planes can show incorrect Integration Summary and Application Instance card data after Control Plane upgrade until the Data Plane is upgraded to 1.18.0.
- Some BW6 and Flogo known issues are capability-version dependent; upgrade the capability and application charts together.
- SCC grants must be re-applied to any new service accounts created during capability provisioning.

## References

- [TIBCO Platform 1.18.0 Release Notes](../../releases/v1.18.0)
- [TIBCO Platform 1.18.0 Quick Reference](./QUICK-REFERENCE)
- [Shared ARO CP + DP Setup Guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide)
- [ARO DNS Records Guide](../how-to-add-dns-records-aro-azure)
- [Troubleshooting Guide](../troubleshooting)
- [TIBCO Platform Control Plane 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
