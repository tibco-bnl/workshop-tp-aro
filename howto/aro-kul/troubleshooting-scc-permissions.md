# Troubleshooting: SCC Permission Error on ARO for TIBCO Control Plane

## Error Description

When deploying `tibco-cp-base` helm chart on Azure Red Hat OpenShift (ARO), pods fail to start with the following error:

```
pods "tp-cp-orchestrator-669d64876b-" is forbidden: unable to validate against any security context constraint: 
[provider "tp-scc": Forbidden: not usable by user or serviceaccount, 
provider "anyuid": Forbidden: not usable by user or serviceaccount, 
provider "nfs-ems-scc": Forbidden: not usable by user or serviceaccount, 
provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: []int64{1000}: 1000 is not an allowed group, 
provider restricted-v2: .initContainers[0].runAsUser: Invalid value: 1000: must be in the ranges:]
```

## Root Cause

The service accounts in the Control Plane namespace **do not have permission to use the `tp-scc`** Security Context Constraint. Even though the `tp-scc` was created, it needs to be explicitly granted to the service accounts.

## Solution

### Step 1: Verify SCC Exists

First, confirm that the `tp-scc` Security Context Constraint was created:

```bash
oc get scc tp-scc
```

**Expected output:**
```
NAME     PRIV    CAPS                   SELINUX     RUNASUSER   FSGROUP    SUPGROUP   PRIORITY   READONLYROOTFS   VOLUMES
tp-scc   false   ["NET_BIND_SERVICE"]   MustRunAs   RunAsAny    RunAsAny   RunAsAny   10         false            [...]
```

If it doesn't exist, create it using the command from Step 6 of the setup guide.

### Step 2: Grant SCC to Service Accounts

**This is the critical step that's missing!** Grant the `tp-scc` to both the custom service account and the default service account:

```bash
# Set your Control Plane instance ID
export CP_INSTANCE_ID="cp1"  # Replace with your actual instance ID

# Grant tp-scc to the custom service account
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa

# Grant tp-scc to the default service account
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

**Expected output for each command:**
```
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:tp-scc added: "cp1-sa"
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:tp-scc added: "default"
```

### Step 3: Verify SCC Assignments

Verify that the SCC was properly assigned to the service accounts:

```bash
# Check which service accounts can use tp-scc
oc describe scc tp-scc | grep -A 20 "Users:"

# Or check what SCCs a specific service account can use
oc get scc -o json | jq -r '.items[] | select(.users[]? | contains("'${CP_INSTANCE_ID}'-sa")) | .metadata.name'
```

### Step 4: Verify Service Account Exists

Ensure the service account was created:

```bash
# Check if service account exists
oc get serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns

# Check if default service account exists
oc get serviceaccount default -n ${CP_INSTANCE_ID}-ns
```

If the service account doesn't exist, create it:

```bash
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

### Step 5: Delete Existing Pods (if any)

If there are pods stuck in error state, delete them so they can be recreated with the correct SCC:

```bash
# Delete all pods in the namespace (they will be recreated automatically)
oc delete pods --all -n ${CP_INSTANCE_ID}-ns

# Or delete specific failing pods
oc delete pod tp-cp-orchestrator-669d64876b-xxxxx -n ${CP_INSTANCE_ID}-ns
```

### Step 6: Monitor Pod Creation

Watch the pods being recreated:

```bash
# Watch pod status
oc get pods -n ${CP_INSTANCE_ID}-ns -w

# Check events for any errors
oc get events -n ${CP_INSTANCE_ID}-ns --sort-by='.lastTimestamp' | tail -20
```

## Verification

### Check Pod Security Context

Once pods are running, verify they're using the correct SCC:

```bash
# Get a running pod name
POD_NAME=$(oc get pods -n ${CP_INSTANCE_ID}-ns -l app=cp-orchestrator -o jsonpath='{.items[0].metadata.name}')

# Check which SCC the pod is using
oc describe pod $POD_NAME -n ${CP_INSTANCE_ID}-ns | grep "openshift.io/scc"
```

**Expected output:**
```
openshift.io/scc: tp-scc
```

### Check All Pods Status

```bash
# Check that all pods are running
oc get pods -n ${CP_INSTANCE_ID}-ns

# Expected: All pods should be in Running or Completed status
```

## Complete Pre-Installation Checklist

To avoid this issue in future deployments, follow this checklist **BEFORE** deploying tibco-cp-base:

### 1. Create Namespace with Labels
```bash
oc apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
 name: ${CP_INSTANCE_ID}-ns
 labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)
```

### 2. Create Service Account
```bash
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

### 3. Create tp-scc (if not exists)
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

### 4. Grant SCC Permissions (CRITICAL!)
```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

### 5. Create Required Secrets
```bash
# Session keys
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}

# Database credentials
kubectl create secret generic ${CP_DB_SECRET_NAME} \
    --from-literal=db_username=${CP_DB_USERNAME} \
    --from-literal=db_password=${CP_DB_PASSWORD} \
    -n ${CP_INSTANCE_ID}-ns

# Encryption secret
kubectl create secret generic cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns \
  --from-literal=CP_ENCRYPTION_SECRET_KEY=$(openssl rand -base64 32)
```

### 6. Verify Prerequisites
```bash
# Check namespace
oc get namespace ${CP_INSTANCE_ID}-ns

# Check service account
oc get serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns

# Check SCC assignment
oc describe scc tp-scc | grep -A 5 "Users:"

# Check secrets
oc get secrets -n ${CP_INSTANCE_ID}-ns | grep -E "session-keys|provider-cp-database|cporch-encryption"
```

## Alternative: Use privileged SCC (NOT RECOMMENDED for Production)

If you need a quick workaround for testing (NOT recommended for production):

```bash
# Grant privileged SCC (allows more permissions)
oc adm policy add-scc-to-user privileged system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user privileged system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

**Warning:** This grants excessive permissions. Use only for testing and always revert to `tp-scc` for production.

## Common Issues and Solutions

### Issue 1: "SCC not found"
**Solution:** Create the `tp-scc` using the command in Step 3 above.

### Issue 2: "Service account not found"
**Solution:** Create the service account:
```bash
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

### Issue 3: Pods still failing after granting SCC
**Solution:** 
1. Delete the failing pods to force recreation
2. Check pod events: `oc describe pod <pod-name> -n ${CP_INSTANCE_ID}-ns`
3. Verify the SCC is actually being used: `oc describe pod <pod-name> -n ${CP_INSTANCE_ID}-ns | grep scc`

### Issue 4: Multiple service accounts need permissions
**Solution:** Grant SCC to all service accounts used by the chart:
```bash
# Find all service accounts in the namespace
oc get serviceaccounts -n ${CP_INSTANCE_ID}-ns

# Grant to each one
for sa in $(oc get serviceaccounts -n ${CP_INSTANCE_ID}-ns -o jsonpath='{.items[*].metadata.name}'); do
  oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:$sa
done
```

## Quick Fix Script

Here's a complete script to fix the SCC issue:

```bash
#!/bin/bash
# Fix SCC permissions for TIBCO Control Plane on ARO

set -e

export CP_INSTANCE_ID="cp1"  # Change to your instance ID

echo "Fixing SCC permissions for ${CP_INSTANCE_ID}-ns namespace..."

# Grant SCC to service accounts
echo "Granting tp-scc to service accounts..."
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default

# Verify
echo "Verifying SCC assignment..."
oc describe scc tp-scc | grep -A 10 "Users:"

# Delete failing pods
echo "Deleting pods to force recreation..."
oc delete pods --all -n ${CP_INSTANCE_ID}-ns

# Watch pods
echo "Watching pod status (Ctrl+C to exit)..."
oc get pods -n ${CP_INSTANCE_ID}-ns -w
```

Save this as `fix-scc-permissions.sh`, make it executable, and run it:

```bash
chmod +x fix-scc-permissions.sh
./fix-scc-permissions.sh
```

## Reference

For more details on OpenShift Security Context Constraints, see:
- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Managing SCCs in OpenShift](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html#security-context-constraints-command-reference_configuring-internal-oauth)

## Summary

The key takeaway: **Always grant SCC permissions to service accounts BEFORE deploying the helm chart on OpenShift/ARO**. This is a required step that's easy to miss but critical for pod creation.

The correct sequence is:
1. Create namespace
2. Create service account
3. Create tp-scc (if not exists)
4. **Grant SCC to service accounts** ← Often missed!
5. Create secrets
6. Deploy helm chart
