You are helping validate and set up all prerequisites for a TIBCO Platform deployment on Azure Red Hat OpenShift (ARO). Work through the steps below methodically, running each verification command, reporting the result, and fixing any gaps before moving on.

## Reference
Read `howto/prerequisites-checklist-for-customer.md` for the full requirements list. This skill focuses on the technical setup that must be complete before running `tibco-provision-cp` or `tibco-provision-cp-dp`.

## Phase 1 — Cluster Access

Verify OpenShift CLI access and cluster health:

```bash
oc whoami
oc version
oc get nodes -o wide
oc get clusterversion
```

Report: user, OCP version, number of Ready nodes, and any NotReady nodes. If `oc whoami` fails, stop and ask the user to log in first (`oc login <api-url>`).

## Phase 2 — Collect Configuration

Ask the user to confirm or provide these values (check `howto/aks-aro-openshift-env-variables.sh` for defaults):

- `CP_INSTANCE_ID` — Control Plane identifier, max 5 chars, **no hyphens** (e.g., `cp1`)
- `DP_INSTANCE_ID` — Data Plane identifier (e.g., `dp1`)
- `TP_CONTAINER_REGISTRY_URL` — TIBCO JFrog registry URL (e.g., `csgprduswrepoedge.jfrog.io`)
- `TP_CONTAINER_REGISTRY_USER` / `TP_CONTAINER_REGISTRY_PASSWORD` — JFrog credentials
- `CP_DB_HOST` — PostgreSQL hostname (or `in-cluster` for local PostgreSQL)
- `CP_DB_USERNAME` / `CP_DB_PASSWORD` — PostgreSQL credentials
- `TP_BASE_DNS_DOMAIN` — Base DNS domain for the platform

Export all provided values and use them in subsequent steps.

## Phase 3 — Storage Classes

Verify that both ReadWriteMany (file) and ReadWriteOnce (block) storage classes exist:

```bash
oc get storageclass
```

- File storage (RWX): `azure-file` or equivalent — required for shared logs and configs
- Block storage (RWO): `managed-premium` or equivalent — required for PostgreSQL and PVCs

If neither is configured, install via the `dp-config-aro` Helm chart:

```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aro-storage tibco-platform-public/dp-config-aro \
  --set "global.tibco.createNetworkPolicy=false"
```

## Phase 4 — Security Context Constraints (SCC)

Check if `tp-scc` exists:

```bash
oc get scc tp-scc 2>/dev/null && echo "tp-scc EXISTS" || echo "tp-scc MISSING"
```

If missing, create it:

```bash
oc apply -f - <<EOF
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: tp-scc
priority: 10
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: false
allowPrivilegedContainer: false
allowedCapabilities:
- NET_BIND_SERVICE
fsGroup:
  type: RunAsAny
readOnlyRootFilesystem: false
requiredDropCapabilities:
- ALL
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
seccompProfiles:
- runtime/default
supplementalGroups:
  type: RunAsAny
volumes:
- configMap
- csi
- downwardAPI
- emptyDir
- ephemeral
- persistentVolumeClaim
- projected
- secret
EOF
```

## Phase 5 — Control Plane Namespace and Service Account

Create the CP namespace with required labels:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF

oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns 2>/dev/null || echo "SA already exists"
```

Grant `tp-scc` — this step is critical and must run before any Helm install:

```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

Verify:
```bash
oc describe scc tp-scc | grep -A 10 "Users:"
```

## Phase 6 — Container Registry Access

Test that the cluster can pull from the TIBCO JFrog registry:

```bash
curl -u "${TP_CONTAINER_REGISTRY_USER}:${TP_CONTAINER_REGISTRY_PASSWORD}" \
  -s -o /dev/null -w "%{http_code}" \
  https://${TP_CONTAINER_REGISTRY_URL}/v2/_catalog
```

HTTP 200 = access OK. If it returns 401/403, the credentials are wrong.

Create the image pull secret in the CP namespace:

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="${TP_CONTAINER_REGISTRY_URL}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USER}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --docker-email="platform@company.com" \
  -n ${CP_INSTANCE_ID}-ns \
  --dry-run=client -o yaml | oc apply -f -
```

## Phase 7 — Kubernetes Secrets

Generate and create the required secrets:

```bash
# Session keys
TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY} \
  --dry-run=client -o yaml | oc apply -f -

# Encryption secret
CP_ENCRYPTION_SECRET=$(openssl rand -base64 32)
kubectl create secret generic cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns \
  --from-literal=ENCRYPTION_KEY=${CP_ENCRYPTION_SECRET} \
  --dry-run=client -o yaml | oc apply -f -

# Database credentials
kubectl create secret generic ${CP_INSTANCE_ID}-provider-cp-database \
  -n ${CP_INSTANCE_ID}-ns \
  --from-literal=db_username="${CP_DB_USERNAME}" \
  --from-literal=db_password="${CP_DB_PASSWORD}" \
  --dry-run=client -o yaml | oc apply -f -
```

Verify all secrets exist:

```bash
oc get secrets -n ${CP_INSTANCE_ID}-ns \
  | grep -E "tibco-container-registry-credentials|session-keys|cporch-encryption|database"
```

## Phase 8 — Helm Repository

Add the TIBCO Helm repository:

```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update
helm search repo tibco-platform-public/tibco-cp-base --versions | head -5
```

## Phase 9 — OpenShift Router Wildcard (Required for CP Routes)

Check if the default ingress controller allows wildcard routes:

```bash
oc get ingresscontroller default -n openshift-ingress-operator \
  -o jsonpath='{.spec.routeAdmission}' | python3 -m json.tool 2>/dev/null || \
oc get ingresscontroller default -n openshift-ingress-operator \
  -o yaml | grep -A5 routeAdmission
```

If `wildcardPolicy` is not set to `WildcardsAllowed`, patch it:

```bash
oc patch ingresscontroller default -n openshift-ingress-operator \
  --type=merge --patch='{"spec":{"routeAdmission":{"wildcardPolicy":"WildcardsAllowed"}}}'
```

## Phase 10 — Final Checklist Summary

Run a final summary check and report pass/fail for each item:

```bash
echo "=== Namespace ===" && oc get namespace ${CP_INSTANCE_ID}-ns
echo "=== Service Account ===" && oc get sa ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
echo "=== SCC ===" && oc get scc tp-scc
echo "=== SCC Binding ===" && oc describe scc tp-scc | grep ${CP_INSTANCE_ID}
echo "=== Secrets ===" && oc get secrets -n ${CP_INSTANCE_ID}-ns | grep -E "registry|session|encryption|database"
echo "=== Storage Classes ===" && oc get storageclass
echo "=== Helm Repo ===" && helm repo list | grep tibco
```

Report a clear PASS/FAIL for each prerequisite. If everything passes, the environment is ready for `tibco-provision-cp`.
