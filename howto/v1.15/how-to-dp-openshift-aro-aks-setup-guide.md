---
layout: default
title: How to Set Up ARO Cluster for Data Plane Only (v1.15.0)
---

# How to Set Up ARO Cluster for Data Plane Only (v1.15.0)

> **Version:** 1.15.0 | **Platform:** Azure Red Hat OpenShift (ARO) | **Last Updated:** March 10, 2026

**📌 Important Version Information**
- This guide is for TIBCO Platform Data Plane **version 1.15.0** connecting to SaaS Control Plane
- For version 1.14.0 documentation, see [v1.14 guide](../v1.14/how-to-dp-openshift-aro-aks-setup-guide)
- For Control Plane + Data Plane setup, see [CP+DP Guide](./how-to-cp-and-dp-openshift-aro-aks-setup-guide)

## Table of Contents
- [Overview](#overview)
- [What's New in v1.15.0](#whats-new-in-v150)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Deployment Steps](#deployment-steps)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

---

## Overview

This guide provides instructions for deploying **TIBCO Platform Data Plane version 1.15.0** on Azure Red Hat OpenShift (ARO), connecting to an existing TIBCO Platform SaaS Control Plane.

### What You'll Deploy
- **Azure Red Hat OpenShift (ARO) Cluster** with appropriate node sizing
- **TIBCO Platform Data Plane 1.15.0** infrastructure
- **Data Plane Capabilities** (BWCE, Flogo)
- **OpenShift Router** for ingress routing
- **Hybrid Connectivity** to SaaS Control Plane
- **Azure Storage** - Azure Disk and Azure Files storage classes

### Deployment Time
- **Total Duration:** 1-2 hours
- **ARO Setup:** 30-45 minutes
- **Data Plane Infrastructure:** 30-45 minutes
- **Capability Provisioning:** 15-30 minutes

---

## What's New in v1.15.0

### Breaking Changes
- ⚠️ **Helm 3.13+ Required**: New label-based deployment tracking
- ⚠️ **Network Policy Updates**: Enhanced namespace labeling requirements
- ⚠️ **Infrastructure Chart Changes**: New `dp-core-infrastructure` chart structure
- ⚠️ **Bootstrap Configuration**: New connection parameters for SaaS CP
- ⚠️ **OpenShift Router Support**: Native OpenShift Router integration

### New Features
- ✅ **Simplified Infrastructure Chart**: `dp-core-infrastructure` 1.15.8
- ✅ **Enhanced Observability**: Improved metrics and logging integration
- ✅ **Better Network Policies**: Label-based isolation
- ✅ **OpenShift SCC Support**: Better Security Context Constraints integration
- ✅ **Gateway API Support**: Modern ingress configuration options

### Compatibility
- **OpenShift:** 4.14+ on Azure Red Hat OpenShift (ARO)
- **Helm:** 3.13+
- **Azure:** ARO with OpenShift 4.14+
- **Control Plane:** TIBCO Platform SaaS CP (latest version recommended)

---

## Prerequisites

### 1. Azure Requirements
- ✅ **Azure Subscription** with appropriate permissions
- ✅ **Resource Group** or permissions to create one
- ✅ **Azure CLI** installed and configured (version 2.50+)
- ✅ **OpenShift CLI (oc)** installed (version 4.14+)
- ✅ **kubectl** installed (version 1.27+)
- ✅ **Helm 3.13+** installed (required for label support)

### 2. ARO Cluster Specifications
- **OpenShift Version:** 4.14 or higher
- **Worker Node Count:** Minimum 3 worker nodes
- **Worker Node Size:** Standard_D4s_v3 or higher (4 vCPUs, 16GB RAM per node)
- **Total Resources:** 12+ CPU cores, 48+ GB RAM minimum for workers
- **Network:** Virtual Network with appropriate subnet sizing
- **Storage:** Azure Disk (Premium_LRS) + Azure Files

### 3. SaaS Control Plane Requirements
- ✅ **Active TIBCO Platform SaaS subscription**
- ✅ **Control Plane URL** (e.g., `https://your-org.cic2.tibcocloud.com`)
- ✅ **Service Account** credentials for Data Plane registration
- ✅ **Network connectivity** from ARO to SaaS Control Plane

### 4. Tools and Software
- **Azure CLI:** Version 2.50 or later (`az version`)
- **OpenShift CLI (oc):** Version 4.14+ (`oc version`)
- **Helm:** Version 3.13+ (`helm version`)
- **kubectl:** Version 1.27+ (`kubectl version`)
- **Git:** For cloning tp-helm-charts repository

### 5. Access Requirements
- ✅ **TIBCO Container Registry** access (csgprduswrepoedge.jfrog.io)
- ✅ **Red Hat Pull Secret** for ARO
- ✅ **Domain Name** for Data Plane applications (if exposing publicly)

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────┐
│   TIBCO Platform SaaS Control Plane    │
│   (your-org.cic2.tibcocloud.com)       │
└────────────────┬────────────────────────┘
                 │
                 │ Hybrid Connectivity
                 │ (TLS/HTTPS)
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              Azure Red Hat OpenShift (ARO)                  │
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │         Data Plane Namespace                 │          │
│  │                                              │          │
│  │  - dp-core-infrastructure (1.15.8)          │          │
│  │  - BWCE Capability                           │          │
│  │  - Flogo Capability                          │          │
│  │  - Observability Integration                 │          │
│  │  - Application Deployments                   │          │
│  └──────────────────────────────────────────────┘          │
│                         │                                   │
│  ┌──────────────────────▼────────────────────────┐         │
│  │     OpenShift Router (Ingress)                │         │
│  └───────────────────────────────────────────────┘         │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          ▼
                   Azure DNS Zone
                   (*.dp-aro.example.com)
```

---

## Deployment Steps

### Overview

This guide follows a simplified deployment approach for Data Plane v1.15.0 on ARO:

1. **Azure Environment Setup** - Create ARO cluster
2. **Storage Configuration** - Configure Azure Disk and Files storage classes
3. **Data Plane Bootstrap** - Register Data Plane with SaaS Control Plane
4. **Infrastructure Deployment** - Install dp-core-infrastructure 1.15.8
5. **Capability Provisioning** - Install BWCE and Flogo capabilities via Control Plane UI

### Detailed Steps

For detailed step-by-step instructions, please refer to:

#### 📖 Official TIBCO Documentation

- [Data Plane Installation Guide](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/installing-data-plane.htm)
- [OpenShift Data Plane Configuration](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/openshift-data-plane.htm)
- [Hybrid Connectivity Setup](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/hybrid-connectivity.htm)

#### 🔧 Key Configuration Changes for v1.15.0

**1. ARO Cluster Creation**
```bash
# Create ARO cluster with appropriate sizing
az aro create \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --vnet <vnet-name> \
  --master-subnet <master-subnet> \
  --worker-subnet <worker-subnet> \
  --worker-vm-size Standard_D4s_v3 \
  --worker-count 3 \
  --pull-secret @pull-secret.txt
```

**2. Security Context Constraints (OpenShift-Specific)**
```bash
# Apply required SCCs for Data Plane
oc adm policy add-scc-to-user anyuid -z default -n <dp-namespace>
oc adm policy add-scc-to-user privileged -z default -n <dp-namespace>
```

**3. Data Plane Bootstrap Secret**
```bash
# Obtain bootstrap credentials from SaaS Control Plane
# Create bootstrap secret for Data Plane registration
kubectl create secret generic dp-bootstrap-secret \
  --from-literal=CP_URL="https://your-org.cic2.tibcocloud.com" \
  --from-literal=CP_SERVICE_ACCOUNT="<service-account>" \
  --from-literal=CP_SERVICE_ACCOUNT_PASSWORD="<password>" \
  -n <dp-namespace>
```

**4. Install dp-core-infrastructure with Labels (v1.15.0)**
```bash
# Install Data Plane infrastructure with Helm 3.13+
helm install dp-infra \
  --namespace <dp-namespace> \
  --labels layer=0 \
  -f dp-values.yaml \
  tibco-platform/dp-core-infrastructure
```

**5. Network Policies**
Enhanced namespace labels required:
```yaml
metadata:
  labels:
    platform.tibco.com/workload-type: "data-plane"
    platform.tibco.com/dataplane-id: "<dp-id>"
```

**6. Storage Classes** (OpenShift-Specific)
```yaml
# Azure Disk storage class for OpenShift
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-premium
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed

# Azure Files storage class for OpenShift
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files
provisioner: kubernetes.io/azure-file
parameters:
  storageAccount: <storage-account-name>
  resourceGroup: <resource-group>
```

---

## Troubleshooting

### Common Issues

**1. Helm Version Compatibility**
```bash
# Error: Unknown flag --labels
# Solution: Upgrade to Helm 3.13+
helm version  # Must be 3.13.0 or higher
```

**2. OpenShift SCC Issues**
```bash
# Error: cannot set securityContext
# Solution: Apply required SCCs
oc describe scc anyuid
oc describe scc privileged
oc get pods -n <dp-namespace> -o yaml | grep -i "scc"
```

**3. Hybrid Connectivity Issues**
```bash
# Test connectivity to SaaS Control Plane
curl -k https://your-org.cic2.tibcocloud.com/health

# Check Data Plane registration status
kubectl get pods -n <dp-namespace> -l app=tibdp-bootstrap
kubectl logs -n <dp-namespace> <bootstrap-pod>
```

**4. Storage Class Issues**
```bash
# Verify storage classes are available
oc get storageclasses
oc describe storageclass azure-disk-premium
oc describe storageclass azure-files
```

**5. Network Policy Issues**
```bash
# Check namespace labels
kubectl get namespace <dp-namespace> --show-labels

# Verify network policies
kubectl get networkpolicies -n <dp-namespace>
```

### Getting Help

- **TIBCO Documentation**: [https://docs.tibco.com/pub/platform-cp/latest/doc/html/](https://docs.tibco.com/pub/platform-cp/latest/doc/html/)
- **Red Hat ARO Documentation**: [https://docs.openshift.com/container-platform/](https://docs.openshift.com/container-platform/)
- **TIBCO Support Portal**: Contact TIBCO Support with Data Plane logs

---

## Next Steps

### After Successful Deployment

1. **Verify Data Plane Registration**
   - Login to SaaS Control Plane
   - Navigate to Data Planes section
   - Verify your ARO Data Plane is registered and healthy

2. **Provision Capabilities via Control Plane UI**
   - BWCE (BusinessWorks Container Edition) capability
   - Flogo capability for integration flows
   - Messaging capability (EMS) if needed

3. **Deploy Sample Applications**
   - Create a sample BWCE application
   - Deploy via Control Plane UI
   - Test application routing via OpenShift routes

4. **Configure Observability** (Optional but Recommended)
   - Follow [Observability Setup Guide](../how-to-dp-openshift-observability)
   - Integrate with Control Plane observability
   - Set up local Prometheus and Grafana

5. **Production Readiness**
   - Review [Prerequisites Checklist](../prerequisites-checklist-for-customer)
   - Configure resource quotas and limits
   - Set up monitoring and alerting
   - Review security hardening for OpenShift

---

## Additional Resources

### Documentation
- [TIBCO Platform Release Notes v1.15.0](../../releases/v1.15.0)
- [ARO Firewall Requirements](../../docs/firewall-requirements-aro)
- [Prerequisites Checklist](../prerequisites-checklist-for-customer)

### Related Guides
- [Control Plane + Data Plane Setup (v1.15)](./how-to-cp-and-dp-openshift-aro-aks-setup-guide)
- [Observability Setup](../how-to-dp-openshift-observability)
- [DNS Management](../how-to-add-dns-records-aro-azure)
- [BW6 Driver Supplements](../how-to-upload-bw6-driver-supplements)

---

**Document Version:** 1.0 for TIBCO Platform DP 1.15.0  
**Last Updated:** March 10, 2026  
**Platform:** Azure Red Hat OpenShift (ARO)
