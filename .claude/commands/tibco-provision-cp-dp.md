You are helping deploy TIBCO Platform Control Plane **and** Data Plane on Azure Red Hat OpenShift (ARO). This skill assumes Control Plane is already installed (via `tibco-provision-cp`). It adds the Data Plane components on top of an existing CP deployment in the same cluster.

## Before You Start

Verify Control Plane is healthy:

```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns
helm list -n ${CP_INSTANCE_ID}-ns
```

Confirm these environment values are set:
```bash
echo "CP_INSTANCE_ID=${CP_INSTANCE_ID}"
echo "DP_INSTANCE_ID=${DP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
```

## Step 1 — Create Data Plane Namespace

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${DP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/dataplane-id: ${DP_INSTANCE_ID}
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
```

Grant `tp-scc` to the Data Plane namespace service accounts — required for DP workloads on ARO:

```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_INSTANCE_ID}-ns:default
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_INSTANCE_ID}-ns:${DP_INSTANCE_ID}-sa
```

Create the Data Plane service account:

```bash
oc create serviceaccount ${DP_INSTANCE_ID}-sa -n ${DP_INSTANCE_ID}-ns 2>/dev/null || echo "SA already exists"
```

## Step 2 — Create Image Pull Secret in DP Namespace

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="${TP_CONTAINER_REGISTRY_URL}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USER}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --docker-email="platform@company.com" \
  -n ${DP_INSTANCE_ID}-ns \
  --dry-run=client -o yaml | oc apply -f -
```

## Step 3 — Install dp-configure-namespace

This chart creates the initial namespace configuration required by the Data Plane:

```bash
helm upgrade --install --wait --timeout 10m \
  --create-namespace -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-configure-namespace tibco-platform-public/dp-configure-namespace \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.controlPlane.instanceId=${CP_INSTANCE_ID}" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.serviceAccount=${DP_INSTANCE_ID}-sa" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials"
```

Verify:
```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns
kubectl get configmap -n ${DP_INSTANCE_ID}-ns
```

## Step 4 — Install dp-core-infrastructure

This chart installs the core Data Plane infrastructure (routing, storage mounts, agent):

```bash
helm upgrade --install --wait --timeout 20m \
  -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-core-infrastructure tibco-platform-public/dp-core-infrastructure \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.controlPlane.instanceId=${CP_INSTANCE_ID}" \
  --set "global.tibco.controlPlane.host=https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}" \
  --set "global.tibco.controlPlane.proxyUrl=http://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.serviceAccount=${DP_INSTANCE_ID}-sa" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.tibco.platform.controlPlane.proxyUrl=http://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials" \
  --set "global.tibco.dataPlane.dnsDomain=${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}" \
  --set "ingress.className=openshift-default" \
  --set "ingress.annotations.route\\.openshift\\.io/termination=edge"
```

Monitor deployment:
```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns -w
```

## Step 5 — Register Data Plane in Control Plane

After core infrastructure is running, register the Data Plane with the Control Plane via the Admin UI:

1. Navigate to `https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}`
2. Go to **Infrastructure** → **Data Planes**
3. Click **Add Data Plane**
4. Enter:
   - **Data Plane Name**: `${DP_INSTANCE_ID}`
   - **Kubernetes Namespace**: `${DP_INSTANCE_ID}-ns`
   - **Ingress Class**: `openshift-default`
   - **DNS Domain**: `${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}`

Or use the TIBCO Platform CLI if available:
```bash
tp dp register \
  --name "${DP_INSTANCE_ID}" \
  --namespace "${DP_INSTANCE_ID}-ns" \
  --cp-url "https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}"
```

## Step 6 — Grant SCC to Capability Service Accounts

After capabilities are deployed via the Control Plane UI, their service accounts may need tp-scc grants. This can be done proactively for known SAs or reactively when pods fail:

```bash
# Grant to common capability service accounts
for sa in bwce-sa flogo-sa ems-sa; do
  oc adm policy add-scc-to-user tp-scc \
    system:serviceaccount:${DP_INSTANCE_ID}-ns:${sa} 2>/dev/null || true
done
```

Monitor for SCC-related failures:
```bash
oc get events -n ${DP_INSTANCE_ID}-ns \
  --field-selector reason=Failed | grep -i "scc\|security\|permission"
```

## Step 7 — Verify Data Plane

```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns
kubectl get pvc -n ${DP_INSTANCE_ID}-ns
oc get routes -n ${DP_INSTANCE_ID}-ns
```

Check that the DP agent pod is running and connected to CP:
```bash
kubectl logs -n ${DP_INSTANCE_ID}-ns \
  $(kubectl get pods -n ${DP_INSTANCE_ID}-ns -l app=dp-agent -o name | head -1) \
  --tail=50 | grep -E "connected|registered|error" | tail -20
```

## Step 8 — DNS Verification

Verify DP domain resolves:
```bash
nslookup services.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN} 2>/dev/null || \
  dig +short services.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}
```

## Troubleshooting

**Cross-namespace DNS failures** (Flogo/O11y pods can't reach CP): Add `proxyUrl` to DP Helm values:
```bash
helm upgrade ${DP_INSTANCE_ID}-dp-core-infrastructure tibco-platform-public/dp-core-infrastructure \
  -n ${DP_INSTANCE_ID}-ns --reuse-values \
  --set "global.tibco.platform.controlPlane.proxyUrl=http://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}"
```

**BackoffLimitExceeded jobs**: Inject `global.certificates.secretName` and `global.imagePullSecrets` — these must be set even if using cert-manager auto-generated certs.

**SCC failures on new capability pods**: Run `oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_INSTANCE_ID}-ns:<sa>` for the failing pod's service account.

See `howto/troubleshooting.md` for the full ARO troubleshooting guide.
