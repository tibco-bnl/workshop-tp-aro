You are helping deploy the TIBCO Platform Control Plane on Azure Red Hat OpenShift (ARO). Follow these steps in order. Run each Helm command, verify the output, and report status before proceeding.

## Before You Start

Confirm that `tibco-prerequisites` has been run and all checks passed. If not, stop and run that skill first.

Source the environment file or ask the user to confirm these values are set:

```bash
echo "CP_INSTANCE_ID=${CP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
echo "CP_DB_HOST=${CP_DB_HOST}"
```

Also determine the TIBCO Platform version to install:

```bash
helm search repo tibco-platform-public/tibco-cp-base --versions | head -5
```

## Step 1 — Cert-Manager

Cert-manager manages TLS certificates for Control Plane routes.

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install --wait --timeout 10m \
  --create-namespace -n cert-manager cert-manager jetstack/cert-manager \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager
```

Verify:
```bash
kubectl get pods -n cert-manager
```

All three pods (`cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`) should be Running.

## Step 2 — External DNS (optional, if using Route 53 or Azure DNS)

Skip this step if DNS records will be managed manually. If using automatic DNS:

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

helm upgrade --install --wait --timeout 10m \
  --create-namespace -n external-dns-system external-dns external-dns/external-dns \
  --set provider=azure \
  --set azure.resourceGroup="${AZURE_DNS_RESOURCE_GROUP}" \
  --set azure.subscriptionId="${AZURE_SUBSCRIPTION_ID}"
```

## Step 3 — Metrics Server

Required for HPA (Horizontal Pod Autoscaler) in Control Plane:

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install --wait --timeout 5m \
  -n kube-system metrics-server metrics-server/metrics-server
```

Verify:
```bash
kubectl top nodes
```

## Step 4 — Prepare Helm Values

Generate the `tibco-cp-base` values. Adjust the values below for your environment:

```bash
cat > /tmp/tibco-cp-values.yaml << EOF
global:
  tibco:
    containerRegistry:
      url: ${TP_CONTAINER_REGISTRY_URL}
      username: ${TP_CONTAINER_REGISTRY_USER}
      password: ${TP_CONTAINER_REGISTRY_PASSWORD}
    serviceAccount: ${CP_INSTANCE_ID}-sa
    createNetworkPolicy: false
    enableLogging: true
    proxy:
      enabled: false
  tibco:
    platform:
      controlPlane:
        instanceId: ${CP_INSTANCE_ID}
        namespace: ${CP_INSTANCE_ID}-ns
  certificates:
    secretName: ""    # leave empty to use cert-manager auto-generated
  imagePullSecrets:
    - name: tibco-container-registry-credentials

tibco:
  controlPlane:
    baseConfig:
      cpInstanceId: ${CP_INSTANCE_ID}
      cpNamespace: ${CP_INSTANCE_ID}-ns
      serviceAccount: ${CP_INSTANCE_ID}-sa
    dnsConfig:
      baseDnsDomain: ${TP_BASE_DNS_DOMAIN}
    database:
      dbHost: ${CP_DB_HOST}
      dbPort: "5432"
      dbName: "${CP_INSTANCE_ID}postgres"
      secretRef: ${CP_INSTANCE_ID}-provider-cp-database
    sessionConfig:
      sessionKeysSecretRef: session-keys
    encryptionConfig:
      encryptionSecretRef: cporch-encryption-secret
    ingress:
      className: "openshift-default"
      annotations:
        route.openshift.io/termination: edge
EOF
```

Review the values file:
```bash
cat /tmp/tibco-cp-values.yaml
```

Ask the user to confirm the values are correct before proceeding.

## Step 5 — SCC Grant (Final Check Before Install)

This is the most common cause of CP install failure on ARO. Re-verify that `tp-scc` is granted to the service accounts in the CP namespace:

```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
oc describe scc tp-scc | grep -E "Users:|Groups:" -A 5
```

## Step 6 — Install TIBCO Control Plane

```bash
helm upgrade --install --wait --timeout 60m \
  --create-namespace -n ${CP_INSTANCE_ID}-ns \
  ${CP_INSTANCE_ID}-tibco-cp tibco-platform-public/tibco-cp-base \
  -f /tmp/tibco-cp-values.yaml
```

This will take 10-20 minutes. Monitor pod startup:

```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns -w
```

## Step 7 — Verify Deployment

Check all Control Plane pods are Running:

```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns
kubectl get pvc -n ${CP_INSTANCE_ID}-ns
kubectl get ingress -n ${CP_INSTANCE_ID}-ns 2>/dev/null || \
  oc get route -n ${CP_INSTANCE_ID}-ns
```

Check for any pods not in Running/Completed state:
```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns \
  --field-selector='status.phase!=Running,status.phase!=Succeeded'
```

If any pods are failing, check their events:
```bash
kubectl describe pod -n ${CP_INSTANCE_ID}-ns <pod-name>
kubectl logs -n ${CP_INSTANCE_ID}-ns <pod-name> --previous 2>/dev/null || \
kubectl logs -n ${CP_INSTANCE_ID}-ns <pod-name>
```

## Step 8 — Verify DNS Routes

Get the OpenShift Routes created for the Control Plane:

```bash
oc get routes -n ${CP_INSTANCE_ID}-ns
```

The routes should resolve to the OpenShift ingress router IP. Verify DNS resolution:

```bash
nslookup admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN} 2>/dev/null || \
  dig +short admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}
```

## Step 9 — Access the Control Plane

The Control Plane admin URL will be:

```
https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}
```

First-time admin login uses the bootstrap credentials. Check the Helm values or secrets for the initial admin user:

```bash
kubectl get secret -n ${CP_INSTANCE_ID}-ns | grep -i admin
kubectl get secret -n ${CP_INSTANCE_ID}-ns tibco-cp-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d
```

Report the admin URL and any credential information to the user.

## Troubleshooting

If pods fail to start due to SCC errors:
```bash
# Check pod security events
oc get events -n ${CP_INSTANCE_ID}-ns --field-selector reason=Failed | grep -i scc
# Re-grant SCC and restart failing pods
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:<sa-name>
kubectl rollout restart deployment -n ${CP_INSTANCE_ID}-ns
```

If pods fail with image pull errors, verify the pull secret:
```bash
oc get secret tibco-container-registry-credentials -n ${CP_INSTANCE_ID}-ns -o yaml | grep .dockerconfigjson
```

See `howto/troubleshooting.md` for more ARO-specific issues.
