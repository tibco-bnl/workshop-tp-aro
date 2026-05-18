# TIBCO Platform v1.17.0 - ARO Documentation Summary

**Date Created:** May 18, 2026  
**Purpose:** Summary of v1.17.0 documentation updates for Azure Red Hat OpenShift (ARO)

## Documentation Updates Overview

This document summarizes the updates made to the workshop-tp-aro repository for TIBCO Platform version 1.17.0.

## Files Created/Updated

### New Files
1. **releases/v1.17.0.md** - Complete release notes for v1.17.0
2. **howto/v1.17/QUICK-REFERENCE.md** - Quick reference guide for v1.17.0 on ARO
3. **howto/v1.17/DOCUMENTATION-SUMMARY.md** - This file

### Modified Files
1. **README.md** - Updated to reference v1.17.0 as current release

### Primary Setup Guide
- **[howto/how-to-cp-and-dp-openshift-aro-aks-setup-guide.md](../how-to-cp-and-dp-openshift-aro-aks-setup-guide.md)** - Full CP + DP deployment walkthrough (latest). Includes hardened SCC configuration (`MustRunAsNonRoot`) with compatibility analysis for all TIBCO Platform charts.

## Key Changes in v1.17.0

### New Features

#### 1. Webhook Receiver for Alerts
- **External Integration**: Connect TIBCO Platform alerts to any external system via HTTP webhook
- **JSON Payload**: Standardized JSON payload format for easy integration
- **Use Cases**: PagerDuty, ServiceNow, Slack, Teams, custom notification systems

#### 2. OpenSearch Support for Observability
- **OpenSearch Backend**: Use OpenSearch (instead of or alongside Elasticsearch) for:
  - Jaeger distributed traces
  - Service logs from capabilities
- **ARO Impact**: May use OpenSearch Operator on OpenShift or external OpenSearch cluster
- **Index Templates**: Optimized templates for TIBCO Platform workloads

#### 3. Capability Management APIs
- **Update API (PUT)**: Update existing capability instances without full re-provisioning
- **Upgrade API**: Upgrade capability instances via API (useful for CI/CD automation)

#### 4. BW6 (Containers) - Custom Fluentbit
- **Configuration**: Set customized Fluentbit pipelines during provisioning or update
- **Capability Version**: Requires capability version 1.17.0+

#### 5. BW6 Classic - Full Lifecycle Management UI
- **Agent/Domain/AppSpace/AppNode/Application management** all available in Control Plane UI
- **Significant UI enhancement** for BW6 customers running classic (non-container) BW6

#### 6. BW5 Enhancements
- **Application History**: Audit trail for deploy/undeploy operations in Application Configuration
- **Custom Fluentbit**: Customized log forwarding configuration
- **Hawk REST API**: 31 Hawk methods exposed via REST on port 8090 in BW5CE

#### 7. Flogo Enhancements
- **Fluentbit via Helm**: Configure log forwarding as part of Helm deployment
- **Recipe Customization**: YAML editor for capability recipes in the UI
- **New Connectors**: Google Cloud Storage, TIBCO ActiveSpaces, TIBCO FTL

### Component Versions

All core components updated to version 1.17.0:

| Component | Version |
|-----------|---------|
| tibco-cp-base | 1.17.0 |
| tibco-cp-bw | 1.17.0 |
| tibco-cp-flogo | 1.17.0 |
| tibco-cp-devhub | 1.17.0 |
| tibco-cp-addon-eventprocessing | 1.17.0 |
| tp-dp-monitor-agent | 1.17.13 |
| tp-dp-license-file | 1.17.0 |
| tp-cp-proxy | 1.17.4 |

## ARO-Specific Considerations

### OpenSearch on OpenShift
- OpenSearch can be deployed using the OpenSearch Operator for Kubernetes/OpenShift
- Alternatively, use an external OpenSearch cluster (Azure-hosted or self-managed)
- Configure OpenShift Routes for OpenSearch endpoint exposure
- Recommended TLS termination: `reencrypt` for end-to-end TLS

### BW5CE Hawk API - Network Policy
- New port 8090 exposed by BW5CE pods requires NetworkPolicy updates
- Add ingress rules for port 8090 if using restrictive NetworkPolicies in DP namespace

### Webhook Receiver - Egress Requirements
- Control Plane namespace must have egress access to configured webhook endpoints
- Update ARO NSG and NetworkPolicy rules as needed for external webhook URLs

### Security Context Constraints (SCC)
- SCC configurations remain compatible from v1.16.0 to v1.17.0 (no breaking changes)
- Custom Fluentbit configurations in BW5/BW6 containers may require additional volume mounts — verify SCC allows the required hostPath or configMap mounts if used

## Upgrade Considerations

### Recommended Upgrade Path
1. **From v1.16.0 → v1.17.0**: Supported (direct upgrade)
2. **From v1.15.0 → v1.17.0**: Not recommended (upgrade to v1.16.0 first)
3. **From v1.14.0 → v1.17.0**: Multi-step: v1.14.0 → v1.15.0 → v1.16.0 → v1.17.0

### Post-Upgrade Actions
- If using OpenSearch for observability: apply index templates as documented
- If enabling Webhook Receiver: configure firewall/NSG egress rules
- If using BW5CE: verify port 8090 is accessible per your NetworkPolicy
- Review Flogo recipe customizations during next capability update cycle
