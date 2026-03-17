# Troubleshooting Jaeger Query Service Connectivity Issue in ARO

## Issue Summary

The Jaeger query service is failing to start with the following error:

```
Failed to init storage factory: failed to create Elasticsearch client: 
health check timeout: Head "https://dp-config-es-es-http.elastic-system.svc:9200": 
dial tcp 172.30.132.245:9200: connect: connection refused: no Elasticsearch node available
```

This is a connectivity issue between Jaeger and the Elasticsearch backend service in your Azure Red Hat OpenShift (ARO) cluster.

---

## Root Cause Analysis

In ARO environments, this issue is typically caused by one or more of the following:

1. **Security Context Constraints (SCC)** - Elasticsearch pods lack proper permissions to start
2. **Network Policies** - Cross-namespace traffic is blocked between Jaeger and Elasticsearch
3. **Service Availability** - Elasticsearch pods are not running or ready
4. **Service Account Permissions** - Insufficient RBAC permissions

---

## Diagnostic Steps

### Step 1: Verify Elasticsearch Pod Status

Check if Elasticsearch pods are running in the `elastic-system` namespace:

```bash
oc get pods -n elastic-system
oc get svc dp-config-es-es-http -n elastic-system
oc describe endpoints dp-config-es-es-http -n elastic-system
```

**Expected Result**: Pods should be in `Running` state and service should have active endpoints.

---

### Step 2: Check Security Context Constraints (SCC)

Verify which SCC is assigned to Elasticsearch pods:

```bash
# Check current SCC assignment
oc get pod <elasticsearch-pod-name> -n elastic-system -o yaml | grep "openshift.io/scc"

# Verify tp-scc exists
oc get scc tp-scc
```

**If Elasticsearch pods are failing to start**, they likely need elevated SCC permissions:

```bash
# Get the service account used by Elasticsearch
SA_NAME=$(oc get pods -n elastic-system -o jsonpath='{.items[0].spec.serviceAccountName}')

# Grant tp-scc to the service account
oc adm policy add-scc-to-user tp-scc system:serviceaccount:elastic-system:${SA_NAME}

# Restart Elasticsearch pods
oc rollout restart statefulset -n elastic-system
```

---

### Step 3: Check Network Policies

Verify if network policies are blocking cross-namespace communication:

```bash
# Check network policies in both namespaces
kubectl get networkpolicies -n elastic-system
kubectl get networkpolicies -n <jaeger-namespace>

# Check namespace labels
kubectl get namespace elastic-system --show-labels
kubectl get namespace <jaeger-namespace> --show-labels
```

**If network policies exist**, ensure they allow ingress from Jaeger's namespace to Elasticsearch on port 9200.

---

### Step 4: Review Elasticsearch Logs

Check Elasticsearch pod logs for startup errors:

```bash
oc logs -n elastic-system <elasticsearch-pod-name> --tail=50
oc describe pod -n elastic-system <elasticsearch-pod-name> | grep -A 10 "Events:"
```

Look for SCC violations, volume mount failures, or permission errors.

---

### Step 5: Test Connectivity from Jaeger Pod

Create a debug pod in Jaeger's namespace to test connectivity:

```bash
oc run test-connectivity --image=curlimages/curl -it --rm --restart=Never -- \
  curl -v -k https://dp-config-es-es-http.elastic-system.svc:9200
```

This will confirm if the network path is accessible.

---

## Recommended Resolution

Based on ARO best practices for TIBCO Platform deployments:

1. **Apply tp-scc to Elasticsearch Service Account**:
   ```bash
   oc adm policy add-scc-to-user tp-scc system:serviceaccount:elastic-system:default
   ```

2. **Verify Elasticsearch is healthy**:
   ```bash
   oc wait --for=condition=ready pod -l app=elasticsearch -n elastic-system --timeout=300s
   ```

3. **Restart Jaeger Query Service**:
   ```bash
   oc rollout restart deployment/<jaeger-query-deployment> -n <namespace>
   ```

---

## Additional Notes

- **Jaeger v1 End-of-Life**: The current Jaeger version (v1.66.0) reached EOL on December 31, 2025. Consider planning a migration to Jaeger v2.
- **ARO Security**: ARO enforces stricter security policies than vanilla Kubernetes. All workloads must have appropriate SCCs assigned.
- **Reference Documentation**: See the TIBCO Platform ARO setup guide for complete SCC and permission configuration steps.

---

## Next Steps

If the issue persists after following these steps:

1. Collect diagnostic bundle:
   ```bash
   oc adm must-gather
   ```

2. Provide the following information:
   - Elasticsearch pod logs
   - Jaeger query pod logs  
   - Output of `oc get scc` and `oc get networkpolicies --all-namespaces`
   - ARO cluster version: `oc version`

Please let us know if you need any assistance with these troubleshooting steps.
