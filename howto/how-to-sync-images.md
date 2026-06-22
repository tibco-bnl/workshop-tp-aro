---
layout: default
title: How to Push TIBCO Platform Images to a Custom Container Registry
---

# 🔄 How to Push TIBCO Platform Images to a Custom Container Registry

> 📋 **Scope**: Mirroring TIBCO Platform images to a private or air-gapped container registry  
> 🎯 **Applies to**: Azure Red Hat OpenShift (ARO), air-gapped clusters, enterprise private registries  
> 🔗 **Official sync script**: [TIBCOSoftware/tp-helm-charts — sync-artifacts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts)  
> ⚠️ **See also**: [Troubleshooting Guide — Issue 4: BW Plugin Image Layer Corruption](./troubleshooting#4--businessworks-plugin-extraction-crash--image-layer-corruption)

When deploying TIBCO Platform in environments where cluster nodes cannot reach the TIBCO JFrog registry directly — such as air-gapped clusters, corporate firewalled environments, or regulated environments requiring private registry policies — you must first mirror the required container images to an accessible internal registry before installation.

This guide covers the official TIBCO synchronization script, safe copy methods for each environment type, critical BusinessWorks plugin image handling, and a verification and remediation runbook.

---

## 📋 Table of Contents

1. [Prerequisites](#1--prerequisites)
2. [Official TIBCO sync-images.sh Script](#2--official-tibco-sync-imagessh-script)
3. [Why Standard push Commands Break BusinessWorks Plugins](#3-️-why-standard-push-commands-break-businessworks-plugins)
4. [Safe Image Copy Methods](#4--safe-image-copy-methods)
5. [OpenShift Integrated Registry — Authentication & Setup](#5-️-openshift-integrated-registry--authentication--setup)
6. [Verify Image Integrity](#6--verify-image-integrity)
7. [Runbook: Fix an Already-Corrupted Registry](#7--runbook-fix-an-already-corrupted-registry)
8. [Additional Resources](#8--additional-resources)

---

## 1. 📋 Prerequisites

### Tools Required

| Tool | Purpose | Required For |
|------|---------|-------------|
| `skopeo` | Bit-perfect registry-to-registry copy | Podman / OpenShift environments |
| `docker` + `buildx` plugin | Bit-perfect manifest copy | Docker environments |
| `oc` CLI | OpenShift cluster access | ARO integrated registry |
| `oc mirror` plugin | Bulk declarative image mirroring | Air-gapped OpenShift |
| `podman` | Registry login (for skopeo auth) | Podman toolchain |

### Credentials Required

- [ ] TIBCO JFrog source registry credentials (`csgprduswrepoedge.jfrog.io`)
- [ ] Target registry credentials (OpenShift integrated registry, or private registry)
- [ ] OpenShift cluster access (`oc whoami` returns a valid user)
- [ ] `RELEASE_VERSION` — the TIBCO Platform version being deployed (e.g., `1.17.0`)

### Clone the TIBCO tp-helm-charts Repository

The official sync script and image lists are in the TIBCO tp-helm-charts repository:

```bash
git clone https://github.com/TIBCOSoftware/tp-helm-charts.git
cd tp-helm-charts/scripts/sync-artifacts
```

---

## 2. 🚀 Official TIBCO sync-images.sh Script

TIBCO provides an official synchronization script at [`scripts/sync-artifacts/sync-images.sh`](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts) in the `tp-helm-charts` repository.

> **✅ This is the recommended method.** The script uses `docker buildx imagetools create` internally, which performs a bit-perfect registry-to-registry copy — it preserves the original GZIP layer headers that BusinessWorks plugin images require. No images are pulled or re-compressed locally.

### Environment Variables

**Required:**

| Variable | Description | Example |
|----------|-------------|---------|
| `SOURCE_REGISTRY` | TIBCO JFrog source registry | `csgprduswrepoedge.jfrog.io` |
| `SOURCE_REGISTRY_USERNAME` | JFrog username | `your-username` |
| `SOURCE_REGISTRY_PASSWORD` | JFrog password or API token | `your-token` |
| `RELEASE_VERSION` | Platform version (`major.minor.patch`) | `1.17.0` |
| `TARGET_REGISTRY` | Your private registry URL | `myregistry.example.com` |

**Optional:**

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_REGISTRY_USERNAME` | — | Target registry username |
| `TARGET_REGISTRY_PASSWORD` | — | Target registry password |
| `TARGET_REGISTRY_REPO` | — | Target repository path override |
| `CAPABILITY_NAME` | _(all)_ | Sync only a specific capability (e.g., `bwce`) |
| `MAX_RETRY` | `0` | Retry count for failed copy operations |
| `WAIT_BEFORE_RETRY` | `0` | Seconds between retries |
| `WRITE_SCRIPT_LOGS_TO_FILE` | `false` | Write logs to `image_sync_<timestamp>.log` |

### Running the Script

```bash
export SOURCE_REGISTRY="csgprduswrepoedge.jfrog.io"
export SOURCE_REGISTRY_USERNAME="john.doe@company.com"
export SOURCE_REGISTRY_PASSWORD="AKCp8mnyYZQ..."
export RELEASE_VERSION="1.17.0"
export TARGET_REGISTRY="registry.apps.ocp-tibco-workshop.example.com"
export TARGET_REGISTRY_USERNAME="ocp-admin"
export TARGET_REGISTRY_PASSWORD=""

# Optional: sync only BW capability images
export CAPABILITY_NAME="bwce"

cd tp-helm-charts/scripts/sync-artifacts
./sync-images.sh
```

The script reads image lists from `../../artifacts/*-${RELEASE_VERSION}-images.txt` and copies each image directly from source to target.

> **ℹ️ Note for Podman / OpenShift environments**: The official script requires Docker with the `buildx` plugin. If your jump server or bastion host only has Podman, see [Method B — skopeo copy](#-method-b--skopeo-copy-podman--openshift-native) below.

---

## 3. ⚠️ Why Standard push Commands Break BusinessWorks Plugins

Using `podman push`, `docker push`, `podman save`, or `docker save` to transfer images to your private registry will silently corrupt BusinessWorks plugin images. This causes extraction jobs to fail during the BW capability deployment with:

```
tar: invalid tar header checksum
```

### Root Cause — GZIP DEFLATE Block Type Corruption

Standard container engines decompress and **re-compress** image layers locally as part of the push/save process. For BusinessWorks plugin images (which contain nested Java archive structures), this changes the GZIP DEFLATE block type from:

| Block Type | Signature bytes | Status |
|-----------|----------------|--------|
| `BTYPE=01` — Fixed Huffman (original TIBCO) | `ecf2` | ✅ Extraction succeeds |
| `BTYPE=00` — Non-compressed / Stored block (re-compressed) | `00ff` | ❌ Extraction fails |

The minimalist `busybox tar` binary inside the `bwce-utilities` extraction container cannot parse `BTYPE=00` stored blocks and throws a fatal checksum error.

> **The fix is simple: never use the local container engine's push/save pipeline for BW plugin images. Use a registry-to-registry copy tool instead (see below).**

---

## 4. ✅ Safe Image Copy Methods

All methods below perform registry-to-registry copies that stream raw layer blobs without local decompression. They preserve the original `BTYPE=01` headers.

### 🚀 Method A — sync-images.sh (Recommended, Docker environments)

See [Section 2](#2--official-tibco-sync-imagessh-script) above. The official TIBCO script handles authentication, image list reading, retry logic, and logging.

---

### 🦭 Method B — skopeo copy (Podman / OpenShift Native)

`skopeo` is Red Hat's cloud-native image utility. It streams raw binary chunks directly between registries without local decompression. This is the **recommended method for Podman and OpenShift environments**.

**Step 1 — Log in to both registries:**

```bash
# Source: TIBCO JFrog
podman login csgprduswrepoedge.jfrog.io \
  --username john.doe@company.com \
  --password AKCp8mnyYZQ...

# Target: Your OpenShift registry or private registry
podman login registry.apps.ocp-tibco-workshop.example.com
# For OCP integrated registry:
podman login -u $(oc whoami) -p $(oc whoami -t) \
  default-route-openshift-image-registry.apps.ocp-tibco-workshop.example.com
```

**Step 2 — Copy individual images with `--format v2s2`:**

```bash
skopeo copy --format v2s2 \
  docker://csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  docker://registry.apps.ocp-tibco-workshop.example.com/tibco-platform-cp/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

> **ℹ️ The `--format v2s2` flag** preserves the Docker V2 Schema 2 layer structure required by the `bwce-utilities` extraction container. Always include it.

**Script wrapper for multiple images:**

```bash
#!/bin/bash
SOURCE="csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod"
TARGET="registry.apps.ocp-tibco-workshop.example.com/tibco-platform-cp"
IMAGES=(
  "tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0"
  "tci-bw-plugin-as2:2.5.0.v4.3-tci-2.0"
  "tci-bw-plugin-ap:5.0.0.v11.2-tci-2.0"
)
for IMAGE in "${IMAGES[@]}"; do
  skopeo copy --format v2s2 \
    docker://${SOURCE}/${IMAGE} \
    docker://${TARGET}/${IMAGE}
done
```

---

### 🐳 Method C — docker buildx imagetools (Docker environments, manual)

Use this when you need more control than the `sync-images.sh` script provides, or when syncing individual images from a Docker environment.

```bash
docker buildx imagetools create \
  --tag registry.apps.ocp-tibco-workshop.example.com/tibco-platform-cp/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

No images are pulled locally — `imagetools create` links manifest pointers directly between registries.

---

### 📦 Method D — skopeo dir:// (Air-Gapped / No Direct Connectivity)

Use this when your target cluster has no network path to the TIBCO JFrog registry and you must physically transport images across an air-gap perimeter.

> **⚠️ Do not use `podman save` / `docker save` to create the transport archive.** Always use `skopeo copy dir://` which preserves raw layer blobs.

**On the internet-connected machine (source side):**

```bash
# Dump raw, unmodified manifest blocks to a staging directory
skopeo copy \
  docker://csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-ap:5.0.0.v11.2-tci-2.0 \
  dir:/tmp/staging/tci-bw-plugin-ap

# Archive the directory (not the image layers — the folder structure)
tar -cvf tibco-plugin-transport.tar -C /tmp/staging tci-bw-plugin-ap

# [Transfer tibco-plugin-transport.tar across the air-gap perimeter]
```

**On the air-gapped target machine:**

```bash
# Extract the staging directory
tar -xvf tibco-plugin-transport.tar -C /tmp/staging

# Push bit-perfect to the target registry
# The --force flag overwrites any previously corrupted records
skopeo copy --force --format v2s2 \
  dir:/tmp/staging/tci-bw-plugin-ap \
  docker://registry.apps.ocp-tibco-workshop.example.com/tibco-platform-cp/tci-bw-plugin-ap:5.0.0.v11.2-tci-2.0
```

---

### 🔴 Method E — oc mirror (ARO / OpenShift Bulk Migration)

`oc mirror` is OpenShift's native declarative tool for bulk image replication. It is ideal for large-scale migrations and enterprise air-gapped environments.

**Step 1 — Create an `imageset-config.yaml`:**

```yaml
# imageset-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
storageConfig:
  registry:
    imageURL: registry.apps.ocp-tibco-workshop.example.com/tibco-platform-cp/mirror-metadata
    skipTLS: true
mirror:
  additionalImages:
    - name: csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
    - name: csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-as2:2.5.0.v4.3-tci-2.0
    - name: csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-ap:5.0.0.v11.2-tci-2.0
```

**Step 2 — Run the mirror:**

```bash
oc mirror --config=imageset-config.yaml \
  docker://registry.apps.ocp-tibco-workshop.example.com \
  --dest-skip-tls
```

---

### 📊 Method Comparison

| Method | Tooling Required | Best For | Bit-Perfect? |
|--------|-----------------|----------|-------------|
| `sync-images.sh` | Docker + buildx | Standard deployments, all images at once | ✅ Yes |
| `skopeo copy` | skopeo | Podman / OpenShift, single images or scripts | ✅ Yes |
| `docker buildx imagetools` | Docker + buildx | Manual per-image copy, Docker environments | ✅ Yes |
| `skopeo dir://` | skopeo | Air-gapped with physical data transfer | ✅ Yes |
| `oc mirror` | OpenShift CLI | Enterprise / GitOps bulk mirroring | ✅ Yes |
| `podman push` / `docker push` | Any | ❌ **Do not use for BW plugin images** | ❌ No |

---

## 5. 🏗️ OpenShift Integrated Registry — Authentication & Setup

When using the OpenShift internal image registry as your target:

### Log In to the Registry

```bash
# Get the registry route
oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}'

# Log in with your OpenShift credentials
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
podman login -u $(oc whoami) -p $(oc whoami -t) $REGISTRY
```

### Ensure the Target Namespace Has an ImageStream

```bash
# Create the namespace if it does not exist
oc create namespace tibcoplatform-cp-dev 2>/dev/null || true

# Images pushed to this registry path:
# $REGISTRY/tibcoplatform-cp-dev/<image>:<tag>
```

### Enable External Route for Image Pushes (if not already enabled)

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

---

## 6. 🧪 Verify Image Integrity

After pushing images to your private registry, verify that BusinessWorks plugin layers have the correct GZIP header before running the Helm install.

```bash
TOKEN=$(oc whoami -t)
REGISTRY="registry.apps.ocp-tibco-workshop.example.com"
NAMESPACE="tibcoplatform-cp-dev"
IMAGE="tci-bw-plugin-ap"
TAG="5.0.0.v11.2-tci-2.0"

# 1. Get the first layer digest from the image manifest
DIGEST=$(curl -s -k \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://$REGISTRY/v2/$NAMESPACE/$IMAGE/manifests/$TAG" \
  | jq -r '.layers[0].digest')

# 2. Download the raw layer blob
curl -s -k \
  -H "Authorization: Bearer $TOKEN" \
  "https://$REGISTRY/v2/$NAMESPACE/$IMAGE/blobs/$DIGEST" \
  -o /tmp/check_header.tar.gz

# 3. Read the first 16 bytes
xxd /tmp/check_header.tar.gz | head -1
```

**Expected output (healthy image):**
```
00000000: 1f8b 0800 0000 0000 00ff ecf2 638c 2f40 ...
```

| Bytes 10–11 | Meaning | Status |
|-------------|---------|--------|
| `ecf2` | `BTYPE=01` Fixed Huffman — original TIBCO compression | ✅ Safe to proceed |
| `00ff` | `BTYPE=00` Non-compressed — re-compressed by push | ❌ Re-mirror before installing |

---

## 7. 🔧 Runbook: Fix an Already-Corrupted Registry

If images were already pushed using `podman push` or `docker push` and the OpenShift registry has cached the corrupted layers, a normal re-push will be skipped (`Copying blob ... skipped: already exists`). You must evict the stale records first.

### Step 1 — Evict Stale ImageStream Records

```bash
NAMESPACE="tibcoplatform-cp-dev"

oc delete imagestream tci-bw-plugin-ap   -n $NAMESPACE
oc delete imagestream tci-bw-plugin-cics -n $NAMESPACE
oc delete imagestream tci-bw-plugin-as2  -n $NAMESPACE
# Repeat for any other affected BW plugin images
```

### Step 2 — Delete Broken Extraction Job Pods

```bash
oc delete jobs -n $NAMESPACE --selector=app.kubernetes.io/component=bwce-utilities
```

### Step 3 — Re-Mirror Images Using a Bit-Perfect Method

Choose one of the safe methods from [Section 4](#4--safe-image-copy-methods) and re-push all affected BW plugin images.

### Step 4 — Verify Header Integrity

Run the verification commands from [Section 6](#6--verify-image-integrity). Confirm `ecf2` is present in the header bytes.

### Step 5 — Retry the Helm Install

The capability deployment will now find intact images and the extraction jobs will complete successfully.

---

## 8. 🔗 Additional Resources

### Official TIBCO Scripts

- [TIBCOSoftware/tp-helm-charts — sync-artifacts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts)
- [TIBCO Platform — Pushing Images to Custom Container Registry](https://docs.tibco.com/pub/platform-cp/latest/doc/html/UserGuide/pushing-images-to-registry.htm)

### Image Copy Tools

- [skopeo documentation](https://github.com/containers/skopeo)
- [docker buildx imagetools](https://docs.docker.com/engine/reference/commandline/buildx_imagetools/)
- [oc mirror — Disconnected Install](https://docs.openshift.com/container-platform/latest/installing/disconnected_install/installing-mirroring-disconnected.html)

### Related Workshop Guides

- [Troubleshooting Guide](./troubleshooting) — Issue 4 covers BW plugin image corruption in detail
- [Customer Prerequisites Checklist](./prerequisites-checklist-for-customer)
- [Firewall Requirements for ARO](../docs/firewall-requirements-aro)
