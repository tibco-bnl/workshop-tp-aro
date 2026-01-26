# Network Connectivity Test Job for TIBCO Platform on ARO

This Kubernetes Job tests connectivity to all required, recommended, and optional endpoints needed for TIBCO Platform deployment on Azure Red Hat OpenShift (ARO).

## Overview

The connectivity test validates access to:
- **CRITICAL endpoints**: TIBCO registries, Red Hat registries, OpenShift services, Helm repos, Azure services (deployment will fail if these are blocked)
- **RECOMMENDED endpoints**: Microsoft Container Registry, Kubernetes, GitHub, Red Hat partner catalog (some features may not work)
- **OPTIONAL endpoints**: Documentation sites (useful for troubleshooting)

## Prerequisites

- Access to an ARO cluster with `oc` configured
- Cluster must have outbound internet connectivity (or proxy configured)
- Permissions to create ConfigMaps and Jobs in the target namespace

## Quick Start

### 1. Deploy the Connectivity Test Job

```bash
# Apply the job (includes ConfigMap with test script)
oc apply -f scripts/connectivity-test-job.yaml

# Wait for job to complete (typically 30-60 seconds)
oc wait --for=condition=complete --timeout=120s job/connectivity-test
```

### 2. View the Results

```bash
# Get the test results from job logs
oc logs job/connectivity-test

# Alternative: Get pod name and view logs
POD_NAME=$(oc get pods -l job-name=connectivity-test -o jsonpath='{.items[0].metadata.name}')
oc logs $POD_NAME
```

### 3. Check Job Status

```bash
# Check if job completed successfully
oc get job connectivity-test

# Expected output for success:
# NAME                 COMPLETIONS   DURATION   AGE
# connectivity-test    1/1           45s        2m

# Check exit code
oc get job connectivity-test -o jsonpath='{.status.conditions[0].type}'
# Should show: Complete
```

## Understanding the Results

### Exit Codes

- **Exit Code 0**: All checks passed (CRITICAL, RECOMMENDED, OPTIONAL)
- **Exit Code 1**: CRITICAL endpoints failed - deployment will likely fail, ARO cluster may not update
- **Exit Code 2**: RECOMMENDED endpoints failed - deployment may proceed with limited functionality

### Report Sections

The test report includes:

1. **CRITICAL Endpoints** - Must be accessible
   - TIBCO JFrog registry (`csgprduswrepoedge.jfrog.io`)
   - TIBCO Helm charts (`tibcosoftware.github.io`)
   - **Red Hat registries** (`registry.redhat.io`, `quay.io`, `registry.access.redhat.com`)
   - **OpenShift services** (`api.openshift.com`, `console.redhat.com`, `sso.redhat.com`)
   - Third-party Helm repos (cert-manager, Elastic ECK, Prometheus)
   - Container registries (Docker Hub, GitHub Container Registry)
   - Azure services (Resource Manager, Azure AD)

2. **RECOMMENDED Endpoints** - Highly recommended
   - Microsoft Container Registry (`mcr.microsoft.com`)
   - Kubernetes (`k8s.io`, `kubernetes.io`)
   - GitHub (`github.com`)
   - Red Hat partner catalog (`registry.connect.redhat.com`)
   - Red Hat customer portal (`access.redhat.com`)

3. **OPTIONAL Endpoints** - For documentation
   - Prometheus.io, Elastic.co, Grafana.com, etc.

### Sample Output

```
=========================================================================
TIBCO Platform Connectivity Test Report
Platform: Azure Red Hat OpenShift (ARO)
Date: Thu Jan 23 10:30:45 UTC 2026
Hostname: connectivity-test-xyz123
=========================================================================

SECTION 1: CRITICAL ENDPOINTS (Must be accessible)
=========================================================================

--- TIBCO Container Registry (CRITICAL) ---
✓ PASS https://csgprduswrepoedge.jfrog.io (HTTP 200)

--- Red Hat Container Registries (CRITICAL for ARO) ---
✓ PASS https://registry.redhat.io (HTTP 200)
✓ PASS https://quay.io (HTTP 200)
✓ PASS https://registry.access.redhat.com (HTTP 200)

--- Red Hat/OpenShift Services (CRITICAL for ARO) ---
✓ PASS https://api.openshift.com (HTTP 200)
✓ PASS https://console.redhat.com (HTTP 200)
✓ PASS https://sso.redhat.com (HTTP 200)

...

=========================================================================
CONNECTIVITY TEST SUMMARY
=========================================================================

CRITICAL Endpoints:
  Total: 25
  Passed: 25
  Failed: 0

RECOMMENDED Endpoints:
  Total: 8
  Passed: 8
  Failed: 0

OPTIONAL Endpoints:
  Total: 4
  Passed: 4
  Failed: 0

=========================================================================
OVERALL STATISTICS
=========================================================================
Total Tests: 37
Total Passed: 37
Total Failed: 0
Pass Rate: 100.00%

=========================================================================
RECOMMENDATIONS
=========================================================================
✓ All CRITICAL endpoints are accessible
✓ All RECOMMENDED endpoints are accessible

=========================================================================
NEXT STEPS
=========================================================================
1. ✓ All required connectivity checks passed
2. Proceed with TIBCO Platform deployment
3. Monitor connectivity during deployment
4. Verify ARO cluster health: oc get clusteroperators
```

## ARO-Specific Considerations

### Red Hat Registry Failures

If Red Hat registries fail connectivity tests:

⚠️ **WARNING**: This will prevent ARO cluster updates and may affect cluster stability!

```bash
# Check ARO cluster operators status
oc get clusteroperators

# Check image pull errors
oc get events --all-namespaces | grep -i "pull"

# Verify Red Hat pull secret
oc get secret pull-secret -n openshift-config -o json
```

### OpenShift Service Failures

If `api.openshift.com` or `console.redhat.com` fail:

- Some OpenShift console features may not work
- Cluster Manager integration may be unavailable
- Red Hat SRE monitoring may be impacted

## Troubleshooting

### If CRITICAL Endpoints Fail

1. **Check firewall rules**:
   ```bash
   # Review firewall requirements document
   cat docs/firewall-requirements.md
   ```

2. **Test specific endpoint manually**:
   ```bash
   oc run test --image=registry.access.redhat.com/ubi9/ubi-minimal --rm -it -- \
     bash -c "microdnf install -y curl && curl -I https://registry.redhat.io"
   ```

3. **Check cluster-wide proxy settings**:
   ```bash
   oc get proxy cluster -o yaml
   ```

4. **Review NSG/Azure Firewall rules**:
   - See `docs/firewall-requirements.md` Section 10 for NSG rules
   - See `docs/firewall-requirements.md` Section 11 for Azure Firewall rules

### If Job Fails to Start

```bash
# Check pod events
oc describe job connectivity-test

# Check pod status
oc get pods -l job-name=connectivity-test

# View pod logs if in error state
oc logs -l job-name=connectivity-test --all-containers

# Check Security Context Constraints (ARO-specific)
oc get scc
oc adm policy who-can use scc restricted
```

### Re-running the Test

```bash
# Delete existing job
oc delete job connectivity-test

# Reapply after firewall changes
oc apply -f scripts/connectivity-test-job.yaml

# Monitor progress
oc logs -f job/connectivity-test
```

## Customization

### Test Different Namespace

```bash
# Edit the YAML file or use oc with namespace flag
oc apply -f scripts/connectivity-test-job.yaml -n tibco-platform

# View logs
oc logs -n tibco-platform job/connectivity-test
```

### Add Custom Endpoints

Edit the ConfigMap in `connectivity-test-job.yaml` and add URLs to the test script:

```bash
# Add to CRITICAL section
for url in \
    "https://csgprduswrepoedge.jfrog.io" \
    "https://your-custom-endpoint.com"
do
    if test_url "$url" "CRITICAL"; then
        ((CRITICAL_PASS++))
    else
        ((CRITICAL_FAIL++))
        CRITICAL_FAILED+=("$url")
    fi
done
```

### Adjust Timeout

Edit the `timeout` variable in the test script (default is 5 seconds):

```bash
test_url() {
    local url=$1
    local category=$2
    local timeout=10  # Increase to 10 seconds
    ...
}
```

## Integration with CI/CD

### Use in OpenShift Pipelines (Tekton)

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: connectivity-test
spec:
  steps:
    - name: run-test
      image: image-registry.openshift-image-registry.svc:5000/openshift/cli:latest
      script: |
        #!/bin/bash
        oc apply -f scripts/connectivity-test-job.yaml
        oc wait --for=condition=complete --timeout=120s job/connectivity-test
        oc logs job/connectivity-test
        
        # Fail if critical endpoints failed
        if oc get job connectivity-test -o jsonpath='{.status.failed}' | grep -q "1"; then
          echo "Connectivity test failed"
          exit 1
        fi
```

### Use in GitHub Actions

```yaml
- name: Run Connectivity Test on ARO
  run: |
    oc apply -f scripts/connectivity-test-job.yaml
    oc wait --for=condition=complete --timeout=120s job/connectivity-test
    oc logs job/connectivity-test
    
    # Fail pipeline if critical endpoints failed
    if oc get job connectivity-test -o jsonpath='{.status.failed}' | grep -q "1"; then
      echo "Connectivity test failed"
      exit 1
    fi
```

## Cleanup

```bash
# Delete the job (ConfigMap will remain for reuse)
oc delete job connectivity-test

# Delete both job and ConfigMap
oc delete -f scripts/connectivity-test-job.yaml
```

## Job Retention

The job is configured with `ttlSecondsAfterFinished: 86400` (24 hours), which means:
- Completed jobs are automatically cleaned up after 24 hours
- Failed jobs are also cleaned up after 24 hours
- Logs can be retrieved within this time window

To keep jobs longer, edit the YAML:

```yaml
spec:
  ttlSecondsAfterFinished: 604800  # 7 days
```

## Monitoring ARO Cluster Health

After successful connectivity tests, verify ARO cluster health:

```bash
# Check all cluster operators
oc get clusteroperators

# All operators should show AVAILABLE=True, PROGRESSING=False, DEGRADED=False

# Check cluster version
oc get clusterversion

# Check nodes
oc get nodes

# Check critical namespaces
oc get pods -n openshift-cluster-version
oc get pods -n openshift-image-registry
oc get pods -n openshift-ingress
```

## Related Documentation

- [Firewall Requirements](../docs/firewall-requirements.md) - Complete list of required endpoints including ARO-specific requirements
- [Network Security Group Rules](../docs/firewall-requirements.md#10-network-security-group-nsg-rules-for-azure)
- [Azure Firewall Rules](../docs/firewall-requirements.md#11-azure-firewall-application-rules)
- [Firewall Request Template](../docs/firewall-requirements.md#17-simplified-firewall-request-template)
- [OpenShift Proxy Configuration](../docs/firewall-requirements.md#12-proxy-configuration)

## Support

If connectivity tests fail:

1. Review the [firewall requirements document](../docs/firewall-requirements.md)
2. Contact your network/security team with the test results
3. Use the [firewall request template](../docs/firewall-requirements.md#sample-firewall-request-form) to request access
4. Emphasize ARO-specific requirements (Red Hat registries are CRITICAL)
5. Re-run tests after firewall changes are applied
6. Monitor ARO cluster operators: `oc get clusteroperators`

## Important Notes

⚠️ **Red Hat Registry Access**: ARO clusters REQUIRE access to Red Hat registries. Blocking these will prevent:
- Cluster updates and patches
- OpenShift operator updates
- Red Hat SRE monitoring and support
- Container image pulls for OpenShift components

⚠️ **OpenShift Services**: Access to `api.openshift.com` and related services is needed for:
- Cluster registration
- Update channels
- Red Hat Insights integration
- OpenShift Cluster Manager features
