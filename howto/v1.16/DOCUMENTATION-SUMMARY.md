# TIBCO Platform v1.16.0 - ARO Documentation Summary

**Date Created:** April 10, 2026  
**Purpose:** Summary of v1.16.0 documentation updates for Azure Red Hat OpenShift (ARO)

## Documentation Updates Overview

This document summarizes the updates made to the workshop-tp-aro repository for TIBCO Platform version 1.16.0.

## Files Created/Updated

### New Files
1. **releases/v1.16.0.md** - Complete release notes for v1.16.0
2. **howto/v1.16/QUICK-REFERENCE.md** - Quick reference guide for v1.16.0 on ARO
3. **howto/v1.16/DOCUMENTATION-SUMMARY.md** - This file

### Modified Files
1. **README.md** - Updated to reference v1.16.0 as current release

### Primary Setup Guide
- **[howto/how-to-cp-and-dp-openshift-aro-aks-setup-guide.md](../how-to-cp-and-dp-openshift-aro-aks-setup-guide.md)** - Full CP + DP deployment walkthrough (latest). Includes hardened SCC configuration (`MustRunAsNonRoot`) with compatibility analysis for all TIBCO Platform charts.

## Key Changes in v1.16.0

### New Features

#### 1. License Management
- **90-day expiration warning** - Early notification for planning
- **30-day critical alert** - Important reminder
- **7-day final warning** - Urgent action needed
- **Enhanced dashboard** - Visual license status tracking

#### 2. BW6 AI Plugin 6.0.0
- **RAG Support**: Retrieval-Augmented Generation capabilities
- **AI Integration**: OpenAI, Azure OpenAI, custom models
- **Vector Databases**: Semantic search and embeddings
- **Natural Language**: Query data using natural language

#### 3. BW5 Monitoring Enhancements
- **Real-time metrics**: Improved process monitoring
- **Advanced alerts**: Better health indicators
- **Hawk integration**: Enhanced event correlation
- **Performance analytics**: Bottleneck identification

#### 4. Flogo Container Improvements
- **Init Containers**: Pre-initialization support
- **Sidecar Containers**: Auxiliary process patterns
- **Better Routing**: Optimized OpenShift Router integration

### Container Registry Change

⚠️ **Important Update:**

| Version | Registry URL | Repository |
|---------|-------------|------------|
| v1.15.0 | `csgprdeuwrepoedge.jfrog.io` | `tibco-platform-docker-prod` |
| v1.16.0 | `csgprdusw2reposaas.jfrog.io` | `tibco-platform-docker-dev` |

**Action Required:** Update image pull secrets when upgrading to v1.16.0

### Component Versions

All components updated to version 1.16.0:
- tibco-cp-base: 1.16.0
- Developer Hub: 1.16.0
sign-operator: 1.16.0
- BWCE Provisioner: 1.16.0
- Flogo Provisioner: 1.16.0
- BW5 Provisioner: 1.16.0
- Messaging (EMS/Gateway): 1.16.0
- Artifact Manager: 1.16.0

## ARO-Specific Considerations

### OpenShift Router
- Enhanced route termination options (edge, reencrypt, passthrough)
- Better TLS certificate management
- Improved session affinity for stateful apps

### Security Context Constraints (SCC)
- Updated SCC examples for all TIBCO components
- Better pod security configuration
- Enhanced RBAC for OpenShift environments

### Storage
- Azure Files integration optimized
- Azure Disk support enhanced
- Multiple storage class support per component

### Network
- Improved network policies for OpenShift SDN
- OVN-Kubernetes compatibility verified
- Better integration with Azure Load Balancer

## Upgrade Considerations

### Recommended Upgrade Path
1. **From v1.15.0 → v1.16.0**: Supported (direct upgrade)
2. **From v1.14.0 → v1.16.0**: Not recommended (upgrade to v1.15.0 first)

### Pre-Upgrade Checklist
- [ ] Backup all helm releases and values
- [ ] Backup OpenShift routes and services
- [ ] Update container registry credentials
- [ ] Review custom values files for compatibility
- [ ] Test upgrade in non-production first
- [ ] Verify minimum OpenShift version (4.12+, 4.14+ recommended)
- [ ] Ensure Helm 3.13+ installed

### Upgrade Steps Summary
1. Backup current installation
2. Update container registry secret
3. Update Helm repository
4. Upgrade Control Plane components
5. Verify all pods running
6. Test routes and applications

## Breaking Changes

### Required Updates
1. **Container Registry**: Must update to new registry URL and repository
2. **Image Pull Secrets**: Recreate with new credentials
3. **OpenShift Version**: Minimum 4.12, recommend 4.14+ for ARO

### Optional Configuration Changes
1. **Idle Session Timeout**: New optional parameter (default: 4 hours)
2. **Database Read/Write Split**: Optional configuration for scaling
3. **Resource Constraints**: New optional resource limit configurations

## Documentation Structure

### Version-Specific Guides
- **v1.16/** - Latest version (this release)
- **v1.15/** - Previous version (maintained for reference)
- **v1.14/** - Archived version

### Guide Types
1. **Control Plane + Data Plane**: Full deployment on single ARO cluster
2. **Data Plane Only**: Connect to SaaS Control Plane
3. **Observability**: Monitoring and logging setup

## Key Differences: AKS vs ARO

| Aspect | AKS | ARO |
|--------|-----|-----|
| **CLI** | kubectl | oc |
| **Ingress** | Ingress Resources | OpenShift Routes |
| **Registry** | Azure Container Registry | Same (JFrog) |
| **Storage** | Azure StorageClasses | OpenShift StorageClasses |
| **Security** | Pod Security Standards | Security Context Constraints |
| **Network** | Azure CNI / Kubenet | OpenShift SDN / OVN-Kubernetes |
| **Load Balancer** | Azure Load Balancer | Azure LB + OpenShift Router |

## Testing Status

### Validated On
- **OpenShift Version**: 4.14, 4.15
- **ARO Version**: Latest (as of April 2026)
- **Azure Region**: Multiple (West Europe, East US, etc.)
- **Helm Version**: 3.13+

### Test Scenarios
- ✅ Fresh installation of v1.16.0
- ✅ Upgrade from v1.15.0 to v1.16.0
- ✅ Control Plane + Data Plane on same cluster
- ✅ Data Plane only with SaaS Control Plane
- ✅ Observability stack deployment
- ✅ License management features
- ✅ BW6 AI Plugin capabilities (basic validation)
- ✅ Flogo init/sidecar containers

## Known Limitations

### ARO-Specific
1. **Azure Files Performance**: May be slower for database workloads (use Azure Disk)
2. **Default Routes**: May need custom domain configuration for production
3. **SCC Requirements**: Some components require custom Security Context Constraints

### General
1. **BW6 AI Plugin**: Requires additional AI service configuration (OpenAI, Azure OpenAI)
2. **License Alerts**: Email configuration required for notifications
3. **Read Replicas**: Database read/write split requires manual configuration

## Support and Resources

### Official Documentation
- [TIBCO Platform Docs](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm)
- [TIBCO Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [OpenShift Documentation](https://docs.openshift.com/)
- [ARO Documentation](https://learn.microsoft.com/en-us/azure/openshift/)

### Workshop Resources
- [Main README](../../README.md)
- [Quick Reference](./QUICK-REFERENCE.md)
- [Release Notes](../../releases/v1.16.0.md)

### Community
- [TIBCO Community](https://community.tibco.com/)
- [GitHub Issues](https://github.com/tibco-bnl/workshop-tp-aro/issues)

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-04-10 | Initial v1.16.0 documentation created | Workshop Team |
| 2026-04-10 | Release notes and quick reference added | Workshop Team |

---

**Status:** ✅ Complete  
**Version:** 1.16.0  
**Platform:** Azure Red Hat OpenShift (ARO)  
**Last Updated:** April 10, 2026
