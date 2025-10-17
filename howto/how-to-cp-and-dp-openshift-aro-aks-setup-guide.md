# How to Set Up Azure Red Hat OpenShift (ARO) Cluster and Deploy TIBCO Platform Control Plane and Data Plane

## Original documentation can be found and referred in future here: 
[ARO docs from tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aro%20(Azure%20Red%20Hat%20OpenShift))

This document is with extra details while following the above document and make all the things working. 

Note: This document is copy of gh-pages doc from [here:](https://tibco-bnl.github.io/workshop-tibco-platform/docs/howto/how-to-dp-openshift-aro-aks-setup-guide.html#get-openshift-ingress-domain) hence links in table of contents will not work if you are viewing in google docs. 

## Table of Contents
<!-- TOC -->
- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Using a Prebuilt Docker Container for CLI Tools](#using-a-prebuilt-docker-container-for-cli-tools)
- [Step 1: Prepare Azure Environment](#step-1-prepare-azure-environment)
- [Step 2: Create Networking Resources](#step-2-create-networking-resources)
- [Step 3: Create ARO Cluster](#step-3-create-aro-cluster)
- [Step 4: Permissions and Role Assignments](#step-4-permissions-and-role-assignments)
- [Step 5: Connect to the Cluster](#step-5-connect-to-the-cluster)
- [Step 6: Configure Security Context Constraints](#step-6-configure-security-context-constraints)
- [Step 7: Configure Shared Infrastructure](#step-7-configure-shared-infrastructure)
  - [Step 7.1: Export Variables for Both Control Plane and Data Plane](#step-71-export-variables-for-both-control-plane-and-data-plane)
  - [Step 7.2: Configure Ingress Controller](#step-72-configure-ingress-controller)
  - [Step 7.3: Install Storage Classes](#step-73-install-storage-classes)
  - [Step 7.4: Install PostgreSQL](#step-74-install-postgresql)
- [Step 8: TIBCO Platform Control Plane Setup](#step-8-tibco-platform-control-plane-setup)
  - [Step 8.1: Create Control Plane Namespace and Service Account](#step-81-create-control-plane-namespace-and-service-account)
  - [Step 8.2: Configure Certificates and DNS Records](#step-82-configure-certificates-and-dns-records)
  - [Step 8.3: Generate Session Keys Secret](#step-83-generate-session-keys-secret)
  - [Step 8.4: Bootstrap Chart Values](#step-84-bootstrap-chart-values)
- [Step 9: TIBCO Platform Data Plane Setup](#step-9-tibco-platform-data-plane-setup)
  - [Step 9.1: Configure Observability](#step-91-configure-observability)
  - [Step 9.2: Deploy TIBCO Platform Data Plane](#step-92-deploy-tibco-platform-data-plane)
- [Step 10: Provision TIBCO BWCE and Flogo Capabilities from the GUI](#step-10-provision-tibco-bwce-and-flogo-capabilities-from-the-gui)
- [Step 11: Clean Up](#step-11-clean-up)
- [References](#references)
- [Troubleshooting and Cluster Information Commands](#troubleshooting-and-cluster-information-commands)
<!-- TOC -->

---

## Introduction

This guide provides step-by-step instructions to set up an Azure Red Hat OpenShift (ARO) cluster and deploy both the TIBCO Platform Control Plane and Data Plane on it. You can deploy either:

- **Control Plane only**: For managing multiple data planes across different clusters
- **Data Plane only**: When connecting to an existing SaaS Control Plane
- **Both Control Plane and Data Plane**: On the same ARO cluster for a complete standalone setup

**This guide assumes you are deploying both Control Plane and Data Plane on the same ARO cluster**, which is the most common scenario for workshops and evaluations. Common infrastructure components (storage classes, ingress configuration, etc.) are shared between both deployments.

This guide is intended for workshop and evaluation purposes, **for production every user needs to take best decision based on their enterprise policies**.

> [!NOTE]
> **Environment Variables Organization**: All environment variables required throughout this guide have been consolidated in [Step 7.1: Export Variables for Both Control Plane and Data Plane](#step-71-export-variables-for-both-control-plane-and-data-plane). This organization eliminates duplication and provides a single location to configure all deployment parameters. Individual sections will reference these centralized variables.

---

## Prerequisites

- **Azure Subscription** with Owner or Contributor + User Access Administrator roles.
- **Red Hat account** for pull secret.
- **Required Azure Permissions**: Your user account needs the following permissions:
  - `Microsoft.Authorization/roleAssignments/write` (for creating role assignments)
  - `Microsoft.RedHatOpenShift/OpenShiftClusters/write` (for creating ARO clusters)
  - `Microsoft.Network/*` (for managing network resources)
- **Command-line tools** (install via [Homebrew](https://brew.sh/)):
    - `az` (Azure CLI)
    - `oc` (OpenShift CLI)
    - `kubectl`
    - `helm`
    - `jq`, `yq`, `envsubst`, `bash`
- **Docker** (optional, for containerized CLI tools)
- **TIBCO Platform Helm charts repo**: [https://tibcosoftware.github.io/tp-helm-charts](https://tibcosoftware.github.io/tp-helm-charts)

---

## Clone tp-helm-charts repo

To clone the `tp-helm-charts` repository, run:

```bash
git clone https://github.com/TIBCOSoftware/tp-helm-charts.git
cd tp-helm-charts
```

This will download the latest charts and scripts required for the setup.

## Using a Prebuilt Docker Container for CLI Tools

All CLI commands in this guide can be executed inside a prebuilt Docker container that includes the required tools. This approach ensures a consistent environment and avoids local installation issues.

### Build the Docker Image

Navigate to the directory containing your Dockerfile (e.g., `/tp-helm-charts/docs/workshop`) and build the image:

```bash
docker buildx build --platform="linux/amd64" --progress=plain -t workshop-cli-tools:latest --load .
```

### Run the Container

Start an interactive shell with the necessary tools:

```bash
docker run -it --rm workshop-cli-tools:latest /bin/bash
```

> **Tip:** Mount your working directory with `-v $(pwd):/workspace` if you need access to local files inside the container.

All subsequent commands in this guide can be run from within this container shell.

---

## Step 1: Prepare Azure Environment

### 1.1. Export Required Variables

```bash
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_TENANT_ID=$(az account show --query tenantId -o tsv)
export TP_AZURE_REGION="westeurope" # or your preferred region
export TP_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"
export TP_CLUSTER_NAME="aroCluster"
export TP_WORKER_COUNT=6
export TP_VNET_NAME="openshiftvnet"
export TP_MASTER_SUBNET_NAME="masterOpenshiftSubnet"
export TP_WORKER_SUBNET_NAME="workerOpenshiftSubnet"
export TP_VNET_CIDR="10.5.0.0/16"
export TP_MASTER_SUBNET_CIDR="10.5.0.0/23"
export TP_WORKER_SUBNET_CIDR="10.5.2.0/23"
export TP_WORKER_VM_SIZE="Standard_D8s_v5"
export TP_WORKER_VM_DISK_SIZE_GB="128"
```

### 1.2. Login and Set Subscription

```bash
az login
az account set --subscription ${TP_SUBSCRIPTION_ID}
```

### 1.3. Register Required Resource Providers

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

### 1.4. Download Red Hat Pull Secret

- Download from: https://console.redhat.com/openshift/install/azure/aro-provisioned
- Save as `pull-secret.txt` and set permissions:

```bash
chmod +x pull-secret.txt
```

---

## Step 2: Create Networking Resources

Navigate to your scripts directory and run the pre-cluster script:

This script prepares the Azure environment (resource group, VNet, subnets) needed before deploying an ARO cluster, ensuring all required network infrastructure is in place.

E.g. It creates openshiftvnet with master and worker subnets.

```bash
cd "aro (Azure Red Hat OpenShift)/scripts"
./pre-aro-cluster-script.sh
```


---

## Step 3: Create ARO Cluster

### Troubleshooting Authorization Issues

If you encounter an `AuthorizationFailed` error like:
```
The client 'user@domain.com' does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'
```

This indicates insufficient permissions. Here are the solutions:

#### Option 1: Request Additional Permissions (Recommended)
Ask your Azure administrator to grant you one of the following roles:
- **Owner** role on the subscription or resource group
- **User Access Administrator** + **Contributor** roles combined

> **Note:** If your organization uses **Privileged Identity Management (PIM)**, you may need to:
> 1. Activate your Owner role in the Azure Portal under "Privileged Identity Management"
> 2. Refresh your Azure CLI session: `az login --use-device-code` or `az account clear && az login`
> 3. Verify your permissions: `az role assignment list --assignee $(az account show --query user.name -o tsv) --scope /subscriptions/${TP_SUBSCRIPTION_ID}`
> 4. If role assignments show empty, try broader scope checks:
>    ```bash
>    # Check at subscription level without specific scope
>    az role assignment list --assignee $(az account show --query user.name -o tsv) --all
>    
>    # Check your current user context
>    az account show --query '{User:user.name,Subscription:name,SubscriptionId:id}' -o table
>    
>    # Test if you can list resource groups (requires Contributor or higher)
>    az group list --query '[].{Name:name,Location:location}' -o table
>    ```

#### Option 2: Pre-assign Required Roles
If you cannot get User Access Administrator permissions, ask your Azure administrator to pre-assign the required roles:

```bash
# Get the ARO resource provider service principal ID
ARO_RP_SP_ID=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query [0].appId -o tsv)

# Assign Network Contributor role to ARO RP on the VNet
az role assignment create \
    --assignee ${ARO_RP_SP_ID} \
    --role "Network Contributor" \
    --scope "/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${TP_VNET_NAME}"
```

#### Option 3: Use Service Principal Authentication
Create a service principal with sufficient permissions and use it for ARO cluster creation:

```bash
# Create service principal (requires elevated permissions)
az ad sp create-for-rbac --name "aro-cluster-sp" --role Owner --scopes "/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}"

# Login with service principal
az login --service-principal -u <appId> -p <password> --tenant ${TP_TENANT_ID}
```

### Create the ARO Cluster

Cluster creation takes 30–45 minutes.

> **Note:** To check available OpenShift versions in your region before creation:
> ```bash
> az aro get-versions --location ${TP_AZURE_REGION} -o table
> ```

```bash
az aro create \
    --resource-group ${TP_RESOURCE_GROUP} \
    --name ${TP_CLUSTER_NAME} \
    --vnet ${TP_VNET_NAME} \
    --master-subnet ${TP_MASTER_SUBNET_NAME} \
    --worker-subnet ${TP_WORKER_SUBNET_NAME} \
    --worker-count ${TP_WORKER_COUNT} \
    --worker-vm-disk-size-gb ${TP_WORKER_VM_DISK_SIZE_GB} \
    --worker-vm-size ${TP_WORKER_VM_SIZE} \
    --version 4.17.27 \
    --pull-secret @pull-secret.txt
```


---

## Step 4: Permissions and Role Assignments

Below are the key commands used to set permissions and roles for your ARO cluster and TIBCO Platform Data Plane setup, with brief descriptions for each step.

Ref: [Microsoft ARO Doc: How to Create a Storage Class and Set Permissions](https://learn.microsoft.com/en-us/azure/openshift/howto-create-a-storageclass#set-permissions)

### 4.1. Set Resource Group Permissions

The ARO service principal requires `listKeys` permission on the Azure storage account resource group. Assign the Contributor role to the ARO service principal:

```bash
# Set environment variables (using variables from Step 1)
export ARO_RESOURCE_GROUP=${TP_RESOURCE_GROUP}
export CLUSTER=${TP_CLUSTER_NAME}
export AZURE_FILES_RESOURCE_GROUP=${TP_RESOURCE_GROUP}

# Get the ARO service principal ID
ARO_SERVICE_PRINCIPAL_ID=$(az aro show -g $ARO_RESOURCE_GROUP -n $CLUSTER --query servicePrincipalProfile.clientId -o tsv)

# Assign Contributor role to the ARO service principal on the storage resource group
az role assignment create --role Contributor --scope /subscriptions/$TP_SUBSCRIPTION_ID/resourceGroups/$AZURE_FILES_RESOURCE_GROUP --assignee $ARO_SERVICE_PRINCIPAL_ID
```
*Assigns necessary permissions for ARO to manage Azure Files storage resources.*

### 4.2. Set ARO Cluster Permissions

The OpenShift persistent volume binder service account requires permission to read secrets. Create and assign a custom cluster role:

```bash
# Get the ARO API server endpoint
ARO_API_SERVER=$(az aro list --query "[?contains(name,'$CLUSTER')].[apiserverProfile.url]" -o tsv)

# Login to the OpenShift cluster as kubeadmin
oc login -u kubeadmin -p $(az aro list-credentials -g $ARO_RESOURCE_GROUP -n $CLUSTER --query=kubeadminPassword -o tsv) $ARO_API_SERVER

# Create a cluster role to allow reading secrets
oc create clusterrole azure-secret-reader \
    --verb=create,get \
    --resource=secrets

# Assign the cluster role to the persistent-volume-binder service account
oc adm policy add-cluster-role-to-user azure-secret-reader system:serviceaccount:kube-system:persistent-volume-binder
```
*Enables OpenShift to bind persistent volumes by granting the required permissions to read secrets.*

---

## Step 5: Connect to the Cluster

### 5.1. Get Credentials

You can also get credentials from the aroCluster in Azure Portal by clicking on "Connect" button. 

```bash
az aro list-credentials --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP}
```

### 5.2. Login with OpenShift CLI

```bash
apiServer=$(az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query apiserverProfile.url -o tsv)
oc login ${apiServer} -u <kubeadminUsername> -p <kubeadminPassword>

```

### 5.3. Access OpenShift Console

```bash
az aro show --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP} --query "consoleProfile.url" -o tsv
```

---

## Step 6: Configure Security Context Constraints

**Why this step is needed:** OpenShift uses Security Context Constraints (SCCs) to control the security context under which pods run. TIBCO Platform components require specific security permissions to function properly, including the ability to bind to network services and access persistent storage. The default OpenShift SCCs are too restrictive for TIBCO workloads.

**What this accomplishes:** Creates a custom SCC (`tp-scc`) that provides the minimum required security permissions for TIBCO Platform Control Plane and Data Plane components while maintaining security best practices.

Create a custom SCC for TIBCO workloads:

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

Verify:

```bash
oc get scc tp-scc

NAME     PRIV    CAPS                   SELINUX     RUNASUSER   FSGROUP    SUPGROUP   PRIORITY   READONLYROOTFS   VOLUMES
tp-scc   false   ["NET_BIND_SERVICE"]   MustRunAs   RunAsAny    RunAsAny   RunAsAny   10         false            ["configMap","csi","downwardAPI","emptyDir","ephemeral","persistentVolumeClaim","projected","secret"]

```

---

## Step 7: Configure Shared Infrastructure

**Why this step is needed:** Both TIBCO Control Plane and Data Plane require common infrastructure components including ingress controllers, storage classes, and databases. Configuring these shared components once ensures consistency and reduces duplication.

**What this accomplishes:** 
- Sets up ingress capabilities for both internal and external traffic routing
- Creates storage classes for persistent data storage requirements
- Installs PostgreSQL database required by the Control Plane
- Configures network policies for secure communication between components

This section configures the infrastructure components that will be shared between Control Plane and Data Plane deployments on the same ARO cluster.

### Step 7.1: Export Variables for Both Control Plane and Data Plane

The following variables are required for both Control Plane and Data Plane setup and should be exported in addition to the variables from Step 1. This comprehensive list consolidates all environment variables needed throughout the deployment process.

```bash
# ========================================
# AZURE AND CLUSTER INFRASTRUCTURE VARIABLES
# ========================================
# Note: These are already defined in Step 1, included here for reference
# export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# export TP_TENANT_ID=$(az account show --query tenantId -o tsv)
# export TP_AZURE_REGION="westeurope"
# export TP_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"
# export TP_CLUSTER_NAME="aroCluster"
# export TP_WORKER_COUNT=6
# export TP_VNET_NAME="openshiftvnet"
# export TP_MASTER_SUBNET_NAME="masterOpenshiftSubnet"
# export TP_WORKER_SUBNET_NAME="workerOpenshiftSubnet"
# export TP_VNET_CIDR="10.5.0.0/16"
# export TP_MASTER_SUBNET_CIDR="10.5.0.0/23"
# export TP_WORKER_SUBNET_CIDR="10.5.2.0/23"
# export TP_WORKER_VM_SIZE="Standard_D8s_v5"
# export TP_WORKER_VM_DISK_SIZE_GB="128"

# ========================================
# NETWORK CONFIGURATION VARIABLES
# ========================================
## Network specific variables (get actual values from your ARO cluster)
export TP_NODE_CIDR="10.5.2.0/23" # Node CIDR: from Worker Node subnet CIDR (TP_WORKER_SUBNET_CIDR)
export TP_POD_CIDR="10.128.0.0/14" # Pod CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv
export TP_SERVICE_CIDR="172.30.0.0/16" # Service CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv

# Network policy specific variables
export TP_ENABLE_NETWORK_POLICY="false" # possible values "true", "false"

# ========================================
# DNS AND DOMAIN CONFIGURATION VARIABLES
# ========================================
## Domain specific variables
export TP_CLUSTER_DOMAIN="nxp.atsnl-emea.azure.dataplanes.pro" # replace it with your DNS Zone name
export TP_DNS_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"  # replace with name of resource group containing dns record sets
export TP_TOP_LEVEL_DOMAIN="${TP_CLUSTER_DOMAIN}" # top level domain of TP_DOMAIN
export TP_SANDBOX="apps" # hostname of TP_DOMAIN
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="openshift-default" # name of main ingress class used by capabilities

# ========================================
# STORAGE CONFIGURATION VARIABLES
# ========================================
# Storage specific variables
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class

# ========================================
# OBSERVABILITY CONFIGURATION VARIABLES
# ========================================
# LogServer specific variables (optional)
export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX="" # logserver index to push the logs to
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""

# ========================================
# CONTAINER REGISTRY VARIABLES
# ========================================
## Container Registry variables (shared by both Control Plane and Data Plane)
export TP_CONTAINER_REGISTRY_URL="csgprdeuwrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository

# ========================================
# HELM CHART CONFIGURATION VARIABLES
# ========================================
# Helm chart repository variables
export TP_CHART_REPO_USER_NAME=
export TP_CHART_REPO_TOKEN=
export HELM_URL=tibco-platform-public

# ========================================
# CONTROL PLANE SPECIFIC VARIABLES
# ========================================
## Control Plane Instance specific variables (only needed if deploying Control Plane)
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export CP_MY_DNS_DOMAIN=${CP_INSTANCE_ID}-my.${TP_DOMAIN} # domain to be used for Control Plane UI
export CP_TUNNEL_DNS_DOMAIN=${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN} # domain to be used for hybrid connectivity

# Control Plane chart versions
export CP_PLATFORM_BOOTSTRAP_VERSION=1.11.0
export CP_PLATFORM_BASE_VERSION=1.11.0

# Storage configuration for Control Plane
export CP_STORAGE_SIZE="10Gi" # storage size for Control Plane components

# TLS Secret names for Control Plane
export CP_MY_TLS_SECRET_NAME="custom-my-tls" # TLS secret for Control Plane UI domain
export CP_TUNNEL_TLS_SECRET_NAME="custom-tunnel-tls" # TLS secret for hybrid connectivity domain

# Email configuration for certificates
export EMAIL="cp-test@tibco.com" # email for certificates (required if deploying Control Plane)
export EMAIL_FOR_CERTBOT="kulbhushan.bhalerao@tibco.com"

# Database configuration variables
export CP_DB_HOST="postgresql.tibco-ext.svc.cluster.local"
export CP_DB_NAME="postgres"
export CP_DB_PASSWORD="postgres"
export CP_DB_PORT="5432"
export CP_DB_SECRET_NAME="provider-cp-database-credentials"
export CP_DB_SSL_MODE="disable"
export CP_DB_USERNAME="postgres"

# Email server configuration variables
export CP_EMAIL_SERVER_TYPE="smtp"
export CP_EMAIL_SMTP_SERVER="development-mailserver.tibco-ext.svc.cluster.local"
export CP_EMAIL_SMTP_PORT="1025"
export CP_EMAIL_SMTP_USERNAME=""  # Empty - MailDev doesn't require authentication
export CP_EMAIL_SMTP_PASSWORD=""  # Empty - MailDev doesn't require authentication

# Admin user configuration variables
export CP_ADMIN_EMAIL="${EMAIL}"
export CP_ADMIN_FIRSTNAME="cp-test"
export CP_ADMIN_LASTNAME="cp-test"
export CP_ADMIN_CUSTOMER_ID="nxp-customer-id"

# ========================================
# DATA PLANE SPECIFIC VARIABLES
# ========================================
## Data Plane specific variables (only needed if deploying Data Plane)
export DP_NAMESPACE="dp1" # Replace with your namespace
```

> [!IMPORTANT]
> We are assuming customer will be using the Azure DNS Service.

### Step 7.2: Configure Ingress Controller

**Why this step is needed:** TIBCO Control Plane uses wildcard domains for the `my` (Control Plane UI) and `tunnel` (hybrid connectivity) domains. The default OpenShift ingress controller restricts wildcard domains and cross-namespace ingress ownership for security reasons.

**What this accomplishes:** 
- Enables wildcard domain support required by Control Plane services
- Allows inter-namespace ingress ownership for Control Plane components
- Ensures external traffic can reach Control Plane services properly

> [!NOTE]
> We are using the default Ingress Controller provisioned for ARO cluster. This configuration is shared by both Control Plane and Data Plane.

The default ingress controller needs to be configured to allow wildcard domains and inter-namespace ownership (required for Control Plane `my` and `tunnel` domains):

```bash
oc -n openshift-ingress-operator patch ingresscontroller/default --type='merge' \
  -p '{"spec":{"routeAdmission":{"wildcardPolicy":"WildcardsAllowed","namespaceOwnership":"InterNamespaceAllowed"}}}'
```

### Step 7.3: Install Storage Classes

**Why this step is needed:** TIBCO Platform components require persistent storage for configuration data, application artifacts, and runtime state. Different components have different storage requirements - some need shared file storage while others need high-performance block storage.

**What this accomplishes:**
- **Azure Files storage class**: Provides shared file storage for Control Plane configuration and Data Plane capabilities that need concurrent read/write access
- **Azure Disk storage class**: Provides high-performance block storage for databases like PostgreSQL
- **Azure Files EMS storage class**: Specialized storage for Enterprise Message Service with NFS protocol support

Create storage classes required for both Control Plane and Data Plane deployments:

```bash
# Azure Files Storage Class (used by Control Plane and Data Plane capabilities)
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: ${TP_FILE_STORAGE_CLASS}
mountOptions:
- mfsymlinks
- cache=strict
- nosharesock
- noperm
parameters:
  allowBlobPublicAccess: "false"
  networkEndpointType: privateEndpoint
  skuName: Premium_LRS
provisioner: file.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Azure Disk Storage Class (used by PostgreSQL and other disk-based workloads)
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: ${TP_DISK_STORAGE_CLASS}
parameters:
  skuName: Premium_LRS # other values: Premium_ZRS, StandardSSD_LRS (default)
provisioner: disk.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF

# Azure Files Storage Class for EMS (Enterprise Message Service) - Data Plane capability
oc apply -f - <<EOF
apiVersion: storage.k8s.io/v1
allowVolumeExpansion: true
kind: StorageClass
metadata:
  name: azure-files-sc-ems
mountOptions:
- soft
- timeo=300
- actimeo=1
- retrans=2
- _netdev
parameters:
  allowBlobPublicAccess: "false"
  networkEndpointType: privateEndpoint
  protocol: nfs
  skuName: Premium_LRS
provisioner: file.csi.azure.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

### Step 7.4: Install PostgreSQL

**Why this step is needed:** TIBCO Control Plane requires PostgreSQL as its metadata database to store:
- Platform configuration and metadata
- User permissions and RBAC settings
- Application deployment information
- Audit logs and operational data

**What this accomplishes:**
- **PostgreSQL cluster**: Provides highly available database service for Control Plane
- **Persistent storage**: Ensures data persistence across pod restarts using Azure Disk storage
- **Database configuration**: Sets up required schemas and access permissions

Install PostgreSQL server chart using the `on-premises-third-party` chart. This PostgreSQL instance will be used by the Control Plane:

> [!NOTE]
> You can optionally use any pre-existing PostgreSQL installation, but please make sure that the Control Plane pods can communicate with that database.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n tibco-ext postgresql tibco-platform-public/on-premises-third-party \
  --labels layer=2 \
  --version "^1.0.0" -f - <<EOF
global:
  tibco:
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
  storageClass: ${TP_DISK_STORAGE_CLASS}
postgresql:
  enabled: true
  auth:
    postgresPassword: postgres
    username: postgres
    password: postgres
    database: "postgres"
  image:
    registry: "${TP_CONTAINER_REGISTRY_URL}"
    repository: ${TP_CONTAINER_REGISTRY_REPOSITORY}/common-postgresql
    tag: 16.4.0-debian-12-r14
    pullSecrets:
    - tibco-container-registry-credentials
    debug: true
  primary:
    # resourcesPreset: "nano" # nano micro small
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
EOF
```

If you are using network policies, label the `tibco-ext` namespace:

```bash
oc label namespace tibco-ext networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

> [!IMPORTANT]
> Please note that the PostgreSQL installed above does not enforce SSL by default. It has to be manually configured.

### Step 7.5: Install and Access Email Server (MailDev)

**Why this step is needed:** TIBCO Control Plane requires an SMTP server to send email notifications for:
- User account activation and password reset emails
- Platform notifications and alerts
- Subscription and billing notifications
- System administration alerts

**What this accomplishes:**
- **Development SMTP server**: Provides a lightweight email server for testing and development
- **Email capture**: Captures all outbound emails from Control Plane for review and testing
- **Web interface**: Provides a web-based interface to view captured emails
- **No authentication**: Configured to work without SMTP authentication for simplicity

#### Install MailDev Email Server

Deploy the MailDev email server that will capture and display emails sent by the Control Plane:

```bash
# Apply the MailDev deployment
oc apply -f /path/to/your/maildev-deploy.yaml

# Wait for the deployment to be ready
oc wait --for=condition=ready pod -l app=development-mailserver -n tibco-ext --timeout=300s

# Verify the deployment
oc get pods -n tibco-ext -l app=development-mailserver
```

#### Access the MailDev Web Interface

**Web Interface URL**: `https://mail.nxp.atsnl-emea.azure.dataplanes.pro`

**What you can do with the email interface:**
- **View all emails**: See all emails sent by the Control Plane in a convenient web interface
- **User activation**: Click on activation links in emails to activate new users
- **Password resets**: Access password reset emails for testing
- **Platform notifications**: Review system alerts and notifications
- **Email debugging**: Inspect email content, headers, and formatting

#### Using the Email Interface for Control Plane Setup

1. **Initial Setup**: After deploying the Control Plane, check the email interface for the platform administrator activation email
2. **User Management**: When creating new users, their activation emails will appear in the interface
3. **Testing**: Use the email interface to test email functionality without needing external email services

#### Email Server Configuration Details

The MailDev server is configured with the following settings:
- **SMTP Server**: `development-mailserver.tibco-ext.svc.cluster.local`
- **SMTP Port**: `1025`
- **Web Interface Port**: `1080` (mapped to route)
- **Authentication**: Disabled (no username/password required)
- **SSL/TLS**: Not required for development use

> [!NOTE]
> This email server is intended for development and testing purposes only. For production deployments, configure a proper SMTP server with authentication and encryption.

---

## Step 8: TIBCO Platform Control Plane Setup

**Why this step is needed:** The TIBCO Control Plane provides centralized management capabilities for the entire TIBCO Platform ecosystem:
- **Platform governance**: Centralized management of capabilities, permissions, and policies
- **Application lifecycle**: Manages deployment, scaling, and monitoring of applications
- **User management**: Handles authentication, authorization, and role-based access control
- **Resource orchestration**: Coordinates resource allocation and service dependencies

**What this accomplishes:**
- **Control Plane deployment**: Installs the core platform management services
- **Configuration integration**: Connects to PostgreSQL database and certificate infrastructure
- **Service mesh setup**: Establishes secure communication between platform components
- **Management interfaces**: Provides APIs and UI for platform administration

> [!IMPORTANT]
> This section covers Control Plane specific configuration. If you are only deploying a Data Plane to connect to a SaaS Control Plane, skip to [Step 9: TIBCO Platform Data Plane Setup](#step-9-tibco-platform-data-plane-setup).

### Step 8.1: Create Control Plane Namespace and Service Account

**Why this step is needed:** The Control Plane requires its own dedicated namespace for:
- **Resource isolation**: Separates Control Plane components from other workloads
- **Security boundaries**: Enables specific RBAC policies and security contexts
- **Resource management**: Allows targeted resource quotas and limits
- **Label-based operations**: Facilitates platform-specific operations and monitoring

**What this accomplishes:**
- **Dedicated namespace**: Creates isolated environment for Control Plane components
- **Service account**: Provides identity for Control Plane services to access Kubernetes APIs
- **Platform labels**: Enables platform-specific resource discovery and management

Create a namespace where the TIBCO Control Plane charts will be deployed. This provides isolation for the Control Plane components and makes it easier to manage permissions and resources:

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

Create a dedicated service account for TIBCO Control Plane deployment. This service account will be used by Control Plane components to interact with the Kubernetes API:

```bash
oc create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

Grant necessary Security Context Constraints (SCC) permissions to the service accounts. This is required in OpenShift environments to allow the Control Plane pods to run with the appropriate security context:

```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:${CP_INSTANCE_ID}-sa
oc adm policy add-scc-to-user tp-scc system:serviceaccount:${CP_INSTANCE_ID}-ns:default
```

These permissions ensure that Control Plane components can access required resources and run with the security context defined in the custom `tp-scc` we created earlier, which provides the minimum required privileges while maintaining security best practices.

### Step 8.2: Configure Certificates and DNS Records

**Why this step is needed:** The Control Plane requires secure HTTPS communication for:
- **Web interface security**: Protects the Control Plane UI and APIs with SSL/TLS encryption
- **Service-to-service communication**: Ensures secure inter-service communication within the platform
- **Hybrid connectivity**: Secures tunnel connections between Control Plane and Data Planes
- **Client trust**: Provides browser-trusted certificates for user access

**What this accomplishes:**
- **SSL/TLS certificates**: Creates valid certificates for Control Plane domains using Let's Encrypt
- **DNS configuration**: Sets up DNS records for Control Plane services and hybrid connectivity
- **Wildcard domains**: Enables flexible subdomain usage for different Control Plane services
- **Certificate automation**: Uses certbot for automated certificate generation and renewal

> [!IMPORTANT]
> For the scope of this document, we use Azure DNS Service for DNS hosting, resolution.

We recommend that you use different DNS records and certificates for `my` (Control Plane application) and `tunnel` (hybrid connectivity) domains. You can use wildcard domain names for these Control Plane application and hybrid connectivity domains. 

**Why wildcard certificates are recommended:**
- **Admin interface**: The Control Plane admin interface will be accessible at `admin.${CP_MY_DNS_DOMAIN}`
- **Subscription domains**: Different subscriptions can have their own subdomains like `<subscription-name>.${CP_MY_DNS_DOMAIN}`
- **Tunnel services**: Various tunnel endpoints will use subdomains under `${CP_TUNNEL_DNS_DOMAIN}`
- **Simplified management**: One wildcard certificate covers all current and future subdomains

The certificates for both the domains are created [using certbot commands](https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-commands)

We recommend that you use different `CP_INSTANCE_ID` to distinguish multiple Control Plane installations within a cluster.

`TP_DOMAIN` is exported as part of [Export required variables](#export-required-variables)

Please export below variables and values related to domains (as descirbed above) if not done:
```bash
CP_INSTANCE_ID,CP_MY_DNS_DOMAIN,CP_TUNNEL_DNS_DOMAIN,EMAIL
```

If you are using network policies, to ensure that network traffic is allowed from the default ingress namespace to the Control Plane namespace pods, label the namespace running following command

```bash
oc label namespace openshift-ingress networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

#### Install Certbot (Alpine Docker)

If you're running in Alpine Docker and get `bash: certbot: command not found`, here are your options:

**Option 1: Install certbot in Alpine (Recommended)**
```bash
# Update packages and install certbot
apk update && apk add certbot

# Verify installation
certbot --version
```

**Option 2: Use pip to install certbot**
```bash
# Install Python and pip first (if not available)
apk add python3 py3-pip

# Install certbot via pip
pip3 install certbot

# Verify installation
certbot --version
```

**Option 3: Use acme.sh as alternative (Lightweight)**
```bash
# Install acme.sh (lighter alternative to certbot)
apk add curl socat
curl https://get.acme.sh | sh

# Use acme.sh instead of certbot for certificate generation
~/.acme.sh/acme.sh --issue --dns -d "*.${CP_MY_DNS_DOMAIN}" --yes-I-know-dns-manual-mode-enough-go-ahead-please
```

**Option 4: Run certbot in separate Docker container**
```bash
# Create alias to run certbot in Docker
alias certbot='docker run --rm -it -v $PWD/certs:/etc/letsencrypt -v $PWD/work:/var/lib/letsencrypt certbot/certbot'

# Test the alias
certbot --version
```

#### Certificate and Secret for MY Domain

```bash
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-my"

certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL_FOR_CERTBOT} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_MY_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

> **Note:** Do not interrupt the command. You will need to create multiple TXT record sets under the `TP_CLUSTER_DOMAIN` DNS zone:
> 1. `_acme-challenge.${CP_INSTANCE_ID}-my.apps` for the wildcard domain
> Create each TXT record with the values mentioned in the certbot output, then press Enter to complete the command.

```bash
oc create secret tls custom-my-tls \
  -n ${CP_INSTANCE_ID}-ns \
  --cert=$SCRATCH_DIR/config/live/${CP_MY_DNS_DOMAIN}/fullchain.pem \
  --key=$SCRATCH_DIR/config/live/${CP_MY_DNS_DOMAIN}/privkey.pem
```

#### Certificate and Secret for TUNNEL Domain

```bash
export SCRATCH_DIR="/tmp/${CP_INSTANCE_ID}-tunnel"

certbot certonly --manual \
  --preferred-challenges=dns \
  --email ${EMAIL_FOR_CERTBOT} \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d "*.${CP_TUNNEL_DNS_DOMAIN}" \
  --config-dir "${SCRATCH_DIR}/config" \
  --work-dir "${SCRATCH_DIR}/work" \
  --logs-dir "${SCRATCH_DIR}/logs"
```

> **Note:** Do not interrupt the command. Create the `_acme-challenge.${CP_INSTANCE_ID}-tunnel.apps` TXT record set under the `TP_CLUSTER_DOMAIN` DNS zone with the value mentioned in the output of above command. After the record set is created, press Enter to complete the command.

```bash
oc create secret tls custom-tunnel-tls \
  -n ${CP_INSTANCE_ID}-ns \
  --cert=$SCRATCH_DIR/config/live/${CP_TUNNEL_DNS_DOMAIN}/fullchain.pem \
  --key=$SCRATCH_DIR/config/live/${CP_TUNNEL_DNS_DOMAIN}/privkey.pem
```

#### Create Record Sets for MY and TUNNEL Domains

**Why wildcard DNS entries are used:** The TIBCO Control Plane uses dynamic subdomains for different services and subscription domains. Using wildcard DNS entries (`*.${CP_MY_DNS_DOMAIN}` and `*.${CP_TUNNEL_DNS_DOMAIN}`) allows the platform to automatically handle:
- **Control Plane admin interface**: `admin.${CP_MY_DNS_DOMAIN}`
- **Subscription domains**: `<subscription-name>.${CP_MY_DNS_DOMAIN}`
- **Tunnel connectivity**: Various tunnel endpoints under `*.${CP_TUNNEL_DNS_DOMAIN}`

Add the wildcard record sets under the DNS Zones so that all Control Plane services are accessible:

```bash
INGRESS_IP="$(az aro show -n ${TP_CLUSTER_NAME} -g ${TP_RESOURCE_GROUP} --query 'ingressProfiles[0].ip' -o tsv)"

## add wildcard record set for MY Domain (covers admin.${CP_MY_DNS_DOMAIN} and subscription domains)
az network dns record-set a add-record \
 -g ${TP_DNS_RESOURCE_GROUP} \
 -z ${TP_CLUSTER_DOMAIN} \
 -n "*.${CP_INSTANCE_ID}-my.apps" \
 -a ${INGRESS_IP}

## add wildcard record set for TUNNEL Domain
az network dns record-set a add-record \
 -g ${TP_DNS_RESOURCE_GROUP} \
 -z ${TP_CLUSTER_DOMAIN} \
 -n "*.${CP_INSTANCE_ID}-tunnel.apps" \
 -a ${INGRESS_IP}


## Verify record sets

**Note:** If `dig` command is not found in Alpine Docker, install it:
```bash
# Install dig in Alpine
apk add bind-tools

# Verify installation
dig --version
```

**Alternative verification methods if dig is not available:**
```bash
# Option 1: Use nslookup (usually pre-installed)
nslookup admin.${CP_MY_DNS_DOMAIN}
nslookup test.${CP_TUNNEL_DNS_DOMAIN}

# Option 2: Use curl to test domain resolution
curl -I --connect-timeout 5 https://admin.${CP_MY_DNS_DOMAIN} 2>/dev/null | head -1
curl -I --connect-timeout 5 https://test.${CP_TUNNEL_DNS_DOMAIN} 2>/dev/null | head -1

# Option 3: Use getent (if available)
getent hosts admin.${CP_MY_DNS_DOMAIN}
getent hosts test.${CP_TUNNEL_DNS_DOMAIN}
```

**Using dig (after installation):**
```bash
dig +short admin.${CP_MY_DNS_DOMAIN}
dig +short test.${CP_TUNNEL_DNS_DOMAIN}
```


### Step 8.3: Generate Session Keys Secret

**Why this step is needed:** Session keys provide cryptographic security for the Control Plane:
- **Session management**: Encrypts user sessions and maintains session state securely
- **Cross-service authentication**: Enables secure communication between Control Plane microservices
- **API security**: Protects API tokens and inter-service authentication
- **Compliance**: Ensures data protection standards for user authentication

**What this accomplishes:**
- **Cryptographic keys**: Generates random, secure keys for session encryption
- **Kubernetes secret**: Stores keys securely in the cluster for platform services to access
- **Service security**: Enables encrypted communication between platform components

This secret is a required prerequisite for the platform-bootstrap chart:

```bash
# Generate session keys and export as environment variables
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create the Kubernetes secret required by router pods
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
```

### Step 8.4: Bootstrap Chart Values

The following values can be stored in a file and passed to the platform-bootstrap chart:

> [!IMPORTANT]
> These values are for example only.

> [!NOTE]
> All required environment variables are already defined in [Step 7.1: Export Variables](#step-71-export-variables-for-both-control-plane-and-data-plane). Ensure those variables are exported before running the helm commands below.

#In case you are using helm repo with username and password use following commented line in the command.
#--username ${TP_CHART_REPO_USER_NAME} --password ${TP_CHART_REPO_TOKEN} \

```bash

helm upgrade --install --wait --timeout 1h --create-namespace  \
  -n ${CP_INSTANCE_ID}-ns  platform-bootstrap    ${HELM_URL}/platform-bootstrap  \
  --version "${CP_PLATFORM_BOOTSTRAP_VERSION}" -f - <<EOF
global:
  external:
    clusterInfo:
      nodeCIDR: ${TP_NODE_CIDR}
      podCIDR: ${TP_POD_CIDR}
      serviceCIDR: ${TP_SERVICE_CIDR}
    dnsDomain: ${CP_MY_DNS_DOMAIN}
    dnsTunnelDomain: ${CP_TUNNEL_DNS_DOMAIN}
    storage:
      resources:
        requests:
          storage: ${CP_STORAGE_SIZE}
      storageClassName: "${TP_FILE_STORAGE_CLASS}"
  tibco:
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    #createNetworkPolicy: false    
    logging:
      fluentbit:
        enabled: false
    serviceAccount: ${CP_INSTANCE_ID}-sa                
hybrid-proxy:
  enabled: true
  enableWebHooks: false
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    tls:
      - secretName: ${CP_TUNNEL_TLS_SECRET_NAME}
        hosts:
          - '*.${CP_TUNNEL_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_TUNNEL_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 105        
otel-collector:
  enabled: false
resource-set-operator:
  enabled: true
  enableWebHooks: false
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
router-operator:
  enabled: true
  enableWebHooks: false
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}   
    tls:
      - secretName: ${CP_MY_TLS_SECRET_NAME}
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 100                     
EOF
```
### Step 8.5: Verify Helm Chart Deployments

To check the actual values being used by the platform charts after deployment, you can export their configurations:

**Platform Bootstrap Chart:**
```bash
helm get values platform-bootstrap -n ${CP_INSTANCE_ID}-ns -o yaml > platform-bootstrap-values.yaml
```

**Platform Base Chart (after Step 8.7):**
```bash
helm get values platform-base -n ${CP_INSTANCE_ID}-ns -o yaml > platform-base-values.yaml
```

These commands export all the applied configuration values, which can be useful for:

- Verifying that all your custom values were properly applied
- Debugging issues related to chart configuration 
- Creating templates for future deployments
- Understanding the effective configuration after default values are merged with your overrides

You can also view the values directly in the terminal without saving to a file:

```bash
helm get values platform-bootstrap -n ${CP_INSTANCE_ID}-ns -o yaml
helm get values platform-base -n ${CP_INSTANCE_ID}-ns -o yaml  # After Step 8.7
```
### Step 8.6: Create CP Encryption Secret
> **_NOTE:_** REQUIRED from 1.9.0
```bash
oc create secret -n ${CP_INSTANCE_ID}-ns generic cporch-encryption-secret --from-literal=CP_ENCRYPTION_SECRET_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)
```

### Step 8.7: Install Platform Base
> **_NOTE:_** Before executing base install, ensure workloads in the cluster can access external resources like Database, Email Server

> [!IMPORTANT]
> **Admin User Initial Password**: During platform-base installation, the admin user specified does not receive an activation email whether email service is configured or not. Instead, the platform automatically generates a temporary password and stores it in a Kubernetes job called `tp-control-plane-ops-create-admin-user` that runs for only **1 hour**.
> 
> **Key Points**:
> - The admin user does not get an activation email (unlike regular users)
> - The initial password is only available in the job logs for 1 hour
> - The job is automatically deleted after 1 hour for security reasons
> - The user must reset the password on first login (mandatory)
> - First-time login must use "Default IdP" option
> 
> **How to retrieve the initial password**:
> 1. **During installation**: Run `kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user`
> 2. **Get logs**: `kubectl logs -n ${CP_INSTANCE_ID}-ns jobs/<job-name>`
> 3. **Find initialPassword**: Search for `initialPassword` value in the logs
> 4. **Decode if needed**: `echo '"<initialPassword>"' | jq -r .`
> 
> **Reference**: [TIBCO Platform Administration - Signing to Platform Console](https://docs.tibco.com/pub/platform-cp/1.10.0/doc/html/Administration/signing-to-platform-console.htm)

> [!NOTE]
> All required environment variables are already defined in [Step 7.1: Export Variables](#step-71-export-variables-for-both-control-plane-and-data-plane). Ensure those variables are exported before running the commands below.

```bash
#--username ${TP_CHART_REPO_USER_NAME} --password ${TP_CHART_REPO_TOKEN} \

# Create database credentials secret required for platform-base
kubectl create secret generic ${CP_DB_SECRET_NAME} \
    --from-literal=db_username=${CP_DB_USERNAME} \
    --from-literal=db_password=${CP_DB_PASSWORD} \
    -n ${CP_INSTANCE_ID}-ns

helm upgrade --install --wait --timeout 1h --create-namespace -n ${CP_INSTANCE_ID}-ns  platform-base    ${HELM_URL}/platform-base  \
   --version "${CP_PLATFORM_BASE_VERSION}" -f - <<EOF
global:
  tibco:
    logging:
      fluentbit:
        enabled: false  
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    #createNetworkPolicy: false    
    serviceAccount: ${CP_INSTANCE_ID}-sa       
    #helm:
      #url: ${TP_CHART_REGISTRY}
      #repo: ${TP_CHART_REPO}
      #username: ${TP_CHART_REPO_USER_NAME}
      #password: ${TP_CHART_REPO_TOKEN}  
    #db_ssl_root_cert_secretname: "${CP_DB_SSL_ROOT_CERT_SECRET_NAME}"
    #db_ssl_root_cert_filename: "${CP_DB_SSL_ROOT_CERT_FILENAME}"
  external:
    cpEncryptionSecretName: cporch-encryption-secret
    cpEncryptionSecretKey: CP_ENCRYPTION_SECRET_KEY 
    clusterInfo:
      nodeCIDR: ${TP_NODE_CIDR}
      podCIDR: ${TP_POD_CIDR}
      serviceCIDR: ${TP_SERVICE_CIDR}
    dnsDomain: ${CP_MY_DNS_DOMAIN}
    dnsTunnelDomain: ${CP_TUNNEL_DNS_DOMAIN}
    db_host: "${CP_DB_HOST}"
    db_name: "${CP_DB_NAME}"
    db_password: "${CP_DB_PASSWORD}"
    db_port: "${CP_DB_PORT}"
    db_secret_name: "${CP_DB_SECRET_NAME}"
    db_ssl_mode: "${CP_DB_SSL_MODE}"
    db_username: "${CP_DB_USERNAME}"
    emailServerType: ${CP_EMAIL_SERVER_TYPE}    
    emailServer:
      smtp:
        server: "${CP_EMAIL_SMTP_SERVER}"
        port: "${CP_EMAIL_SMTP_PORT}"
        username: "${CP_EMAIL_SMTP_USERNAME}"
        password: "${CP_EMAIL_SMTP_PASSWORD}"
    admin:
      email: ${CP_ADMIN_EMAIL}
      firstname: "${CP_ADMIN_FIRSTNAME}"
      lastname: "${CP_ADMIN_LASTNAME}"
      customerID: "${CP_ADMIN_CUSTOMER_ID}"     
tp-cp-infra:
  enabled: true
  resources:
    infra-compute-services:
      requests:
        cpu: 200m
        memory: 256Mi
    infra-alerts-services:
      requests:
        cpu: 200m
        memory: 256Mi
tp-cp-o11y:
  enabled: true
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
tp-cp-configuration:
  tp-cp-subscription:
    resources:
      requests:
       cpu: 100m
       memory: 128Mi
tp-cp-recipes:
  enabled: true
tp-cp-core:
  cronjobs:
    cpcronjobservice:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
    replicaCount: 1
  identity-management:
    idm:
      resources:
        requests:
          cpu: 100m
          memory: 1024Mi
    replicaCount: 1
  identity-provider:
    replicaCount: 1
    tpcpidpservice:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
  orchestrator:
    cporchservice:
      resources:
        requests:
          cpu: 500m
          memory: 256Mi
    replicaCount: 1
  pengine:
    replicaCount: 1
    tpcppengineservice:
      resources:
        requests:
          cpu: 300m
          memory: 128Mi
  user-subscriptions:
    cpusersubservice:
      resources:
        requests:
          cpu: 500m
          memory: 128Mi
    replicaCount: 1
  web-server:
    cpwebserver:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
    replicaCount: 1
tp-cp-core-finops:
  finops-otel-collector:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
  finops-service:
    finopsservice:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
  monitoring-service:
    monitoringservice:
      resources:
        requests:
          cpu: 100m
          memory: 512Mi
    replicaCount: 1   
tp-cp-integration:
  enabled: true
  tp-cp-integration-common:
    fileserver:
      enabled: true
      resources:
        requests:
          cpu: 100m
          memory: 128Mi  
  tp-cp-integration-bw:
    enabled: true  
    bw-webserver:
      bwwebserver:
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
  tp-cp-integration-flogo:
    enabled: true
    flogo-webserver:
      flogowebserver:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
  tp-cp-bwce-utilities:
    enabled: true
  tp-cp-bw5ce-utilities:
    enabled: true    
  tp-cp-flogo-utilities:
    enabled: true         
tp-cp-tibcohub-contrib:
  enabled: true
tibco-cp-messaging:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
tp-cp-hawk-recipes:
  enabled: true
tp-cp-hawk:
  enabled: true
  tp-cp-hawk-infra-querynode:  
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
tp-cp-cli:
  enabled: true
tp-cp-alertmanager:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
tp-cp-prometheus:
  server:
    retention: "15d"
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
tp-cp-auditsafe:
  enabled: true
  auditsafe:
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
EOF
```

### Step 8.8: Access Control Plane and Retrieve Initial Admin Password

After the platform-base installation completes successfully, you need to retrieve the initial admin password and access the Control Plane.

#### 8.8.1: Retrieve Initial Admin Password

The platform-base chart creates a temporary job that generates the initial admin password. This job is only available for **1 hour** after installation and is then automatically deleted.

> [!IMPORTANT]
> **Critical Timing**: The `tp-control-plane-ops-create-admin-user` job is deleted after one hour of deployment. You must retrieve the initial password before this time expires.

**Step 1: Get the create admin job details**
```bash
kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user
```

**Step 2: Get the logs of the create admin job**
```bash
# Replace <job-name> with the actual job name from step 1
kubectl logs -n ${CP_INSTANCE_ID}-ns jobs/<job-name>

# Alternative: Direct command using grep
kubectl logs -n ${CP_INSTANCE_ID}-ns $(kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user | awk '{print $1}')
```

**Step 3: Extract the password from logs**
In the logs, search for the value of `initialPassword`. 

**Step 4: Decode the password (if needed)**
```bash
# Use the initialPassword value from the logs
echo '"<initialPassword>"' | jq -r .
```

**Expected output will contain**:
- Admin email: `${CP_ADMIN_EMAIL}` (e.g., cp-test@tibco.com)
- Initial password: `<generated-password>`

#### 8.8.2: Access Control Plane UI

Once you have the initial password, access the Control Plane:

**Control Plane URL**: `https://admin.${CP_MY_DNS_DOMAIN}`

Example: `https://admin.cp1-my.apps.nxp.atsnl-emea.azure.dataplanes.pro`

#### 8.8.3: First Login Steps

1. **Navigate to Control Plane URL**: Open the Control Plane URL in your browser
2. **Select Identity Provider**: For first-time access, click on **"Using Default IdP"** option
3. **Login with admin credentials**:
   - **Email**: `${CP_ADMIN_EMAIL}` (e.g., cp-test@tibco.com)
   - **Password**: Use the password retrieved from the job logs (and decoded if necessary)
4. **Mandatory password reset**: The system will force you to reset the password on first login - this is required for security
5. **Set new password**: Choose a strong password and confirm it
6. **Complete setup**: After password reset, you'll have full access to the Control Plane console

> [!NOTE]
> **Admin User Behavior**: The admin user specified during Control Plane installation does not receive an activation email, regardless of whether email service is configured. The password must be retrieved from the job logs as described above.

#### 8.8.4: Troubleshooting Access Issues

**If you cannot retrieve the password (job expired)**:
```bash
# Check if the create admin job still exists
kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user

# If job is deleted, check for any remaining pods
kubectl get pods -n ${CP_INSTANCE_ID}-ns | grep create-admin

# List all jobs to see what's available
kubectl get jobs -n ${CP_INSTANCE_ID}-ns
```

**If password reset is needed**:
- Use the "Forgot Password" link on the login page
- Check MailDev email interface for reset emails at `https://mail.nxp.atsnl-emea.azure.dataplanes.pro`
- Or contact your platform administrator

> [!IMPORTANT]  
> **First Login Requirements**: 
> - The user must reset the password on the first time login to TIBCO Platform Console
> - For first-time access, you must sign in "Using Default IdP" option
> - After first login, you can use either the default IdP or any configured IdP

> [!IMPORTANT]
> **Security Best Practice**: Always change the initial generated password on first login and store it securely. The temporary job containing the initial password is automatically deleted after 1 hour for security reasons.

### Control Plane Information Summary

| Name                 | Sample value                                                                     | Notes                                                                     |
|:---------------------|:---------------------------------------------------------------------------------|:--------------------------------------------------------------------------|
| Node CIDR             | 10.5.2.0/23                                                                    | from Worker Node subnet (TP_WORKER_SUBNET_CIDR)                                      |
| Service CIDR             | 172.30.0.0/16                                                                    | Run: `az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv`                                        |
| Pod CIDR             | 10.128.0.0/14                                                                    | Run: `az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv`                                        |
| Ingress class name   | openshift-default                                                                            | used for TIBCO Control Plane `my` and `tunnel` ingresses                                               |
| File storage class    |   azure-files-sc                                                                    | used for TIBCO Control Plane                                                                   |
| Disk storage class    |   azure-disk-sc                                                                    | used for PostgreSQL                                                                   |
| PostgreSQL |  postgresql.tibco-ext.svc.cluster.local:5432   | used for TIBCO Control Plane |
| PostgreSQL database@username:password |  postgres@postgres:postgres   | used for TIBCO Control Plane |


### Next Steps for Control Plane

After completing the platform-base installation:

1. **Retrieve initial admin password**: Follow [Step 8.8.1](#881-retrieve-initial-admin-password) to get the temporary password from the job logs
2. **Access Control Plane UI**: Use the URL `https://admin.${CP_MY_DNS_DOMAIN}` with the admin credentials
3. **First login requirements**: Use "Default IdP" option and complete mandatory password reset
4. **Platform administration**: After successful login, you can:
   - **Provision subscriptions**: Set up subscriptions for different teams or environments
   - **Add admin users**: Create additional administrative users for platform management
   - **Register Data Planes**: Connect Data Plane clusters for application deployment
   - **Manage capabilities**: Provision and configure TIBCO capabilities (BWCE, Flogo, etc.)

**What to do next**:
- **Subscription management**: Start provisioning subscriptions for your organization
- **User management**: Add more admin users as needed
- **Data Plane setup**: Proceed to [Step 9: TIBCO Platform Data Plane Setup](#step-9-tibco-platform-data-plane-setup) if deploying on the same cluster

For detailed platform administration and usage, refer to [the TIBCO Platform documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm).

---

## Step 9: TIBCO Platform Data Plane Setup

**Why this step is needed:** The TIBCO Data Plane provides the runtime environment for executing applications and services:
- **Application execution**: Hosts and runs TIBCO applications (BusinessWorks, Flogo, etc.)
- **Capability provisioning**: Provides runtime capabilities like messaging, data processing, and integration
- **Resource management**: Manages compute, memory, and storage resources for applications
- **Connectivity**: Establishes secure connections to Control Plane for management and monitoring

**What this accomplishes:**
- **Data Plane deployment**: Installs the runtime platform for application execution
- **Observability setup**: Configures monitoring, logging, and metrics collection
- **Networking configuration**: Sets up ingress and network policies for application access
- **Capability registration**: Connects Data Plane capabilities to Control Plane for management

This section covers Data Plane specific configuration. The Data Plane can connect to either:
- The Control Plane deployed in [Step 8](#step-8-tibco-platform-control-plane-setup) (on the same cluster)
- An external SaaS Control Plane


### Step 9.1: Configure Observability

**Why this step is needed:** Observability is critical for Data Plane operations to:
- **Monitor application health**: Track performance metrics and application status
- **Enable troubleshooting**: Collect logs and traces for debugging issues
- **Ensure security**: Monitor access patterns and security events
- **Capacity planning**: Track resource usage for scaling decisions

**What this accomplishes:**
- **Network policy setup**: Enables ingress traffic flow to Data Plane services
- **Observability framework**: Prepares the foundation for monitoring and logging
- **Security boundaries**: Establishes proper network isolation while allowing necessary communication

> [!NOTE]
> Ingress Controller and Storage Classes were already configured in [Step 7: Configure Shared Infrastructure](#step-7-configure-shared-infrastructure).

If you are using network policies, ensure that network traffic is allowed from the default ingress namespace to the Data Plane namespace pods:

```bash
oc label namespace openshift-ingress networking.platform.tibco.com/non-dp-ns=enable --overwrite=true
```

#### DNS Configuration
For the Data Plane, we use the default DNS provisioned for ARO cluster. The base DNS can be found using:

```bash
oc get ingresscontroller -n openshift-ingress-operator default -o json | jq -r '.status.domain'
```
It should be something like "apps.<random_alphanumeric_string>.${TP_AZURE_REGION}.aroapp.io"
#### Grant Privileged SCC to Service Accounts

To ensure Data Plane workloads have the necessary permissions, grant the `privileged` Security Context Constraint (SCC) to the default and `dp1-sa` service accounts in the `dp1` namespace:

```bash
oc adm policy add-scc-to-user privileged -z default -n dp1
oc adm policy add-scc-to-user privileged -z dp1-sa -n dp1
```

*This step allows pods running under these service accounts to use the `privileged` SCC, which may be required for some TIBCO Platform components.*

#### Observability Configuration

**Note 1:** This is optional because if you already have your observability stack we can configure to use yours. For logs and traces DP needs Elastic. For metrics DP needs prometheus.

**Note 2:** You can also configure observability after creating/registering the Data Plane.

**Elastic Stack**

Install ECK via OperatorHub:  
[Elastic ECK on OpenShift](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/deploy-eck-on-openshift)

Follow Elastic configuration guide for creating all the indexes needed for the TIBCO Platform
[Prepare logs and traces server](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/preparing-logs-and-traces-servers.htm?TocPath=Observability%2520in%2520TIBCO%2520Control%2520Plane%257CConfiguring%2520Observability%2520Resource%257C_____1)

**Prometheus**

**Note:** There is already a prometheus provisioned in the ARO cluster. For DP we will provision our own prometheus in the namespace mentioned below. 

Prometheus is pre-installed. To scrape metrics from Data Plane, create a ServiceMonitor:

```
# Using DP_NAMESPACE variable from Step 7.1
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
    name: otel-collector-monitor
    namespace: ${DP_NAMESPACE}
spec:
    endpoints:
    - interval: 30s
      path: /metrics
      port: prometheus
      scheme: http
    jobLabel: otel-collector
    selector:
      matchLabels:
        app.kubernetes.io/name: otel-userapp-metrics
EOF
```

To access inbuilt ARO Prometheus externally, use a service account token:

```markdown
To access Prometheus externally, you can create a dedicated service account with the necessary permissions. The following example uses a service account named `thanos-client`, which is a common convention when integrating with Thanos or other external monitoring tools, but you can use any name you prefer:

```bash
oc create sa thanos-client -n openshift-monitoring 
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z thanos-client -n openshift-monitoring
TOKEN=$(oc create token thanos-client -n openshift-monitoring)
```

- `thanos-client` is simply a service account name; it does not require Thanos to be installed. This account is granted the `cluster-monitoring-view` role, allowing it to access Prometheus metrics.
- The generated token (`$TOKEN`) can be used to authenticate with Prometheus endpoints for external scraping or dashboard access.


### Step 9.2: Deploy TIBCO Platform Data Plane

**For SaaS Control Plane:**
Login to your SaaS CP and Register a new Data plane. 

**Note:** If you do not have an access to SaaS CP assigned to your customer work with TIBCO ATS Team.
Usually there is an invitation email sent to the manager or account lead. 

**For On-Premises Control Plane:**
If you deployed a Control Plane using [Step 7](#step-7-tibco-platform-control-plane-setup), access your Control Plane UI at `https://<subdomain>.${CP_MY_DNS_DOMAIN}` and register a new Data Plane.

Follow the wizard which will generate following helm commands with a unique DP ID. 

Dataplane name: aroCluster or aroDataplane or aroStaging
Dataplane k8s namespace: dp1

#### 9.2.1. Add Helm Repo

```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform-public
```

#### 9.2.2. Create Namespace

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: dp1
    labels:
        platform.tibco.com/dataplane-id: <your-dataplane-id>
EOF
```

#### 9.2.3. Configure Namespace

```bash
helm upgrade --install -n dp1 dp-configure-namespace tibco-platform-public/dp-configure-namespace \
    --version 1.7.5 \
    --set global.tibco.dataPlaneId=<your-dataplane-id> \
    --set global.tibco.subscriptionId=<your-subscription-id> \
    --set global.tibco.primaryNamespaceName=dp1 \
    --set global.tibco.serviceAccount=sa \
    --set global.tibco.containerRegistry.url=<your-registry-url> \
    --set global.tibco.containerRegistry.username=<your-registry-username> \
    --set global.tibco.containerRegistry.password=<your-registry-password> \
    --set global.tibco.containerRegistry.repository=tibco-platform-docker-prod \
    --set global.tibco.enableClusterScopedPerm=true \
    --set networkPolicy.createDeprecatedPolicies=false
```

#### 9.2.4. Deploy Core Infrastructure

```bash
helm upgrade --install dp-core-infrastructure -n dp1 tibco-platform-public/dp-core-infrastructure \
    --version 1.7.2 \
    --set global.tibco.dataPlaneId=<your-dataplane-id> \
    --set global.tibco.subscriptionId=<your-subscription-id> \
    --set tp-tibtunnel.configure.accessKey=<your-access-key> \
    --set tp-tibtunnel.connect.url=<your-tibtunnel-url> \
    --set global.tibco.serviceAccount=sa \
    --set global.tibco.containerRegistry.url=<your-registry-url> \
    --set global.tibco.containerRegistry.repository=tibco-platform-docker-prod \
    --set global.proxy.noProxy='' \
    --set global.logging.fluentbit.enabled=true
```

---

## Step 10: Provision TIBCO BWCE and Flogo Capabilities from the GUI

Once the Data Plane is registered and core infrastructure is deployed, you can provision additional capabilities such as TIBCO BusinessWorks Container Edition (BWCE) and TIBCO Flogo directly from the TIBCO Control Plane GUI.

### Steps:

1. **Login to TIBCO Control Plane:**
    - **For SaaS:** Navigate to your TIBCO Control Plane SaaS URL and sign in.
    - **For On-Premises:** Navigate to your Control Plane URL (`https://<subdomain>.${CP_MY_DNS_DOMAIN}`) and sign in.

> **Note:** If this is your first time accessing the Control Plane, check the MailDev email interface at `https://mail.nxp.atsnl-emea.azure.dataplanes.pro` for the administrator activation email. Click the activation link in the email to set up your admin account before proceeding.

2. **Select Your Data Plane:**
    - Go to the "Data Planes" section and select the Data Plane you registered and deployed.

3. **Add Capabilities:**
    - Click on "Provision a Capability".
    - Choose **TIBCO BusinessWorks Container Edition (BWCE)** or **TIBCO Flogo** from the list and press Start button
    - Configure storage class azure-files-sc for Flogo and/or BWCE
    - For ingress: use the base URL and prefix it with `flogo.` or `bwce.`. You can find the base URL using [Get OpenShift Ingress Domain](#get-openshift-ingress-domain).
    - Follow the wizard to configure other required parameters
    - Once finished you will see BWCE and/or Flogo Capability provisioned

4. **Monitor Deployment:**
    - The Control Plane will show the capability provisioning/deployment status.
    - You can monitor progress and logs from the GUI or by checking pods in the corresponding namespace:

    ```bash
    oc -n dp1 get pods
    ```
5. **Deploy apps**
    - Now you can deploy the apps. Follow the documentation of BWCE or Flogo in case you are not aware of how to build your first project and deploy it to TIBCO Platform

> **Note:** The Control Plane GUI automates the Helm chart installation and configuration for these capabilities. No manual CLI steps are required for this process.

--- 

---

## Step 11: Clean Up

### Control Plane Clean Up

If you deployed a Control Plane, refer to [the steps to delete TIBCO Control Plane](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/uninstalling-tibco-control-plane.htm).

### Data Plane Clean Up

- Delete Data Plane from TIBCO Control Plane UI (whether SaaS or on-premises).
- Run cleanup script:

```bash
cd ../scripts
./clean-up.sh
```

> [!IMPORTANT]
> If you have used a common cluster for both TIBCO Control Plane and Data Plane, please check the script and add modifications so that common resources are not deleted.

---

## References

- [Azure ARO Documentation](https://learn.microsoft.com/en-us/azure/openshift/)
- [TIBCO Platform Helm Charts](https://tibcosoftware.github.io/tp-helm-charts)
- [Elastic ECK on OpenShift](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/deploy-eck-on-openshift)
- [OpenShift Monitoring](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/monitoring/accessing-metrics)

---

> **Note:** Adjust all placeholder values (e.g., `<your-dataplane-id>`, `<your-registry-url>`) as per your environment and TIBCO Control Plane configuration.

---

## Troubleshooting and Cluster Information Commands

This section provides useful commands for troubleshooting, monitoring, and inspecting your Azure Red Hat OpenShift (ARO) cluster and deployed workloads.

### Common ARO Cluster Creation Issues

#### Authorization Failed Errors
If you encounter permission errors during ARO cluster creation, refer to the troubleshooting section in [Step 3: Create ARO Cluster](#step-3-create-aro-cluster).

#### Network CIDR Conflicts
If you get errors about overlapping address spaces:
```bash
# Check existing VNets in the region
az network vnet list --resource-group ${TP_RESOURCE_GROUP} --query '[].{Name:name,AddressSpace:addressSpace}' -o table

# Update your CIDR ranges to avoid conflicts (these should match Step 1 variables)
# export TP_VNET_CIDR="10.5.0.0/16"  # Use non-overlapping range
# export TP_MASTER_SUBNET_CIDR="10.5.0.0/23"
# export TP_WORKER_SUBNET_CIDR="10.5.2.0/23"
```

#### Pull Secret Issues
If ARO creation fails due to pull secret problems:
```bash
# Verify pull secret format
cat pull-secret.txt | jq .

# Re-download from Red Hat Customer Portal if needed
# https://console.redhat.com/openshift/install/azure/aro-provisioned
```

### Verify ARO Cluster Status

```bash
# Check ARO cluster provisioning state
az aro show --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP} --query '{Name:name,State:provisioningState,Version:clusterProfile.version}' -o table

# Get cluster details
az aro show --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP}
```

### List All ARO Clusters in a Subscription

```bash
az aro list -o table
```
*Displays all Azure Red Hat OpenShift clusters in your current subscription.*

### Show Details for a Specific ARO Cluster

```bash
az aro show --resource-group ${TP_RESOURCE_GROUP} --name ${TP_CLUSTER_NAME}
```
*Shows detailed information about a specific ARO cluster.*

### Get ARO Cluster Credentials

```bash
az aro list-credentials --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP}
```
*Retrieves the kubeadmin credentials for your ARO cluster.*

### View and Verify Environment Variables

```bash
env | grep TP
```
*Shows all environment variables related to your deployment.*

### Get OpenShift Ingress Domain

```bash
oc get ingresscontroller -n openshift-ingress-operator default -o json | jq -r '.status.domain'
```
*Displays the default ingress domain for your OpenShift cluster.*
### Check Cluster Resources and Status

```bash
oc get ns
oc get pods -A
oc get deploy -A
oc get crds -A
oc get sc
oc get ingress -A
oc get storageaccounts
```
*Lists namespaces, pods, deployments, custom resources, storage classes, ingresses, and storage accounts.*

### Inspect Security Context Constraints (SCC)

```bash
oc get securitycontextconstraints.security.openshift.io
oc get scc tp-scc -o wide
```
*Lists all SCCs and details for the custom `tp-scc`.*

### Monitor Events and Pod Status

```bash
oc get events -w
kubectl get events --sort-by='.metadata.creationTimestamp' -n dp1 --watch
oc -n dp1 get pods -w
```
*Watches for real-time events and pod status changes in the `dp1` namespace.*

### View Logs for Troubleshooting

```bash
oc -n dp1 logs <pod-name>
oc -n dp1 logs -c <container-name> <pod-name>
```
*Fetches logs from a pod or a specific container within a pod.*

---

These commands help you quickly inspect, troubleshoot, and monitor your ARO cluster and TIBCO Platform Data Plane deployment.

---

## Summary Checklist: Objects and Resources Created

This comprehensive checklist includes all the objects, resources, and configurations created throughout this deployment guide. Use this to verify your deployment or troubleshoot missing components.

### 🎯 **Azure Infrastructure Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Resource Group | `${TP_RESOURCE_GROUP}` | 2 | Container for all Azure resources | ☐ |
| Virtual Network | `${TP_VNET_NAME}` (openshiftvnet) | 2 | Network isolation for ARO cluster | ☐ |
| Master Subnet | `${TP_MASTER_SUBNET_NAME}` (masterOpenshiftSubnet) | 2 | Master nodes network segment | ☐ |
| Worker Subnet | `${TP_WORKER_SUBNET_NAME}` (workerOpenshiftSubnet) | 2 | Worker nodes network segment | ☐ |
| ARO Cluster | `${TP_CLUSTER_NAME}` (aroCluster) | 3 | OpenShift cluster on Azure | ☐ |
| Service Principal | ARO Cluster SP | 3 | Identity for ARO cluster operations | ☐ |
| Role Assignment | Contributor on storage RG | 4.1 | ARO access to storage resources | ☐ |

### 🔐 **Security and Access Control Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Security Context Constraint | `tp-scc` | 6 | Custom SCC for TIBCO workloads | ☐ |
| Cluster Role | `azure-secret-reader` | 4.2 | Read secrets for persistent volumes | ☐ |
| Cluster Role Binding | `azure-secret-reader` to `persistent-volume-binder` | 4.2 | PV binder permissions | ☐ |
| Service Account | `${CP_INSTANCE_ID}-sa` | 8.1 | Control Plane service identity | ☐ |
| SCC Assignment | `tp-scc` to `${CP_INSTANCE_ID}-sa` | 8.1 | Control Plane SCC permissions | ☐ |
| SCC Assignment | `tp-scc` to `default` SA | 8.1 | Default SA SCC permissions | ☐ |

### 🌐 **Network and Ingress Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Ingress Controller Patch | Wildcard and inter-namespace support | 7.2 | Enable Control Plane domains | ☐ |
| DNS A Record | `*.${CP_INSTANCE_ID}-my.apps.${TP_CLUSTER_DOMAIN}` | 8.2 | Control Plane UI domain | ☐ |
| DNS A Record | `*.${CP_INSTANCE_ID}-tunnel.apps.${TP_CLUSTER_DOMAIN}` | 8.2 | Hybrid connectivity domain | ☐ |
| Network Label | `openshift-ingress` namespace | 8.2 | Network policy for CP ingress | ☐ |
| Network Label | `tibco-ext` namespace | 7.4 | Network policy for PostgreSQL | ☐ |
| Namespace | `external-dns-system` | 7.6 | External DNS namespace | ☐ |
| Secret | `azure-config-file` | 7.6 | Azure credentials for External DNS | ☐ |
| Helm Release | `external-dns` | 7.6 | Automatic DNS record management | ☐ |

### 💾 **Storage Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Storage Class | `${TP_FILE_STORAGE_CLASS}` (azure-files-sc) | 7.3 | Azure Files for shared storage | ☐ |
| Storage Class | `${TP_DISK_STORAGE_CLASS}` (azure-disk-sc) | 7.3 | Azure Disk for high-performance storage | ☐ |
| Storage Class | `azure-files-sc-ems` | 7.3 | Azure Files for EMS with NFS | ☐ |

### 🗄️ **Database and External Services**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Namespace | `tibco-ext` | 7.4 | External services namespace | ☐ |
| Helm Release | `postgresql` | 7.4 | PostgreSQL database for Control Plane | ☐ |
| PostgreSQL Database | `postgres` | 7.4 | Control Plane metadata storage | ☐ |
| Deployment | `maildev` | 7.5 | Development email server for Control Plane | ☐ |
| Service | `development-mailserver` | 7.5 | Email server service (SMTP port 1025, Web port 1080) | ☐ |
| Route | `maildev-route` | 7.5 | Email web interface access | ☐ |

### 🔑 **Certificates and Secrets**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| TLS Certificate | Let's Encrypt for `*.${CP_MY_DNS_DOMAIN}` | 8.2 | Control Plane UI SSL certificate | ☐ |
| TLS Certificate | Let's Encrypt for `*.${CP_TUNNEL_DNS_DOMAIN}` | 8.2 | Hybrid connectivity SSL certificate | ☐ |
| TLS Secret | `${CP_MY_TLS_SECRET_NAME}` (custom-my-tls) | 8.2 | Control Plane UI certificate storage | ☐ |
| TLS Secret | `${CP_TUNNEL_TLS_SECRET_NAME}` (custom-tunnel-tls) | 8.2 | Tunnel certificate storage | ☐ |
| Generic Secret | `session-keys` | 8.3 | Control Plane session encryption keys | ☐ |
| Generic Secret | `cporch-encryption-secret` | 8.5 | Control Plane orchestration encryption | ☐ |
| Generic Secret | `${CP_DB_SECRET_NAME}` | 8.6 | Database credentials for Control Plane | ☐ |

### 🏗️ **TIBCO Platform Control Plane Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Namespace | `${CP_INSTANCE_ID}-ns` | 8.1 | Control Plane isolation namespace | ☐ |
| Helm Release | `platform-bootstrap` | 8.4 | Control Plane bootstrap components | ☐ |
| Helm Release | `platform-base` | 8.6 | Control Plane core components | ☐ |
| Ingress Route | `*.${CP_MY_DNS_DOMAIN}` | 8.4 | Control Plane UI access | ☐ |
| Ingress Route | `*.${CP_TUNNEL_DNS_DOMAIN}` | 8.4 | Hybrid connectivity access | ☐ |

### 🚀 **TIBCO Platform Data Plane Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Namespace | `${DP_NAMESPACE}` (dp1) | 9.2 | Data Plane isolation namespace | ☐ |
| Helm Release | `dp-configure-namespace` | 9.2 | Data Plane namespace configuration | ☐ |
| Helm Release | `dp-core-infrastructure` | 9.2 | Data Plane core infrastructure | ☐ |
| ServiceMonitor | `otel-collector-monitor` | 9.1 | Prometheus metrics collection | ☐ |
| Network Label | `openshift-ingress` namespace | 9.1 | Network policy for DP ingress | ☐ |
| SCC Assignment | `privileged` to `default` SA in dp1 | 9.1 | Data Plane workload permissions | ☐ |
| SCC Assignment | `privileged` to `sa` SA in dp1 | 9.1 | Data Plane service permissions | ☐ |

### 📊 **Observability Objects**

| **Object Type** | **Name/Description** | **Step** | **Purpose** | **Status** |
|:----------------|:---------------------|:---------|:------------|:-----------|
| Service Account | `thanos-client` | 9.1 | External Prometheus access | ☐ |
| Cluster Role Binding | `cluster-monitoring-view` to `thanos-client` | 9.1 | Prometheus metrics access | ☐ |

### 🎛️ **Configuration Variables and Environment**

| **Category** | **Count** | **Step** | **Purpose** | **Status** |
|:-------------|:----------|:---------|:------------|:-----------|
| Azure Infrastructure Variables | 14 | 1, 7.1 | Azure and cluster configuration | ☐ |
| Network Configuration Variables | 4 | 7.1 | Network and CIDR settings | ☐ |
| DNS and Domain Variables | 6 | 7.1 | Domain and ingress configuration | ☐ |
| Storage Configuration Variables | 2 | 7.1 | Storage class definitions | ☐ |
| Container Registry Variables | 4 | 7.1 | Image registry access | ☐ |
| Control Plane Variables | 18 | 7.1 | Control Plane specific settings | ☐ |
| Data Plane Variables | 1 | 7.1 | Data Plane specific settings | ☐ |

### 🔧 **Verification Commands**

Use these commands to verify the deployment status:

```bash
# Check all namespaces
oc get ns | grep -E "(cp1-ns|dp1|tibco-ext)"

# Check storage classes
oc get sc | grep -E "(azure-files-sc|azure-disk-sc)"

# Check security context constraints
oc get scc tp-scc

# Check Control Plane pods
oc get pods -n ${CP_INSTANCE_ID}-ns

# Check Data Plane pods
oc get pods -n ${DP_NAMESPACE}

# Check PostgreSQL
oc get pods -n tibco-ext

# Check email server
oc get pods -n tibco-ext -l app=development-mailserver

# Check email server route
oc get route maildev-route -n tibco-ext

# Test email server accessibility
curl -I https://mail.nxp.atsnl-emea.azure.dataplanes.pro

# Check External DNS
oc get pods -n external-dns-system
oc logs -n external-dns-system deployment/external-dns | tail -10

# Check certificates
oc get secrets -n ${CP_INSTANCE_ID}-ns | grep tls

# Check ingress routes
oc get routes -n ${CP_INSTANCE_ID}-ns
```

---

**📝 Note**: This checklist serves as a comprehensive verification tool. Mark each item as complete (☑️) as you progress through the deployment to ensure nothing is missed.

