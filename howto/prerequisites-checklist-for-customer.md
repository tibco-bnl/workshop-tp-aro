---
layout: default
title: TIBCO Platform - Customer Prerequisites Checklist
---

# TIBCO Platform - Customer Prerequisites Checklist

**Document Purpose**: This checklist outlines the requirements that must be in place **before** TIBCO Platform Control Plane and Data Plane installation begins.

**Target Audience**: Customer IT teams responsible for infrastructure preparation

**Last Updated**: January 19, 2026

---

## Overview

Before TIBCO implementation team arrives on-site or begins remote installation, please ensure all prerequisites listed in this document are met. This preparation is critical for a successful and timely deployment.

**Estimated Preparation Time**: 3-5 business days (depending on organizational processes)

---

## 1. Kubernetes/OpenShift Cluster Requirements

> **Note**: TIBCO Control Plane supports Cloud Native Computing Foundation (CNCF) certified Kubernetes platforms.

### Control Plane Cluster

| Requirement | Specification | Notes |
|-------------|--------------|-------|
| **Cluster Type** | CNCF certified Kubernetes or OpenShift | Managed clusters (AKS, EKS, ARO) preferred |
| **Cluster Access** | `kubectl`/`oc` CLI with admin permissions | Must be able to create namespaces, CRDs, and cluster roles |
| **Cluster Nodes** | Minimum 3 worker nodes | For high availability |
| **Node Resources (per node)** | 8 CPU cores, 32 GB RAM minimum | Control Plane is resource-intensive |
| **Total Cluster Capacity** | 24+ CPU cores, 96+ GB RAM | Ensure sufficient headroom for Control Plane workloads |
| **Kubernetes API Access** | Stable network connectivity | Required for helm operations |

### Data Plane Cluster(s)

| Requirement | Specification | Notes |
|-------------|--------------|-------|
| **Cluster Type** | CNCF certified Kubernetes or OpenShift | Can be same cluster as Control Plane for dev/test |
| **Cluster Access** | `kubectl`/`oc` CLI with admin permissions | Per Data Plane cluster |
| **Node Resources** | Based on workload requirements | Minimum 4 CPU cores, 16 GB RAM per node |
| **Network Connectivity** | Bidirectional HTTPS to Control Plane | See network requirements section |

---

## 2. Access and Credentials

### Required Access

| Access Type | Details | Must Have Before Installation |
|-------------|---------|------------------------------|
| **Kubernetes/OpenShift Admin** | Cluster-admin or equivalent RBAC | ✅ Required |
| **Container Registry** | Pull credentials for TIBCO images | ✅ Required |
| **DNS Management** | Ability to create DNS records | ✅ Required for Control Plane |
| **Certificate Authority** | Ability to request/generate SSL certificates | ✅ Required for Control Plane |
| **Cloud Provider Console** | Access to Azure/AWS/GCP console (if applicable) | ✅ Required for managed services |
| **PostgreSQL Admin** | Database admin credentials | ✅ Required for Control Plane |

### Tools Required on Installation Machine

| Tool | Version | Purpose |
|------|---------|---------|
| `kubectl` or `oc` | Latest stable | Kubernetes cluster management |
| `helm` | 3.17.0+ | Chart deployment |
| `openssl` | 1.1+ | Certificate generation |
| `curl` / `wget` | Latest | Download scripts and charts |
| `jq` | 1.6+ | JSON processing (optional but recommended) |
| `git` | Latest | Clone repositories (if needed) |

---

## 3. Network Requirements

### Control Plane Network Requirements

| Network Configuration | Requirement | Details |
|----------------------|-------------|---------|
| **Internet Access** | Outbound HTTPS (443) | To pull container images from TIBCO registry |
| **DNS Resolution** | Internal and external | Must resolve both cluster services and internet domains |
| **Load Balancer** | Available (for managed clusters) | Azure LB, AWS NLB/ALB, or equivalent |
| **Firewall Rules** | Allow required ports | See port table below |

### Data Plane Network Requirements

| Network Configuration | Requirement | Details |
|----------------------|-------------|---------|
| **Control Plane Connectivity** | HTTPS (443) to CP domains | Both `my` and `tunnel` domains |
| **Internet Access** | Outbound HTTPS (443) | To pull container images |
| **DNS Resolution** | Internal and external | Must resolve Control Plane domains |

### Required Network Ports

| Source | Destination | Port | Protocol | Purpose |
|--------|------------|------|----------|---------|
| User Browser | Control Plane Ingress | 443 | HTTPS | Control Plane UI access |
| Data Plane | Control Plane (`my` domain) | 443 | HTTPS | Platform API communication |
| Data Plane | Control Plane (`tunnel` domain) | 443 | HTTPS | Hybrid connectivity |
| Control Plane Pods | PostgreSQL | 5432 | TCP | Database access |
| Control Plane Pods | Container Registry | 443 | HTTPS | Image pulls |

---

## 4. Storage Requirements

### Control Plane Storage

| Storage Type | Size | Performance | Use Case | Storage Class Required |
|--------------|------|-------------|----------|----------------------|
| **File Storage** | 100 GB | ReadWriteMany (RWX) | Shared configurations, logs | Azure Files, EFS, NFS |
| **Block Storage** | 50 GB | ReadWriteOnce (RWO) | PostgreSQL database | Azure Disk, EBS, SSD |

### Data Plane Storage

| Storage Type | Size | Performance | Use Case | Storage Class Required |
|--------------|------|-------------|----------|----------------------|
| **File Storage** | 50 GB per namespace | ReadWriteMany (RWX) | Application deployments | Azure Files, EFS, NFS |
| **Block Storage** | As needed | ReadWriteOnce (RWO) | Application-specific storage | Cluster default storage class |

### Storage Class Verification

**Must be completed before installation:**

```bash
# Verify storage classes exist
kubectl get storageclass

# Required storage classes must show:
# - One with RWX capability (File storage)
# - One with RWO capability (Block storage)
```

---

## 5. PostgreSQL Database (Control Plane Only)

### Database Requirements

| Requirement | Specification | Critical Notes |
|-------------|--------------|----------------|
| **Version** | PostgreSQL 16 | Must be version 16 |
| **Database Size** | 50 GB initial, 200 GB recommended | Grows with platform usage |
| **Connection Limit** | Minimum 100 concurrent connections | Default PostgreSQL is 100 |
| **Extensions Required** | `uuid-ossp` | **Must be enabled before installation** |
| **Network Access** | Accessible from Control Plane pods | Port 5432 (default) |
| **Credentials** | Master user with database creation privileges | Required for schema setup |
| **SSL/TLS** | Optional but recommended | If enabled, provide root certificate |

### Database Naming Convention Restrictions

> **⚠️ CRITICAL REQUIREMENT**
> 
> The `controlPlaneInstanceId` (e.g., `cp1`) is used as a database name prefix. PostgreSQL identifiers **CANNOT contain hyphens (-)**.
>
> **Valid Instance ID examples**: `cp1`, `nxpcp`, `nxp_tibco_cp`, `prod1`  
> **Invalid examples**: `nxp-tibco-cp` ❌, `my-control-plane` ❌
>
> **Databases created**: `{instanceId}_tscidmdb`, `{instanceId}_defaultidpdb`, etc.

### Database Options

**Option 1: On-Premises PostgreSQL** (Deployed in cluster)
- TIBCO provides Helm chart for PostgreSQL
- Uses cluster disk storage
- Suitable for dev/test environments

**Option 2: Managed PostgreSQL Service** (Recommended for Production)
- Azure Database for PostgreSQL Flexible Server
- AWS RDS PostgreSQL
- Google Cloud SQL for PostgreSQL
- Requires connection details and SSL certificates (if enabled)

### Required Database Information

Please provide the following **before installation day**:

- [ ] Database host/endpoint: `_______________________`
- [ ] Database port: `_______________________` (default: 5432)
- [ ] Database name: `_______________________` (typically: `postgres`)
- [ ] Master username: `_______________________`
- [ ] Master password: `_______________________` (will be stored securely)
- [ ] SSL mode: `_______________________` (disable/require/verify-ca/verify-full)
- [ ] SSL root certificate (if SSL enabled): `_______________________`

---

## 6. DNS and Domain Requirements (Control Plane)

### DNS Zones Required

| DNS Zone Purpose | Pattern | Example | DNS Records Needed |
|-----------------|---------|---------|-------------------|
| **Control Plane UI** | `{instanceId}-my.{domain}` | `cp1-my.apps.example.com` | Wildcard or specific A/CNAME |
| **Hybrid Connectivity** | `{instanceId}-tunnel.{domain}` | `cp1-tunnel.apps.example.com` | Wildcard or specific A/CNAME |

### DNS Management Access

- [ ] Can create DNS A or CNAME records in required zones
- [ ] DNS propagation time acceptable (typically < 30 minutes)
- [ ] DNS zones support wildcard records OR can create specific records

### Wildcard vs Specific DNS Records

**Option 1: Wildcard DNS** (Easier, Recommended)
```
*.cp1-my.apps.example.com → <LoadBalancer-IP>
*.cp1-tunnel.apps.example.com → <LoadBalancer-IP>
```

**Option 2: Specific Hostnames** (Required if wildcards not allowed)
```
admin.cp1-my.apps.example.com → <LoadBalancer-IP>
subscription1.cp1-my.apps.example.com → <LoadBalancer-IP>
subscription2.cp1-my.apps.example.com → <LoadBalancer-IP>
# (Pattern repeats for tunnel domain)
```

**Note**: If wildcard DNS is not allowed, provide list of expected subscription names in advance.

---

## 7. SSL/TLS Certificates (Control Plane)

### Certificate Requirements

| Certificate For | Subject Alternative Names (SANs) | Certificate Type |
|----------------|----------------------------------|------------------|
| **Control Plane UI** | See SAN examples below | Standard SSL certificate |
| **Hybrid Connectivity** | See SAN examples below | Standard SSL certificate |

### Certificate SAN Examples

**Option 1: Wildcard Certificates** (Easier, Recommended)
```
DNS: *.cp1-my.apps.example.com
DNS: *.cp1-tunnel.apps.example.com
```

**Option 2: Specific Hostnames** (If wildcards not allowed by PKI policy)
```
DNS: admin.cp1-my.apps.example.com
DNS: subscription1.cp1-my.apps.example.com
DNS: subscription2.cp1-my.apps.example.com
DNS: admin.cp1-tunnel.apps.example.com
DNS: subscription1.cp1-tunnel.apps.example.com
DNS: subscription2.cp1-tunnel.apps.example.com
```

### Required Certificate Information

Please provide **before installation day**:

- [ ] Certificate file (PEM format): `_______________________`
- [ ] Private key file (PEM format): `_______________________`
- [ ] Certificate chain/intermediate certificates: `_______________________`
- [ ] Certificate expiration date: `_______________________`
- [ ] Certificate issued by: `_______________________`

### Self-Signed Certificates

- Acceptable for dev/test environments
- TIBCO can generate during installation if needed
- Not recommended for production

---

## 8. Container Registry Access

### TIBCO Container Registry

| Requirement | Details |
|-------------|---------|
| **Registry URL** | Provided by TIBCO (e.g., `csgprdusw2reposaas.jfrog.io`) |
| **Credentials** | Username and password/token provided by TIBCO |
| **Network Access** | Outbound HTTPS (443) from cluster to registry |
| **Image Pull Secret** | Will be created during installation |

### Required Information

- [ ] TIBCO registry URL: `_______________________`
- [ ] Registry username: `_______________________`
- [ ] Registry password/token: `_______________________`
- [ ] Can pull images from registry (test before installation day)

### Network Connectivity Test

```bash
# Test registry access from installation machine
curl -u "username:password" https://<registry-url>/v2/_catalog
```

---

## 9. Kubernetes Secrets (Created During Installation)

The following Kubernetes secrets will be created during the TIBCO Platform installation. Ensure you have the necessary permissions and information ready.

### Control Plane Secrets

#### 1. Container Registry Pull Secret

**Secret Name**: `tibco-container-registry-credentials`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Authenticate and pull TIBCO Platform container images from JFrog registry

**Creation Command**:
```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server=<REGISTRY_URL> \
  --docker-username=<REGISTRY_USERNAME> \
  --docker-password=<REGISTRY_PASSWORD> \
  --docker-email=<YOUR_EMAIL> \
  -n <CP_INSTANCE_ID>-ns
```

**Required Information**:
- Registry URL (e.g., `csgprdusw2reposaas.jfrog.io`)
- Registry username (provided by TIBCO)
- Registry password/token (provided by TIBCO)
- Email address

#### 2. Session Keys Secret (Required)

**Secret Name**: `session-keys`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Session encryption keys required by router pods and web-server components

**Creation Command**:
```bash
# Generate random 32-character alphanumeric keys
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create secret
kubectl create secret generic session-keys -n <CP_INSTANCE_ID>-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
```

**Keys**:
- `TSC_SESSION_KEY`: 32-character alphanumeric string
- `DOMAIN_SESSION_KEY`: 32-character alphanumeric string

> **⚠️ Important**: This secret is mandatory. Router pods will fail to start if this secret is missing.

#### 3. Database Credentials Secret (Optional - Auto-Created)

**Secret Name**: `{instanceId}-postgres-credential` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Store PostgreSQL database credentials for Control Plane components

> **ℹ️ Note**: This secret is **automatically created** by the Control Plane helm chart during installation. Manual creation is only needed if using a custom secret name or pre-creating for specific requirements.

**Manual Creation Command** (if needed):
```bash
kubectl create secret generic <SECRET_NAME> \
  --from-literal=db_username=<DB_USERNAME> \
  --from-literal=db_password=<DB_PASSWORD> \
  -n <CP_INSTANCE_ID>-ns
```

**Keys**:
- `db_username`: PostgreSQL master username
- `db_password`: PostgreSQL master password

#### 4. Database SSL Certificate Secret (If Using SSL)

**Secret Name**: `db-ssl-root-cert` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: SSL certificate for secure PostgreSQL connection (Azure, AWS RDS, etc.)

**Creation Command**:
```bash
kubectl create secret generic db-ssl-root-cert \
  --from-file=db_ssl_root.cert=<PATH_TO_CERT_FILE> \
  -n <CP_INSTANCE_ID>-ns
```

> **⚠️ Critical**: The secret key **must** be named `db_ssl_root.cert` (with a dot, not underscore). This is required by TIBCO Platform.

#### 5. TLS/SSL Certificate Secrets for Ingress

**Secret Names**: 
- `tp-certificate-my` (Control Plane UI domain)
- `tp-certificate-tunnel` (Hybrid connectivity domain)

**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: TLS certificates for HTTPS ingress to Control Plane domains

**Creation Command**:
```bash
# For Control Plane UI domain
kubectl create secret tls tp-certificate-my \
  --cert=<PATH_TO_CERT_FILE> \
  --key=<PATH_TO_KEY_FILE> \
  -n <CP_INSTANCE_ID>-ns

# For tunnel domain
kubectl create secret tls tp-certificate-tunnel \
  --cert=<PATH_TO_CERT_FILE> \
  --key=<PATH_TO_KEY_FILE> \
  -n <CP_INSTANCE_ID>-ns
```

**Required Files**:
- Certificate file (PEM format)
- Private key file (PEM format)

#### 6. Encryption Secret

**Secret Name**: `cporch-encryption-secret`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Encryption key for orchestrator component

**Creation Command**:
```bash
# Generate random encryption key
export ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic cporch-encryption-secret -n <CP_INSTANCE_ID>-ns \
  --from-literal=ENCRYPTION_KEY=${ENCRYPTION_KEY}
```

#### 7. SMTP Credentials Secret (Optional)

**Secret Name**: `smtp-credentials` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: SMTP server authentication for email notifications

**Creation Command**:
```bash
kubectl create secret generic smtp-credentials \
  --from-literal=smtp-username=<SMTP_USERNAME> \
  --from-literal=smtp-password=<SMTP_PASSWORD> \
  -n <CP_INSTANCE_ID>-ns
```

### Data Plane Secrets

#### 1. Container Registry Pull Secret

**Secret Name**: `tibco-container-registry-credentials`  
**Namespace**: `{dataplaneId}-ns` (Data Plane namespace)  
**Purpose**: Pull TIBCO Platform images for Data Plane capabilities

**Creation Command**: Same as Control Plane container registry secret (section 9.1)

### Secrets Checklist

Before installation, ensure you have the following information ready to create secrets:

- [ ] **Container Registry Credentials**:
  - [ ] Registry URL
  - [ ] Username
  - [ ] Password/token
  - [ ] Email address

- [ ] **Database Credentials**:
  - [ ] Master username
  - [ ] Master password
  - [ ] SSL certificate file (if using SSL)

- [ ] **TLS Certificates**:
  - [ ] Certificate files for `my` domain (PEM format)
  - [ ] Private key files for `my` domain (PEM format)
  - [ ] Certificate files for `tunnel` domain (PEM format)
  - [ ] Private key files for `tunnel` domain (PEM format)

- [ ] **SMTP Credentials** (optional):
  - [ ] SMTP username
  - [ ] SMTP password

> **Note**: Session keys and encryption keys will be generated during installation using `openssl` commands.

### RBAC Requirements for Secret Management

Ensure the installation account has the following permissions in target namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tibco-secret-manager
  namespace: <namespace>
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

---

## 10. RBAC and Permissions

### Kubernetes/OpenShift Permissions Required

| Resource Type | Operations Needed | Scope |
|--------------|-------------------|-------|
| **Namespaces** | Create, delete, list | Cluster-wide |
| **CRDs** | Create, update, list | Cluster-wide |
| **ClusterRoles** | Create, bind | Cluster-wide |
| **ClusterRoleBindings** | Create, delete | Cluster-wide |
| **ServiceAccounts** | Create in CP/DP namespaces | Namespace-scoped |
| **Secrets** | Create, read, update | Namespace-scoped |
| **ConfigMaps** | Create, read, update | Namespace-scoped |
| **Services** | Create, expose | Namespace-scoped |
| **Ingress/Routes** | Create, configure | Namespace-scoped |
| **PVCs** | Create, delete | Namespace-scoped |

### OpenShift Specific (ARO/OCP)

| Requirement | Details |
|-------------|---------|
| **Security Context Constraints (SCC)** | Create custom SCC for TIBCO workloads |
| **Project Admin** | Ability to create projects (namespaces) |
| **Route Configuration** | Create and configure OpenShift routes |

---

## 11. Resource Quotas and Limits

### Ensure No Restrictive Quotas

Verify that the following quotas are NOT in place (or have sufficient headroom):

| Resource | Control Plane Namespace | Data Plane Namespace (per DP) |
|----------|------------------------|-------------------------------|
| **CPU Requests** | 20+ cores | 10+ cores |
| **Memory Requests** | 40+ GB | 20+ GB |
| **Persistent Volume Claims** | 5+ | 3+ |
| **Services** | 50+ | 30+ |
| **ConfigMaps** | 100+ | 50+ |
| **Secrets** | 100+ | 50+ |

```bash
# Check for resource quotas in target namespaces
kubectl get resourcequota -n <namespace>

# If quotas exist, ensure they allow TIBCO Platform requirements
```

---

## 12. Network Policies

### Ensure Network Policies Allow Required Traffic

If network policies are enforced, ensure:

- [ ] Control Plane pods can communicate with PostgreSQL
- [ ] Control Plane pods can reach container registry
- [ ] Data Plane pods can reach Control Plane ingress (`my` and `tunnel` domains)
- [ ] Ingress controller can route to Control Plane and Data Plane services
- [ ] DNS resolution works from all pods

---

## 13. Naming Conventions and Instance Identification

### Control Plane Instance ID

| Parameter | Constraint | Example |
|-----------|-----------|---------|
| **Format** | Alphanumeric or underscores only | `cp1`, `nxpcp`, `nxp_tibco_cp` |
| **Max Length** | 5 characters (recommended) | `cp1`, `prod1` |
| **Restrictions** | **NO HYPHENS (-)** | ❌ `nxp-cp`, ❌ `my-control-plane` |
| **Purpose** | Database prefix, namespace naming | Creates `cp1_tscidmdb`, `cp1-ns` |

**⚠️ Critical**: Hyphens cause PostgreSQL database creation failures!

### Namespace Naming

| Component | Namespace Pattern | Example |
|-----------|------------------|---------|
| **Control Plane** | `{instanceId}-ns` | `cp1-ns` |
| **Third-party services** | `tibco-ext` | `tibco-ext` (for PostgreSQL, etc.) |
| **Data Plane** | `{dataplaneId}-ns` | `dp1-ns` |

---

## 14. Email Server Configuration (Optional but Recommended)

For Control Plane notification emails (user invitations, password resets, etc.):

| Parameter | Details |
|-----------|---------|
| **SMTP Server** | Hostname/IP of SMTP server |
| **SMTP Port** | Typically 587 (STARTTLS) or 465 (SSL) or 25 |
| **Authentication** | Username and password (if required) |
| **From Address** | Email address for outgoing notifications |
| **TLS/SSL** | Enabled/Disabled |

**Alternative**: TIBCO can deploy a development mail server (MailDev) for testing purposes.

---

## 15. Browser Requirements (Control Plane UI Access)

### Supported Browsers

For accessing TIBCO Control Plane UI, current versions of the following browsers are supported:

| Browser | Version | Notes |
|---------|---------|-------|
| **Google Chrome** | Current version | Recommended |
| **Mozilla Firefox** | Current version | Fully supported |

> **Important**: Always use the latest stable version of supported browsers for optimal performance and security.

---

## 16. Ingress Controller

### Supported Ingress Controllers

TIBCO Platform supports the following ingress controllers:

#### Control Plane Ingress Controllers

| Ingress Controller | Version | Notes |
|-------------------|---------|-------|
| **NGINX** | 4.12.1 | ⚠️ **Deprecated from v1.10.0** - Active development ending per NGINX community |
| **Traefik** | 3.3.4 | Recommended alternative to NGINX |
| **OpenShift Router** | ocp-v4.0 | For OpenShift/ARO clusters |

#### Data Plane Ingress Controllers

| Ingress Controller | Version | Use Case |
|-------------------|---------|----------|
| **NGINX** | 4.12.1 | ⚠️ **Deprecated from v1.10.0** - Active development ending |
| **Traefik** | 3.3.4 | Data Plane services and apps |
| **Kong** | 2.33.3 | **BusinessWorks Container Edition and Flogo apps only** |
| **OpenShift Router** | ocp-v4.0 | OpenShift Data Plane only (default ingress controller) |

### Control Plane Requirements

| Requirement | Details |
|-------------|---------|
| **Ingress Controller** | One of the supported controllers listed above must be installed |
| **Ingress Class** | Configured and available (e.g., `traefik`, `openshift-default`) |
| **TLS Termination** | Ingress controller handles TLS termination |
| **Load Balancer** | External Load Balancer with public IP (for managed clusters) |
| **Wildcard Domain Support** | Must allow wildcard domains and inter-namespace ingress routing |

> **⚠️ Important**: NGINX ingress controller is **deprecated from TIBCO Control Plane 1.10.0 onwards**. Consider using Traefik as the recommended alternative.

#### OpenShift-Specific Configuration

For OpenShift/ARO clusters using the default router:

```bash
# Default ingress controller must be patched to allow wildcard domains
oc -n openshift-ingress-operator patch ingresscontroller/default --type='merge' \
  -p '{"spec":{"routeAdmission":{"namespaceOwnership":"InterNamespaceAllowed","wildcardPolicy":"WildcardsAllowed"}}}'
```

### Data Plane Requirements

| Requirement | Details |
|-------------|---------|
| **Ingress Controller** | Same as Control Plane or cluster default |
| **Ingress Class** | Configured for Data Plane workloads (must match provisioning wizard selection) |
| **Kong Ingress** | Only for BusinessWorks Container Edition and Flogo app endpoints |

> **Note**: Kong ingress controller (version 2.33.3) is supported only for BusinessWorks Container Edition and TIBCO Flogo application endpoints.

---

## Pre-Installation Checklist

Please complete this checklist and return to TIBCO implementation team **at least 2 business days** before installation date.

### Infrastructure Readiness

- [ ] Kubernetes/OpenShift cluster is running and accessible
- [ ] `kubectl`/`oc` CLI access with admin permissions verified
- [ ] Helm 3.17.0+ installed on installation machine
- [ ] Cluster has sufficient resources (CPU, memory, storage)
- [ ] Storage classes for RWX and RWO are available and tested
- [ ] No restrictive resource quotas in target namespaces

### Network and Connectivity

- [ ] Internet access from cluster verified (can pull images)
- [ ] DNS zones are available and accessible
- [ ] DNS record creation process is understood and ready
- [ ] Load balancer provisioning is available (for managed clusters)
- [ ] Required network ports are open (see network requirements)
- [ ] Network policies allow required traffic flows

### Database (Control Plane Only)

- [ ] PostgreSQL 16 is available (on-prem or managed service)
- [ ] Database endpoint, port, and credentials documented
- [ ] Master user has database creation privileges verified
- [ ] Database is accessible from cluster nodes/pods
- [ ] `uuid-ossp` extension is available
- [ ] SSL certificates obtained (if using SSL mode)
- [ ] Control Plane instance ID chosen (no hyphens!) and documented

### Security and Certificates

- [ ] SSL/TLS certificates obtained for Control Plane domains
- [ ] Certificate files in PEM format ready
- [ ] Private keys securely stored and accessible
- [ ] Container registry credentials received from TIBCO
- [ ] Container registry access tested and verified

### Secrets Preparation

- [ ] Container registry credentials (URL, username, password) ready
- [ ] Database credentials documented
- [ ] TLS certificate and key files prepared for ingress
- [ ] Database SSL certificate ready (if using managed PostgreSQL)
- [ ] SMTP credentials ready (if using email notifications)
- [ ] OpenSSL installed on installation machine (for generating session/encryption keys)

### Access and Permissions

- [ ] Kubernetes cluster admin access confirmed
- [ ] Cloud provider console access (if using managed services)
- [ ] DNS management access confirmed
- [ ] Database admin access confirmed
- [ ] Certificate authority access (if requesting new certificates)

### Documentation and Planning

- [ ] Control Plane instance ID decided: `_______________`
- [ ] Control Plane namespace name: `_______________`
- [ ] Data Plane namespace name(s): `_______________`
- [ ] DNS domains documented: 
  - Control Plane UI: `_______________`
  - Hybrid Connectivity: `_______________`
- [ ] Installation timezone and schedule confirmed
- [ ] Escalation contacts identified (for access/permissions issues)

### Optional but Recommended

- [ ] SMTP server details documented (for email notifications)
- [ ] Backup strategy planned for PostgreSQL database
- [ ] Monitoring/observability solution ready (for platform metrics)
- [ ] Log aggregation configured (for centralized logging)

---

## Completion Confirmation

**Customer Name**: _______________________________________________

**Project Name**: _______________________________________________

**Prepared By**: _______________________________________________

**Date Completed**: _______________________________________________

**Signature**: _______________________________________________

---

## Questions or Issues?

If you encounter any challenges completing these prerequisites, please contact:

**TIBCO Implementation Team**
- Email: _______________________
- Phone: _______________________
- Slack/Teams: _______________________

---

## Appendix: Quick Reference

### Minimum Resource Summary

**Control Plane Cluster:**
- 3+ worker nodes
- 24+ CPU cores total
- 96+ GB RAM total
- 150+ GB storage (RWX + RWO)
- PostgreSQL 16 database

**Data Plane Cluster:**
- 2+ worker nodes
- 8+ CPU cores total
- 32+ GB RAM total
- 50+ GB storage (RWX)
- Network access to Control Plane

**Control Tower Data Plane (Bare Metal/Single-Cluster):**
- Host OS: Linux (x86_64 architecture)
- 4-core CPU processor
- 8 GB RAM
- 20 GB disk space
- Ingress Controller: NGINX or Traefik
- Storage class for Hawk Console persistence
- Observability: Prometheus (metrics), ElasticSearch (traces)

### Critical "No-Hyphens" Reminder

The following identifiers **MUST NOT contain hyphens**:
- `controlPlaneInstanceId` / `CP_INSTANCE_ID`
- Any identifier used in database naming

**Valid**: `cp1`, `nxpcp`, `nxp_tibco_cp`  
**Invalid**: `nxp-tibco-cp`, `my-cp-instance`

---

**Document Version**: 1.0  
**Last Updated**: January 19, 2026  
**Next Review**: Before each customer engagement
