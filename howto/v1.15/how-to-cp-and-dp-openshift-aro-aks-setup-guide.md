---
layout: default
title: How to Set Up ARO Cluster with Control Plane and Data Plane (v1.15.0)
---

# How to Set Up ARO Cluster with Control Plane and Data Plane (v1.15.0)

> **Version:** 1.15.0 | **Platform:** Azure Red Hat OpenShift (ARO) | **Last Updated:** March 10, 2026

**📌 Important Version Information**
- This guide is for TIBCO Platform Control Plane **version 1.15.0**
- For version 1.14.0 documentation, see [v1.14 guide](../v1.14/how-to-cp-and-dp-openshift-aro-aks-setup-guide)
- For upgrade instructions from 1.14.0 to 1.15.0, see [Release Notes](../../releases/v1.15.0#upgrade-path)

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

This guide provides comprehensive instructions for deploying **TIBCO Platform Control Plane version 1.15.0** along with Data Plane on Azure Red Hat OpenShift (ARO).

### What You'll Deploy
- **Azure Red Hat OpenShift (ARO) Cluster** with appropriate node sizing
- **TIBCO Platform Control Plane 1.15.0** with enhanced security features
- **TIBCO Platform Data Plane 1.15.0** for running BWCE and Flogo applications
- **PostgreSQL 16** database for Control Plane metadata
- **OpenShift Router** for ingress routing
- **Azure Storage** - Azure Disk and Azure Files storage classes

### Deployment Time
- **Total Duration:** 3-4 hours
- **ARO Setup:** 45-60 minutes
- **Control Plane:** 1-1.5 hours
- **Data Plane:** 1-1.5 hours

---

## What's New in v1.15.0

### Breaking Changes
- ⚠️ **Helm 3.13+ Required**: New label-based deployment tracking
- ⚠️ **New Secret Requirements**: Session keys and encryption secrets now mandatory
- ⚠️ **Certificate Structure Changed**: Separate certificates for `my` and `tunnel` domains recommended
- ⚠️ **Network Policy Updates**: Enhanced namespace labeling requirements
- ⚠️ **OpenShift Router Support**: Native OpenShift Router now fully supported as Ingress Controller

### New Features
- ✅ **Unified Chart Deployment**: Simplified `tibco-cp-base` chart structure
- ✅ **Enhanced Security**: Improved secrets management and encryption
- ✅ **OpenShift SCC Support**: Better Security Context Constraints integration
- ✅ **Developer Hub 1.15.14**: Updated with new capabilities
- ✅ **Observability Service 1.15.19**: Enhanced monitoring integration
- ✅ **Event Processing**: New addon for event-driven architectures

### Compatibility
- **OpenShift:** 4.14+ on Azure Red Hat OpenShift (ARO)
- **Helm:** 3.13+
- **PostgreSQL:** 16.x
- **Azure:** ARO with OpenShift 4.14+

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
- **Worker Node Size:** Standard_D8s_v3 or higher (8 vCPUs, 32GB RAM per node)
- **Master Node Size:** Standard_D8s_v3 or higher
- **Total Resources:** 24+ CPU cores, 96+ GB RAM minimum for workers
- **Network:** Virtual Network with appropriate subnet sizing
- **Storage:** Azure Disk (Premium_LRS) + Azure Files

### 3. Tools and Software
- **Azure CLI:** Version 2.50 or later (`az version`)
- **OpenShift CLI (oc):** Version 4.14+ (`oc version`)
- **Helm:** Version 3.13+ (`helm version`)
- **kubectl:** Version 1.27+ (`kubectl version`)
- **Git:** For cloning tp-helm-charts repository
- **Text Editor:** For editing configuration files

### 4. Access Requirements
- ✅ **TIBCO Container Registry** access (csgprduswrepoedge.jfrog.io)
- ✅ **Red Hat Pull Secret** for ARO
- ✅ **Domain Name** for TIBCO Platform (e.g., `aro-tibco.example.com`)
- ✅ **DNS Management** access in Azure DNS or your DNS provider

### 5. Knowledge Prerequisites
- Basic understanding of Azure Red Hat OpenShift
- Familiarity with Helm charts and Kubernetes/OpenShift concepts
- Understanding of DNS and certificate management
- Basic Azure networking knowledge

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Red Hat OpenShift                  │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │  Control Plane       │      │  Data Plane          │   │
│  │  Namespace           │      │  Namespace           │   │
│  │                      │      │                      │   │
│  │  - IDM               │◄─────┤  - BWCE Apps         │   │
│  │  - Provisioner       │      │  - Flogo Apps        │   │
│  │  - Web Server        │      │  - Hybrid Conn.      │   │
│  │  - Developer Hub     │      │  - Observability     │   │
│  └──────────────────────┘      └──────────────────────┘   │
│            │                              │                │
│            ├──────────────────────────────┤                │
│            │                              │                │
│  ┌─────────▼──────────────────────────────▼─────────┐     │
│  │         OpenShift Router (Ingress)               │     │
│  └──────────────────────────────────────────────────┘     │
│                         │                                  │
└─────────────────────────┼──────────────────────────────────┘
                          │
                          ▼
                   Azure DNS Zone
                   (*.aro-tibco.example.com)
                          │
                          ▼
                  External PostgreSQL 16
```

---

## Deployment Steps

### Overview

This guide follows a simplified deployment approach for TIBCO Platform v1.15.0 on ARO:

1. **Azure Environment Setup** - Create ARO cluster and supporting resources
2. **Storage Configuration** - Configure Azure Disk and Files storage classes
3. **Security Setup** - Generate session keys, encryption secrets, and certificates
4. **PostgreSQL Setup** - Deploy PostgreSQL 16 database
5. **Control Plane Deployment** - Install TIBCO Platform Control Plane 1.15.0
6. **Data Plane Deployment** - Install Data Plane infrastructure and capabilities

### Detailed Steps

For detailed step-by-step instructions, please refer to:

#### 📖 Official TIBCO Documentation

- [TIBCO Platform 1.15.0 Installation Guide](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)
- [OpenShift-Specific Configuration](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/openshift-deployment.htm)
- [Enhanced Security Configuration](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/enhanced-security.htm)

#### 🔧 Key Configuration Changes for v1.15.0

**1. Session Keys Secret (NEW - Mandatory)**
```bash
# Generate session key and IV
export SESSION_KEY=$(openssl rand -base64 32)
export SESSION_IV=$(openssl rand -base64 16)

# Create secret in Control Plane namespace
kubectl create secret generic session-keys \
  --from-literal=SESSION_KEY="${SESSION_KEY}" \
  --from-literal=SESSION_IV="${SESSION_IV}" \
  -n <cp-namespace>
```

**2. Encryption Secret (NEW - Mandatory)**
```bash
# Generate encryption key
export CPORCH_ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create secret in Control Plane namespace
kubectl create secret generic cporch-encryption-secret \
  --from-literal=CPORCH_ENCRYPTION_KEY="${CPORCH_ENCRYPTION_KEY}" \
  -n <cp-namespace>
```

**3. Security Context Constraints (OpenShift-Specific)**
```bash
# Apply required SCCs for TIBCO Platform
oc adm policy add-scc-to-user anyuid -z default -n <cp-namespace>
oc adm policy add-scc-to-user privileged -z default -n <cp-namespace>
```

**4. Helm Deployment with Labels (v1.15.0 Requirement)**
```bash
# Install with Helm 3.13+ using labels
helm install tibco-cp-base \
  --namespace <cp-namespace> \
  --labels layer=0 \
  -f values.yaml \
  tibco-cp/tibco-cp-base
```

**5. Certificate Structure**
- Create separate certificates for `my.<domain>` and `tunnel.<domain>`
- Use wildcard certificates like `*.aro-tibco.example.com`
- Store in appropriate secret format for OpenShift

**6. Network Policies**
Enhanced namespace labels required:
```yaml
metadata:
  labels:
    platform.tibco.com/workload-type: "control-plane"
    platform.tibco.com/capability: "base"
```

---

## Troubleshooting

### Common Issues

**1. Session Keys or Encryption Secrets Missing**
```bash
# Error: Session keys secret not found
# Solution: Must create both secrets before installing CP
kubectl get secret session-keys -n <cp-namespace>
kubectl get secret cporch-encryption-secret -n <cp-namespace>
```

**2. Helm Version Compatibility**
```bash
# Error: Unknown flag --labels
# Solution: Upgrade to Helm 3.13+
helm version  # Must be 3.13.0 or higher
```

**3. OpenShift SCC Issues**
```bash
# Error: cannot set securityContext
# Solution: Apply required SCCs
oc describe scc anyuid
oc describe scc privileged
```

**4. Certificate Issues**
- Ensure certificates cover both `my.<domain>` and `tunnel.<domain>`
- Verify certificate format is compatible with OpenShift secrets
- Check certificate expiration dates

### Getting Help

- **TIBCO Documentation**: [https://docs.tibco.com/pub/platform-cp/latest/doc/html/](https://docs.tibco.com/pub/platform-cp/latest/doc/html/)
- **Red Hat ARO Documentation**: [https://docs.openshift.com/container-platform/](https://docs.openshift.com/container-platform/)
- **tp-helm-charts Repository**: [https://github.com/TIBCOSoftware/tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)

---

## Next Steps

### After Successful Deployment

1. **Access Control Plane UI**
   - Navigate to `https://admin.my.<your-domain>`
   - Login with admin credentials
   - Complete initial configuration

2. **Deploy Capabilities**
   - Install BWCE capability for BusinessWorks applications
   - Install Flogo capability for integration flows
   - Install Messaging capability (EMS) if needed

3. **Configure Observability** (Optional but Recommended)
   - Follow [Observability Setup Guide](../how-to-dp-openshift-observability)
   - Install Prometheus for metrics
   - Install Elastic ECK for logs

4. **Deploy Sample Applications**
   - Test BWCE application deployment
   - Test Flogo application deployment
   - Verify hybrid connectivity

5. **Production Readiness**
   - Review [Prerequisites Checklist](../prerequisites-checklist-for-customer)
   - Configure backup and disaster recovery
   - Set up monitoring and alerting
   - Review security hardening guidelines

---

## Additional Resources

### Documentation
- [TIBCO Platform Release Notes v1.15.0](../../releases/v1.15.0)
- [ARO Firewall Requirements](../../docs/firewall-requirements-aro)
- [Prerequisites Checklist](../prerequisites-checklist-for-customer)

### Related Guides
- [Data Plane Only Setup (v1.15)](./how-to-dp-openshift-aro-aks-setup-guide)
- [Observability Setup](../how-to-dp-openshift-observability)
- [DNS Management](../how-to-add-dns-records-aro-azure)
- [BW6 Driver Supplements](../how-to-upload-bw6-driver-supplements)

---

**Document Version:** 1.0 for TIBCO Platform CP 1.15.0  
**Last Updated:** March 10, 2026  
**Platform:** Azure Red Hat OpenShift (ARO)
