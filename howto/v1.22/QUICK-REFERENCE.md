# TIBCO Platform 1.22.0 Quick Reference (ARO)

Use this page alongside the [1.22.0 release notes](../../releases/v1.22.0), the shared [ARO CP + DP setup guide](../how-to-cp-and-dp-openshift-aro-aks-setup-guide), and the [official 1.22.0 documentation](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/Default.htm).

## Upgrade sequence from 1.21.0

1. Back up PostgreSQL, Helm values, Kubernetes secrets, and record `helm history`; confirm required `tp-scc` grants remain present.
2. For custom registries, mirror the 1.22.0 images from the official artifact manifests before upgrading.
3. Run the official [1.22.0 upgrade assistant](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/1.22.0). It requires a deployed Control Plane at `app_version` 1.21.0.
4. Upgrade decoupled Control Plane capability charts using the exact artifact versions.
5. Upgrade Data Plane infrastructure and capabilities through the Control Plane UI; prefer its generated commands and validate selected ingress/Gateway API options and service-account SCC grants.
6. Verify chart versions and workload health.

The assistant requires Bash 4+, yq 4.45.4+, Helm 3.17+ and jq 1.8+ for Helm flows, and kubectl for readiness checks. Its only 1.22-specific value change is the `tp-cp-o11y` flattening: `capabilities.o11y.default` and `capabilities.o11y.withResources` become `capabilities.o11y` with `overwriteRecipe` carried over (`"false"` if unset). Review all other values and custom-registry image contents before use.

## 1.22.0 reference chart versions

| Chart | Version |
|---|---:|
| `tibco-cp-base` | 1.22.0 |
| `tibco-cp-bw` / `tibco-cp-flogo` / `tibco-cp-devhub` | 1.22.0 |
| `tibco-cp-hawk` / `tibco-cp-messaging` | 1.22.14 / 1.22.14 |
| `tibco-cp-mcp-hub` / `tp-mcp-gateway` | 1.22.0 / 1.22.4 |
| `tibco-cp-addon-eventprocessing` | 1.22.0 |
| `dp-configure-namespace` / `dp-core-infrastructure` | 1.22.3 / 1.22.5 |
| `tibco-developer-hub` | 1.22.12 |
| `tp-dp-monitor-agent` / `o11yservice` | 1.22.5 / 1.22.29 |
| `jaeger` / `opentelemetry-collector` | 4.8.5 / 0.156.5 |
| EMS / ActiveSpaces charts | `msg-ems-tp` 1.22.14 / `msg-activespaces-tp` 1.22.14 |

Consult all 1.22.0 artifact files for charts not listed here and for the exact images to mirror.

## 1.22 operations to account for

- NGINX Ingress Controller usage is removed from TIBCO Operated Control Plane; keep the OpenShift default router on ARO.
- Application Operator permission (start/stop/restart/scale, environment variables; no delete) can be scoped to a namespace in a Data Plane. BW5 and BW6 Containers support it.
- Application logs (history as text/CSV, real-time as text) can be downloaded from the application details page. After a Control Plane upgrade, this fails with "404 page not found" for apps on a Data Plane not yet upgraded to 1.22 (PCP-25998).
- Infrastructure component CPU, memory, and storage can be overridden in a YAML editor on the Data Plane configuration page. Customized observability values currently reset when the observability resource configuration is updated (PCP-26766).
- BW5/BW6 Containers alert rules gain **Instance Count** and **App Status** categories.
- The Data Plane registration form is unchanged from 1.21: hybrid connectivity is enabled by default; if you disable it, set **Reachable DP URL** to the Data Plane `cpdpproxy` service URL (for example, `http://cpdpproxy.<dp-ns>.svc.cluster.local`) only when that endpoint resolves and is reachable from the Control Plane. It is not the OpenShift router domain; do not assume cross-cluster `*.svc.cluster.local` DNS works. See the [official 1.22 registration guide](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/UserGuide/registering-an-existing-kubernetes-cluster.htm).
- Select the OpenShift Router route resource for this ARO example when offered by the form; validate controller service DNS, generated host/FQDN, and `tp-scc` grants.
- When provisioning a capability that supports Gateway API endpoint exposure, choose **Other** for an unlisted controller implementing Kubernetes Gateway API, then provide the actual `GatewayClass` and Gateway details; verify required CRDs and capability features before provisioning.
- For custom-registry Kubernetes Secret authentication, create the credential Secret in every applicable Data Plane namespace before generating/applying the commands.
- Retain the OpenShift default router and validate `tp-scc` grants for the service accounts used by each capability.
- Optional after upgrade: remove the stale `o11y-exporter.yaml` from the Control Plane PVC (see the [release notes](../../releases/v1.22.0#upgrade-from-1210)).

## Known issue checks

- PCP-26766: customized observability environment values reset after updating the observability resource configuration; no workaround.
- PCP-25998: log download 404 on a not-yet-upgraded Data Plane after the Control Plane upgrade; upgrade the Data Plane and its observability capability.
- PCP-27651: Capability Provisioner and Fluent Bit sidecar error logs after upgrading Data Plane infrastructure to 1.22.0 (BW6 Containers); no workaround documented.
- PCP-9344: upgrade capabilities after upgrading infrastructure components.

Review the [official known issues](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/Release-Notes/known-issues.htm) before upgrading.
