# TIBCO Support Tickets

## Issue #1: Unable to Override flogoprovisioner Resources in tibco-cp-flogo Chart

### **Issue Summary**
Unable to override resource requests/limits for flogoprovisioner chart when deployed via tibco-cp-flogo parent chart recipe

---

### **Product Information**
- **Product**: TIBCO Platform - Control Plane Flogo Capability
- **Chart Name**: tibco-cp-flogo
- **Chart Version**: 1.14.0
- **App Version**: 1.14.0
- **Affected Component**: flogoprovisioner (version 1.14.3)

---

### **Issue Description**

When deploying the Flogo capability using the `tibco-cp-flogo` parent chart, we are unable to override the resource requests and limits for the `flogoprovisioner` component.

The flogoprovisioner is deployed as a recipe defined in:
```
/charts/tibco-cp-flogo/charts/flogo-recipes/templates/flogo.yaml
```

The recipe installs the flogoprovisioner helm chart with hardcoded values, and does not expose a mechanism to override resource settings from the parent chart's values.yaml.

---

### **Current Behavior**

The flogoprovisioner always deploys with the default resource values defined in:
```
/charts/flogoprovisioner/values.yaml
```

Default values (lines 176-182):
```yaml
resources:
  requests:
    cpu: "2"
    memory: 2Gi
  limits:
    cpu: "4"
    memory: 4Gi
```

The recipe at `/charts/tibco-cp-flogo/charts/flogo-recipes/templates/flogo.yaml` (lines 68-95) only allows overriding:
- `global.cp.logging.fluentbit.apps.enabled`
- `global.flogoprovisioner.image.tag`
- `config` parameters (APP_INIT_IMAGE_TAG, APP_HELMCHART_VERSION, INFRA_CP_PROXY_IMAGE_TAG)
- `publicApi.ingress` settings

**There is no provision to override the `resources` section.**

---

### **Expected Behavior**

Customers should be able to override resource requests and limits for flogoprovisioner from the parent `tibco-cp-flogo` chart's values.yaml file, similar to how other configuration values can be overridden.

For example, customers should be able to set:
```yaml
# In tibco-cp-flogo/values.yaml
flogoprovisioner:
  resources:
    requests:
      cpu: "500m"
      memory: 1Gi
    limits:
      cpu: "1"
      memory: 2Gi
```

And have these values propagated to the flogoprovisioner chart during recipe execution.

---

### **Business Impact**

- **Resource Optimization**: Customers cannot adjust resource allocations based on their specific environment capacity and workload requirements
- **Cost Management**: Unable to reduce resource requests/limits in non-production environments to optimize cloud costs
- **Capacity Planning**: Cannot scale up resources for high-load production environments without directly modifying the sub-chart values.yaml
- **Operational Constraints**: Organizations with strict resource quotas per namespace cannot deploy the capability if default values exceed their quota limits

---

### **Reproduction Steps**

1. Deploy tibco-cp-flogo chart with custom resource values:
```yaml
# values.yaml for tibco-cp-flogo
flogoprovisioner:
  resources:
    requests:
      cpu: "500m"
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
```

2. Install the chart:
```bash
helm install flogo-capability tibco-cp-flogo -f values.yaml
```

3. Check the deployed flogoprovisioner resources:
```bash
kubectl get deployment flogoprovisioner -o yaml | grep -A 10 resources
```

4. **Observed Result**: Resources still show the default values (2 CPU / 2Gi memory requests)
5. **Expected Result**: Resources should reflect the overridden values (500m CPU / 512Mi memory requests)

---

### **Proposed Solution**

Update `/charts/tibco-cp-flogo/charts/flogo-recipes/templates/flogo.yaml` to include resource overrides in the recipe values section:

```yaml
recipe.yaml: |
  recipe:
    helmCharts:
      - name: flogoprovisioner
        namespace: ${NAMESPACE}
        version: "1.14.3"
        repository:
          chartMuseum:
            host: ${HELM_REPO}
        values:
          - content: |
              global:
                cp:
                  logging:
                    fluentbit:
                      apps:
                        enabled: ${ENABLE_APPS_FLUENTBIT_SIDECAR}
                flogoprovisioner:
                  image:
                    tag: 784-platform-1.14.0
              resources: ${FLOGOPROVISIONER_RESOURCES}  # ADD THIS
              config:
                APP_INIT_IMAGE_TAG: "51"
                APP_HELMCHART_VERSION: "1.14.3"
                INFRA_CP_PROXY_IMAGE_TAG: "291"
              publicApi:
                ingress:
                  controllerName: ${INGRESS_CONTROLLER_NAME}
                  config:
                    className: ${INGRESS_CLASS_NAME}
                    pathPrefix: ${INGRESS_PATH_PREFIX}
                    fqdn: ${INGRESS_FQDN}
```

And expose the resources in the parent chart's values.yaml with proper defaults.

---

### **Workarounds**

#### **Workaround 1: Post-Installation Resource Patching** (Simplest)

After the recipe deploys flogoprovisioner, patch the deployment directly:

```bash
# Patch the flogoprovisioner deployment with custom resources
kubectl patch deployment flogoprovisioner -n <namespace> --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources",
    "value": {
      "requests": {
        "cpu": "500m",
        "memory": "1Gi"
      },
      "limits": {
        "cpu": "1",
        "memory": "2Gi"
      }
    }
  }
]'
```

**Pros**: Quick, no chart modifications needed  
**Cons**: Manual step, not GitOps-friendly, resets if recipe re-runs

#### **Workaround 2: Direct values.yaml Modification**

Directly modify `/charts/flogoprovisioner/values.yaml` before deployment:

**Pros**: Works immediately  
**Cons**: 
- Not sustainable for multi-environment deployments
- Changes get overwritten on version upgrades
- Not suitable for CI/CD pipelines
- Violates GitOps principles

---

### **Environment Details**
- **Kubernetes Distribution**: Azure Red Hat OpenShift (ARO)
- **Deployment Method**: Helm
- **Installation Type**: Control Plane Capability (Recipe-based)

---

### **Additional Context**

This issue affects all customers who:
- Have resource quota constraints in their Kubernetes namespaces
- Need to optimize costs across multiple environments (dev/test/prod)
- Follow GitOps practices where chart modifications are not permitted
- Require different resource profiles for different environments
- Deploy in resource-constrained clusters

---

### **Files Involved**

1. **Recipe Template**: `/charts/tibco-cp-flogo/charts/flogo-recipes/templates/flogo.yaml`
2. **Flogoprovisioner Values**: `/charts/flogoprovisioner/values.yaml`
3. **Parent Chart Values**: `/charts/tibco-cp-flogo/values.yaml`

---

### **Requested Action**

Please enhance the tibco-cp-flogo chart (specifically the flogo-recipes template) to support resource override capabilities, allowing customers to configure flogoprovisioner resources through the parent chart's values.yaml file.

This should follow the same pattern as other configurable values like image tags, ingress settings, and fluentbit configuration.

---

### **Status**
- [ ] Ticket Created
- [ ] Workaround Implemented
- [ ] Awaiting TIBCO Response
- [ ] Resolution Confirmed

---

## Issue #2: Certificate SAN Requirements - Wildcard vs Specific Hostnames

### **Issue Summary**
Documentation recommends wildcard certificates, but many enterprise customers cannot obtain wildcard certificates and require specific hostname entries in Subject Alternative Names (SAN).

---

### **Product Information**
- **Product**: TIBCO Platform - Control Plane
- **Documentation**: Control Plane deployment guides (AKS, EKS, ARO, GKE)
- **Affected Areas**: Certificate generation, DNS setup, ingress configuration

---

### **Issue Description**

Current documentation recommends using wildcard certificates for Control Plane ingress:

```
subjectAltName = \
    DNS:*.local.example.com,\
    DNS:*.cp1-my.local.example.com,\
    DNS:*.cp1-tunnel.local.example.com
```

However, many enterprise customers have security policies or PKI constraints that prevent them from obtaining wildcard certificates. They need guidance on using specific hostnames instead.

---

### **Current Documentation Recommendations**

**From various setup guides:**
- "You can use wildcard domain names for these control plane application and hybrid connectivity domains"
- "Create wildcard certificates for `*.<TP_MY_DOMAIN>` and `*.<TP_TUNNEL_DOMAIN>`"
- "One wildcard certificate covers all current and future subdomains"

---

### **Customer Requirements**

Customers need to request certificates with **specific hostnames** where `*` is replaced with actual subscription or admin names:

```
subjectAltName = \
    DNS:admin.cp1-my.local.example.com,\
    DNS:subscription1.cp1-my.local.example.com,\
    DNS:subscription2.cp1-my.local.example.com,\
    DNS:admin.cp1-tunnel.local.example.com,\
    DNS:subscription1.cp1-tunnel.local.example.com,\
    DNS:subscription2.cp1-tunnel.local.example.com
```

---

### **Business Impact**

- **Compliance**: Many organizations cannot use wildcard certificates due to security policies
- **PKI Constraints**: Enterprise PKI systems often restrict wildcard certificate issuance
- **Deployment Blockers**: Customers cannot proceed with deployment without proper certificate guidance
- **Planning Issues**: Customers need to know all required hostnames upfront to request certificates

---

### **Requested Documentation Updates**

1. **Add section on non-wildcard certificate alternatives** in deployment guides:
   - How to determine required hostnames based on subscriptions
   - Example SAN configurations for different scenarios
   - Certificate request templates for enterprise PKI

2. **Update certificate generation scripts** to support both modes:
   - Wildcard mode (current default)
   - Specific hostname mode (new option)

3. **Provide hostname planning guide**:
   - List of required admin hostnames
   - Pattern for subscription-based hostnames
   - Capability-specific hostnames (e.g., flogo, messaging)

4. **Update cert.config examples** in:
   - `/workshop-tibco-platform/scripts/cert.config`
   - Control Plane deployment documentation

---

### **Proposed Solution**

Add alternative certificate configuration examples:

```ini
# Option 1: Wildcard certificates (current recommendation)
[ext_wildcard]
subjectAltName = \
    DNS:*.cp1-my.local.example.com,\
    DNS:*.cp1-tunnel.local.example.com

# Option 2: Specific hostnames (for restricted environments)
[ext_specific]
subjectAltName = \
    DNS:admin.cp1-my.local.example.com,\
    DNS:sub1.cp1-my.local.example.com,\
    DNS:sub2.cp1-my.local.example.com,\
    DNS:admin.cp1-tunnel.local.example.com,\
    DNS:sub1.cp1-tunnel.local.example.com,\
    DNS:sub2.cp1-tunnel.local.example.com
```

---

### **Affected Documentation**

1. `/tp-helm-charts/docs/workshop/aks/control-plane/README.md`
2. `/tp-helm-charts/docs/workshop/eks/control-plane/README.md`
3. `/tp-helm-charts/docs/workshop/aro/control-plane/README.md`
4. `/tp-helm-charts/docs/workshop/gke/control-plane/README.md`
5. `/workshop-tp-aro/howto/how-to-cp-and-dp-openshift-aro-aks-setup-guide.md`
6. `/workshop-tibco-platform/scripts/cert.config`

---

### **Status**
- [ ] Documentation Updated
- [ ] Scripts Enhanced
- [ ] Customer Notified
- [ ] Review Complete

---

## Notes

- **Date Created**: January 16, 2026
- **Reported By**: Customer Implementation Team
- **Priority**: High (blocking deployments)
- **Category**: Product Enhancement / Documentation
