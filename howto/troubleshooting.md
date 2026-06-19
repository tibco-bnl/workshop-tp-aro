---
layout: default
title: TIBCO Platform on ARO - Troubleshooting Guide
---

# 🔧 TIBCO Platform on ARO — Troubleshooting Guide

> 📋 **Scope**: Azure Red Hat OpenShift (ARO) — Control Plane & Data Plane deployments  
> 🩺 **Purpose**: Real deployment issues with root cause analysis and verified step-by-step resolutions  
> 🔗 **Back to**: [Main README](../README)

Each issue in this guide follows a consistent **Symptom → Root Cause → Diagnosis → Solution** pattern so you can confirm you have the same problem before applying the fix.

---

## 📋 Issues at a Glance

| # | Issue | Component | Severity |
|---|-------|-----------|----------|
| [1](#1--scc-permission-error--pods-forbidden-on-aro) | SCC Permission Error — Pods Forbidden on ARO | OpenShift SCC | 🔴 Deployment Blocker |
| [2](#2--o11y-service--flogo-provisioner-cross-namespace-crash-loops) | O11y / Flogo Provisioner Cross-Namespace Crash Loops | Data Plane DNS | 🔴 Deployment Blocker |
| [3](#3--control-plane-proxy-registration-failure-backofflimitexceeded) | Control Plane Proxy Registration Failure | Control Plane, Air-Gapped | 🔴 Deployment Blocker |
| [4](#4--businessworks-plugin-extraction-crash--image-layer-corruption) | BusinessWorks Plugin Extraction Crash — Image Layer Corruption | BW6, Custom Registry | 🔴 Deployment Blocker |

---

## 1. 🔐 SCC Permission Error — Pods Forbidden on ARO

**[📖 Related Guide: Customer Prerequisites Checklist](./prerequisites-checklist-for-customer)**

### 🚨 Symptom

After deploying the `tibco-cp-base` Helm chart on ARO, pods fail to start with an SCC validation error:

```
pods "tp-cp-orchestrator-669d64876b-" is forbidden: unable to validate against any security context constraint:
[provider "tp-scc": Forbidden: not usable by user or serviceaccount,
 provider "anyuid": Forbidden: not usable by user or serviceaccount,
 provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: []int64{1000}: 1000 is not an allowed group]
```

### 🔍 Root Cause

The service accounts in the Control Plane namespace do not have permission to use the `tp-scc` Security Context Constraint. Even if `tp-scc` was created successfully, it must be **explicitly granted** to the service accounts before the chart is deployed. This step is easy to miss and causes an immediate deployment failure.

### 🩺 Diagnosis

```bash
# Verify the SCC exists
oc get scc tp-scc

# Check which service accounts currently have access to tp-scc
oc describe scc tp-scc | grep -A 20 "Users:"

# Inspect pod events for the exact SCC error
oc get events -n ${CP_INSTANCE_ID}-ns --sort-by='.lastTimestamp' | tail -20
```

### ✅ Solution

**Step 1 — Grant `tp-scc` to the Control Plane service accounts:**

```bash
export CP_INSTANCE_ID="cp1"  # replace with your actual Control Plane instance ID

oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

Expected output for each command:
```
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:tp-scc added: "cp1-sa"
```

**Step 2 — If pods are already stuck, delete them to force recreation:**

```bash
oc delete pods --all -n ${CP_INSTANCE_ID}-ns
```

**Step 3 — Verify the fix:**

```bash
# Watch pods come back up
oc get pods -n ${CP_INSTANCE_ID}-ns -w

# Confirm the pod is running under tp-scc
POD_NAME=$(oc get pods -n ${CP_INSTANCE_ID}-ns -l app=cp-orchestrator -o jsonpath='{.items[0].metadata.name}')
oc describe pod $POD_NAME -n ${CP_INSTANCE_ID}-ns | grep "openshift.io/scc"
```

Expected output:
```
openshift.io/scc: tp-scc
```

### 🛡️ Prevention — Pre-Installation Checklist

> **⚠️ Important**: Always complete this sequence **before** deploying `tibco-cp-base`. Deploying the chart before granting SCC permissions will immediately fail.

The correct order is:

- [ ] **1. Create the namespace** with the required platform label
- [ ] **2. Create the service account** (`${CP_INSTANCE_ID}-sa`)
- [ ] **3. Create `tp-scc`** (if it does not already exist)
- [ ] **4. Grant `tp-scc` to service accounts** ← Most commonly missed step
- [ ] **5. Create required secrets**
- [ ] **6. Deploy the Helm chart**

```bash
# 1. Create namespace
oc apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)

# 2. Create service account
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns

# 3. Create tp-scc (if it does not exist)
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

# 4. Grant SCC permissions — CRITICAL, do not skip
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

> **ℹ️ Note**: If the chart uses additional service accounts, grant `tp-scc` to each:
> ```bash
> for sa in $(oc get serviceaccounts -n ${CP_INSTANCE_ID}-ns -o jsonpath='{.items[*].metadata.name}'); do
>   oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:$sa
> done
> ```

---

## 2. 🌐 O11y Service / Flogo Provisioner Cross-Namespace Crash Loops

### 🚨 Symptom

The Observability service (`o11y-service`) and `flogo-provisioner` pods crash immediately after deployment with a Go panic:

```
panic: Cannot start service without OAuth2 client after 5 attempts. Last error: ...
dial tcp: lookup cp-proxy.tibcoplatform-dp-dev.svc.cluster.local on 10.222.0.10:53: no such host
```

### 🔍 Root Cause

The Data Plane sub-chart templates default to appending the **Data Plane's own namespace** (`tibcoplatform-dp-dev`) to all cross-namespace endpoint lookups. The pods attempt to find `cp-proxy` inside the Data Plane namespace — but `cp-proxy` lives exclusively in the **Control Plane namespace** (`tibcoplatform-cp-dev`). The DNS query returns `NXDOMAIN` and the service cannot start.

### 🩺 Diagnosis

```bash
# 1. Check the runtime panic in the pod logs
oc logs deployment/o11y-service -n tibcoplatform-dp-dev

# 2. Confirm DNS resolution failure from within the Data Plane namespace
oc run dns-test --rm -i --tty --image=quay.io/openshift/origin-cli -n tibcoplatform-dp-dev -- \
  nslookup cp-proxy.tibcoplatform-dp-dev.svc.cluster.local
```

> **Expected result**: `NXDOMAIN` — confirms the wrong namespace suffix is being appended to the `cp-proxy` hostname.

### ✅ Solution

Add explicit cross-namespace routing values to the **Data Plane** Helm configuration to force routing to the Control Plane namespace:

```yaml
global:
  tibco:
    platform:
      controlPlane:
        proxyUrl: "http://cp-proxy.tibcoplatform-cp-dev.svc.cluster.local"
  cpProxy:
    namespace: "tibcoplatform-cp-dev"
```

> **ℹ️ Note**: Replace `tibcoplatform-cp-dev` with your actual Control Plane namespace.

After updating the values, perform a `helm upgrade` on the Data Plane chart and the pods will resolve `cp-proxy` correctly.

---

## 3. 🔗 Control Plane Proxy Registration Failure (BackoffLimitExceeded)

### 🚨 Symptom

The `tibco-cp-proxy` Helm installation fails and rolls back. The post-install hook job exhausts its retry limit:

```
* job cp-proxy-client-credential-creation failed: BackoffLimitExceeded
```

Inspecting the failed job pod logs reveals:

```
x509: certificate signed by unknown authority
```

### 🔍 Root Cause

The `cp-proxy-client-credential-creation` job runs a short-lived utility pod that registers OAuth2 credentials with the Identity Management (IDM) engine over HTTPS. In air-gapped or private-CA environments it fails for two reasons:

- ✗ **Missing CA trust** — the pod does not trust the cluster's local OpenShift router certificate (self-signed or private CA)
- ✗ **Missing image pull credentials** — the pod cannot fetch its own runtime utility image from the internal registry

### 🩺 Diagnosis

```bash
# 1. Find the failed job pod (act quickly — it may be evicted soon)
oc get pods -n tibcoplatform-cp-dev | grep cp-proxy-client

# 2. Read the logs before the pod is evicted
oc logs pod/cp-proxy-client-credential-creation-xxxx -n tibcoplatform-cp-dev
# Look for: x509: certificate signed by unknown authority
```

### ✅ Solution

**Step 1 — Remove the stale failed job** so Helm can cleanly re-create it on the next install:

```bash
oc delete job cp-proxy-client-credential-creation -n tibcoplatform-cp-dev
```

**Step 2 — Inject the CA bundle and image pull credentials** into the Control Plane chart values before retrying:

```yaml
global:
  certificates:
    secretName: "tp-dataplane-custom-certs"      # Kubernetes secret containing your CA bundle
  imagePullSecrets:
    - name: "tibco-container-registry-credentials"
```

**Step 3 — Re-run the Helm install.** The job pod will now trust the cluster CA and have credentials to pull its runtime image.

---

## 4. 📦 BusinessWorks Plugin Extraction Crash — Image Layer Corruption

**[📖 Related: Custom Registry Prerequisites](./prerequisites-checklist-for-customer#custom--internal-registry-air-gapped-environments)**

### 🚨 Symptom

During BusinessWorks capability deployment, plugin extraction jobs (`tp-cp-bwce-utilities-plugins-extract-job-e` and `-job-g`) crash for plugins such as **AS2, CICS**, and **AP**:

```
======= Extracting '.../tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0' docker image =======
tar: invalid tar header checksum
```

> **⚠️ This error occurs when images were mirrored to a custom or internal registry using standard `podman push` or `docker push` before installation.**  
> If you are planning to push images to a custom registry, read the [Solution](#-solution-1) section **before** running your image migration.

### 🔍 Root Cause

Standard `podman push` and `docker push` decompress and **re-compress** image layers locally during the push process. This silently changes the GZIP DEFLATE block type header:

| Header signature | DEFLATE type | Meaning |
|---|---|---|
| `ecf2` | `BTYPE=01` Fixed Huffman | ✅ Original TIBCO layer — extraction succeeds |
| `00ff` | `BTYPE=00` Non-compressed / Stored block | ❌ Re-compressed by push — extraction fails |

The legacy `tar` binary inside the TIBCO `bwce-utilities` extraction container cannot handle stored blocks (`BTYPE=00`) and throws a checksum error.

### 🩺 Diagnosis

You can verify whether an image was re-compressed by inspecting the raw GZIP header of a layer blob from the registry:

```bash
# 1. Get the cluster access token
TOKEN=$(oc whoami -t)
REGISTRY="default-route-openshift-image-registry.apps.<your-cluster-domain>"

# 2. Fetch the layer digest from the image manifest
DIGEST=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://$REGISTRY/v2/tibcoplatform-cp-dev/tci-bw-plugin-ap/manifests/5.0.0.v11.2-tci-2.0" \
  | jq -r '.layers[0].digest')

# 3. Download the raw layer blob
curl -s -k -H "Authorization: Bearer $TOKEN" \
  "https://$REGISTRY/v2/tibcoplatform-cp-dev/tci-bw-plugin-ap/blobs/$DIGEST" \
  -o /tmp/bw_test.tar.gz

# 4. Inspect the first 16 bytes of the GZIP header
xxd /tmp/bw_test.tar.gz | head -1
```

**Interpreting the result:**

| Output | Signature | Status |
|--------|-----------|--------|
| `1f8b 0800 0000 0000 00ff ecf2 638c ...` | `ecf2` = original Fixed Huffman | ✅ Image is intact — extraction will succeed |
| `1f8b 0800 0009 6e88 00ff 00ff ff00 ...` | `00ff` = re-compressed Stored block | ❌ Image is corrupted — re-mirror before proceeding |

### ✅ Solution

Use a **registry-to-registry copy tool** that streams layer blobs directly between registries without local decompression. Three options are available — choose the one that fits your environment:

| Tool | Best For | Requires |
|------|----------|----------|
| `docker buildx imagetools` | Docker environments | Docker Desktop or buildx plugin |
| `skopeo copy --format v2s2` | Podman / OpenShift native | `skopeo` package (included in RHEL/Fedora) |
| `oc mirror` | Air-gapped bulk migration | OpenShift CLI mirror plugin |

---

#### 🐳 Option A — `docker buildx imagetools` (Docker Environments)

Performs a bit-perfect, manifest-level copy directly between registries. No layers are pulled locally or re-compressed.

```bash
# Remove broken failed jobs first
oc delete job tp-cp-bwce-utilities-plugins-extract-job-e -n tibcoplatform-cp-dev
oc delete job tp-cp-bwce-utilities-plugins-extract-job-g -n tibcoplatform-cp-dev

# Bit-perfect registry-to-registry copy — preserves original BTYPE=01 compression
docker buildx imagetools create \
  --tag <dest-registry>/tibcoplatform-cp-dev/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  repotopo-docker-public.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

---

#### 🦭 Option B — `skopeo copy` (Podman / OpenShift Native — Recommended)

`skopeo` is Red Hat's cloud-native image utility. It streams raw binary chunks directly between registries without pulling, unpacking, or re-compressing layers locally. This is the **recommended approach** for environments locked into a Podman / OpenShift toolchain.

**Step 1 — Log in to both registries via Podman** (`skopeo` inherits tokens from `$XDG_RUNTIME_DIR/containers/auth.json`):

```bash
podman login repotopo-docker-public.jfrog.io
podman login <dest-registry>
```

**Step 2 — Copy images using `skopeo copy` with `--format v2s2`:**

```bash
skopeo copy --format v2s2 \
  docker://repotopo-docker-public.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  docker://<dest-registry>/tibcoplatform-cp-dev/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

> **ℹ️ Note**: The `--format v2s2` flag preserves the exact Docker V2 Schema 2 layer structure that the `bwce-utilities` extraction container requires. Omitting it may still cause corruption in some environments.

**Step 3 — [Verify the fix](#-verification)**, then re-run the Helm install.

---

#### 🔴 Option C — `oc mirror` (Air-Gapped Bulk Migration)

`oc mirror` is OpenShift's native tool for registry-to-registry image mirroring, especially suited for bulk migrations and fully air-gapped environments. It does not decompress layers locally.

**Step 1 — Create an `ImageSetConfiguration` file:**

```yaml
# imageset-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
mirror:
  additionalImages:
    - name: repotopo-docker-public.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
    - name: repotopo-docker-public.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-as2:2.5.0.v4.3-tci-2.0
    - name: repotopo-docker-public.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-ap:5.0.0.v11.2-tci-2.0
```

**Step 2 — Execute the mirror:**

```bash
oc mirror --config=imageset-config.yaml \
  docker://<dest-registry> \
  --dest-skip-tls
```

---

### 🧪 Verification

After re-mirroring using any of the options above, re-run the GZIP header inspection from the [Diagnosis](#-diagnosis-3) section. You should now see `ecf2` in the header bytes, confirming `BTYPE=01` compression is intact.

Then re-run the Helm install — the plugin extraction jobs will complete successfully.

---

## 🔗 Additional Resources

### OpenShift & ARO

- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Managing SCCs in OpenShift](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html#security-context-constraints-command-reference_configuring-internal-oauth)
- [oc mirror — Disconnected Install](https://docs.openshift.com/container-platform/latest/installing/disconnected_install/installing-mirroring-disconnected.html)

### Container Registry Tools

- [TIBCO Platform — Pushing Images to Custom Container Registry](https://docs.tibco.com/pub/platform-cp/latest/doc/html/UserGuide/pushing-images-to-registry.htm)
- [skopeo copy documentation](https://github.com/containers/skopeo/blob/main/docs/skopeo-copy.1.md)
- [docker buildx imagetools](https://docs.docker.com/engine/reference/commandline/buildx_imagetools/)

### Related Workshop Guides

- [Customer Prerequisites Checklist](./prerequisites-checklist-for-customer)
- [Firewall Requirements for ARO](../docs/firewall-requirements-aro)
- [Main Setup Guide — CP + DP on ARO](./how-to-cp-and-dp-openshift-aro-aks-setup-guide)
