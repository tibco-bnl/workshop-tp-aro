#!/bin/bash

# ==============================================================================
# Azure Red Hat OpenShift (ARO) Environment Variables Initialization
# ==============================================================================
# This script consolidates all environment variables required for deploying
# TIBCO Platform Control Plane and Data Plane on Azure Red Hat OpenShift (ARO)
#
# Reference: https://github.com/tibco-bnl/workshop-tp-aro/blob/main/howto/how-to-cp-and-dp-openshift-aro-aks-setup-guide.md
# ==============================================================================

# Login to Azure
az login

# ========================================
# AZURE AND CLUSTER INFRASTRUCTURE VARIABLES
# ========================================
# Azure Subscription and Tenant (automatically retrieved from Azure CLI)
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_TENANT_ID=$(az account show --query tenantId -o tsv)

# Azure Region and Resource Group
export TP_AZURE_REGION="westeurope"                # Change to your preferred region
export TP_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc" # Change to your resource group name

# ARO Cluster Configuration
export TP_CLUSTER_NAME="aroCluster"
export TP_WORKER_COUNT=6
export TP_WORKER_VM_SIZE="Standard_D8s_v5"
export TP_WORKER_VM_DISK_SIZE_GB="128"

# Network Configuration for ARO Cluster
export TP_VNET_NAME="openshiftvnet"
export TP_MASTER_SUBNET_NAME="masterOpenshiftSubnet"
export TP_WORKER_SUBNET_NAME="workerOpenshiftSubnet"
export TP_VNET_CIDR="10.5.0.0/16"
export TP_MASTER_SUBNET_CIDR="10.5.0.0/23"
export TP_WORKER_SUBNET_CIDR="10.5.2.0/23"

# ========================================
# NETWORK CONFIGURATION VARIABLES
# ========================================
# Network specific variables (get actual values from your ARO cluster after creation)
export TP_NODE_CIDR="10.5.2.0/23"      # Node CIDR: from Worker Node subnet CIDR (TP_WORKER_SUBNET_CIDR)
export TP_POD_CIDR="10.128.0.0/14"     # Pod CIDR: Run the command below to get actual value
# az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv
export TP_SERVICE_CIDR="172.30.0.0/16" # Service CIDR: Run the command below to get actual value
# az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv

# Network policy configuration
export TP_ENABLE_NETWORK_POLICY="false" # Set to "true" to enable network policies

# ========================================
# DNS AND DOMAIN CONFIGURATION VARIABLES
# ========================================
# Domain specific variables
export TP_CLUSTER_DOMAIN="nxp.atsnl-emea.azure.dataplanes.pro" # Replace with your DNS Zone name
export TP_DNS_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"         # Replace with resource group containing DNS zone
export TP_TOP_LEVEL_DOMAIN="${TP_CLUSTER_DOMAIN}"              # Top level domain
export TP_SANDBOX="apps"                                       # Hostname prefix of TP_DOMAIN
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"       # Full domain to be used
export TP_INGRESS_CLASS="openshift-default"                    # Main ingress class for capabilities

# ========================================
# STORAGE CONFIGURATION VARIABLES
# ========================================
# Storage class names for Azure storage
export TP_DISK_STORAGE_CLASS="azure-disk-sc"  # Azure disk storage class name
export TP_FILE_STORAGE_CLASS="azure-files-sc" # Azure files storage class name

# ========================================
# OBSERVABILITY CONFIGURATION VARIABLES
# ========================================
# LogServer specific variables (optional - leave empty if not using)
export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX=""    # LogServer index to push the logs to
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""

# ========================================
# CONTAINER REGISTRY VARIABLES
# ========================================
# Container Registry variables (shared by both Control Plane and Data Plane)
export TP_CONTAINER_REGISTRY_URL="csgprdeuwrepoedge.jfrog.io" # JFrog edge node URL
export TP_CONTAINER_REGISTRY_USER=""                          # Replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD=""                      # Replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # Container registry repository

# ========================================
# HELM CHART CONFIGURATION VARIABLES
# ========================================
# Helm chart repository variables
export TP_CHART_REPO_USER_NAME=""         # Leave empty if using public repo
export TP_CHART_REPO_TOKEN=""             # Leave empty if using public repo
export HELM_URL="tibco-platform-public"   # Helm repository name

# ========================================
# CONTROL PLANE SPECIFIC VARIABLES
# ========================================
# Control Plane Instance Configuration
export CP_INSTANCE_ID="cp1" # Unique ID for Control Plane (max 5 alphanumeric chars)
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_DOMAIN}"       # Domain for Control Plane UI
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}" # Domain for hybrid connectivity

# Control Plane chart versions (unified chart since 1.13.0)
export CP_TIBCO_CP_BASE_VERSION="1.14.0"

# Storage configuration for Control Plane
export CP_STORAGE_SIZE="10Gi" # Storage size for Control Plane components

# TLS Secret names for Control Plane
export CP_MY_TLS_SECRET_NAME="custom-my-tls"           # TLS secret for Control Plane UI domain
export CP_TUNNEL_TLS_SECRET_NAME="custom-tunnel-tls"   # TLS secret for hybrid connectivity domain

# Email configuration for certificates
export EMAIL="cp-test@tibco.com"                       # Email for certificates
export EMAIL_FOR_CERTBOT="kulbhushan.bhalerao@tibco.com" # Email for certbot registration

# Database configuration variables
export CP_DB_HOST="postgresql.tibco-ext.svc.cluster.local" # PostgreSQL host (on-premises deployment)
export CP_DB_NAME="postgres"
export CP_DB_PASSWORD="postgres"        # Change to a secure password
export CP_DB_PORT="5432"
export CP_DB_SECRET_NAME="provider-cp-database-credentials"
export CP_DB_SSL_MODE="disable"         # Options: disable, require, verify-ca, verify-full
export CP_DB_USERNAME="postgres"

# Azure PostgreSQL SaaS Configuration (uncomment if using Azure PostgreSQL instead of on-premises)
# export CP_DB_HOST="<your-postgres-server>.postgres.database.azure.com"
# export CP_DB_USERNAME="<admin-user>@<server-name>"
# export CP_DB_PASSWORD="<your-password>"
# export CP_DB_SSL_MODE="require"  # Options: require, verify-ca, verify-full
# export CP_DB_SSL_ROOT_CERT_SECRET_NAME="azure-postgres-ssl-cert"
# export CP_DB_SSL_ROOT_CERT_FILENAME="BaltimoreCyberTrustRoot.crt.pem"

# Email server configuration variables
export CP_EMAIL_SERVER_TYPE="smtp"
export CP_EMAIL_SMTP_SERVER="development-mailserver.tibco-ext.svc.cluster.local" # MailDev server
export CP_EMAIL_SMTP_PORT="1025"
export CP_EMAIL_SMTP_USERNAME="" # Empty - MailDev doesn't require authentication
export CP_EMAIL_SMTP_PASSWORD="" # Empty - MailDev doesn't require authentication

# Admin user configuration variables
export CP_ADMIN_EMAIL="${EMAIL}"
export CP_ADMIN_FIRSTNAME="cp-test"
export CP_ADMIN_LASTNAME="cp-test"
export CP_ADMIN_CUSTOMER_ID="nxp-customer-id"

# ========================================
# DATA PLANE SPECIFIC VARIABLES
# ========================================
# Data Plane specific variables (only needed if deploying Data Plane)
export DP_NAMESPACE="dp1" # Replace with your Data Plane namespace

# ==============================================================================
# CLUSTER CONNECTION AND VERIFICATION
# ==============================================================================

echo ""
echo "========================================="
echo "Environment Variables Initialized"
echo "========================================="
echo "Azure Subscription: ${TP_SUBSCRIPTION_ID}"
echo "Azure Tenant: ${TP_TENANT_ID}"
echo "Resource Group: ${TP_RESOURCE_GROUP}"
echo "Cluster Name: ${TP_CLUSTER_NAME}"
echo "Region: ${TP_AZURE_REGION}"
echo "========================================="
echo ""

# Retrieve ARO cluster credentials
echo "Retrieving ARO cluster credentials..."
az aro list-credentials --name ${TP_CLUSTER_NAME} --resource-group ${TP_RESOURCE_GROUP}

# Get API server URL and login command
apiServer=$(az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query apiserverProfile.url -o tsv)
kubeadminPassword=$(az aro list-credentials -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query kubeadminPassword -o tsv)

echo ""
echo "========================================="
echo "ARO Cluster Login Information"
echo "========================================="
echo "API Server: ${apiServer}"
echo "Username: kubeadmin"
echo "Password: ${kubeadminPassword}"
echo "========================================="
echo ""
echo "To login to the cluster, run:"
echo "oc login ${apiServer} -u kubeadmin -p ${kubeadminPassword}"
echo ""

# Print all initialized environment variables for verification
echo "========================================="
echo "All Environment Variables"
echo "========================================="
env | grep -E '^(TP_|CP_|DP_|HELM_|EMAIL)' | sort
echo "========================================="
