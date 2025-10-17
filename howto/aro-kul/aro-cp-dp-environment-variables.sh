#!/bin/bash

# ==============================================================================
# TIBCO Platform ARO Environment Variables Configuration Script
# ==============================================================================
# This script contains all environment variables required for deploying
# TIBCO Platform Control Plane and Data Plane on Azure Red Hat OpenShift (ARO)
# 
# Usage:
#   source ./aro-environment-variables.sh
#   or
#   . ./aro-environment-variables.sh
#
# Note: Update the values below according to your specific environment
# ==============================================================================

echo "Setting up TIBCO Platform ARO Environment Variables..."

# ==============================================================================
# AZURE AND CLUSTER INFRASTRUCTURE VARIABLES
# ==============================================================================
echo "Setting Azure and Cluster Infrastructure variables..."

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

# ==============================================================================
# NETWORK CONFIGURATION VARIABLES
# ==============================================================================
echo "Setting Network Configuration variables..."

# Network specific variables (get actual values from your ARO cluster)
export TP_NODE_CIDR="10.5.2.0/23" # Node CIDR: from Worker Node subnet CIDR (TP_WORKER_SUBNET_CIDR)
export TP_POD_CIDR="10.128.0.0/14" # Pod CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv
export TP_SERVICE_CIDR="172.30.0.0/16" # Service CIDR: Run the command az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv

# Network policy specific variables
export TP_ENABLE_NETWORK_POLICY="false" # possible values "true", "false"

# ==============================================================================
# DNS AND DOMAIN CONFIGURATION VARIABLES
# ==============================================================================
echo "Setting DNS and Domain Configuration variables..."

# Domain specific variables
export TP_CLUSTER_DOMAIN="nxp.atsnl-emea.azure.dataplanes.pro" # replace it with your DNS Zone name
export TP_DNS_RESOURCE_GROUP="kul-atsbnl-flogo-azfunc"  # replace with name of resource group containing dns record sets
export TP_TOP_LEVEL_DOMAIN="${TP_CLUSTER_DOMAIN}" # top level domain of TP_DOMAIN
export TP_SANDBOX="apps" # hostname of TP_DOMAIN
export TP_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}" # domain to be used
export TP_INGRESS_CLASS="openshift-default" # name of main ingress class used by capabilities

# ==============================================================================
# STORAGE CONFIGURATION VARIABLES
# ==============================================================================
echo "Setting Storage Configuration variables..."

# Storage specific variables
export TP_DISK_STORAGE_CLASS="azure-disk-sc" # name of azure disk storage class
export TP_FILE_STORAGE_CLASS="azure-files-sc" # name of azure files storage class

# ==============================================================================
# OBSERVABILITY CONFIGURATION VARIABLES
# ==============================================================================
echo "Setting Observability Configuration variables..."

# LogServer specific variables (optional)
export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX="" # logserver index to push the logs to
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""

# ==============================================================================
# CONTAINER REGISTRY VARIABLES
# ==============================================================================
echo "Setting Container Registry variables..."

# Container Registry variables (shared by both Control Plane and Data Plane)
export TP_CONTAINER_REGISTRY_URL="csgprdeuwrepoedge.jfrog.io" # jfrog edge node url us-west-2 region, replace with container registry url as per your deployment region
export TP_CONTAINER_REGISTRY_USER="" # replace with your container registry username
export TP_CONTAINER_REGISTRY_PASSWORD="" # replace with your container registry password
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod" # replace with your container registry repository

# ==============================================================================
# HELM CHART CONFIGURATION VARIABLES
# ==============================================================================
echo "Setting Helm Chart Configuration variables..."

# Helm chart repository variables
export TP_CHART_REPO_USER_NAME=""
export TP_CHART_REPO_TOKEN=""
export HELM_URL="tibco-platform-public"

# ==============================================================================
# CONTROL PLANE SPECIFIC VARIABLES
# ==============================================================================
echo "Setting Control Plane specific variables..."

# Control Plane Instance specific variables (only needed if deploying Control Plane)
export CP_INSTANCE_ID="cp1" # unique id to identify multiple cp installation in same cluster (alphanumeric string of max 5 chars)
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_DOMAIN}" # domain to be used for Control Plane UI
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_DOMAIN}" # domain to be used for hybrid connectivity

# Control Plane chart versions
export CP_PLATFORM_BOOTSTRAP_VERSION="1.11.0"
export CP_PLATFORM_BASE_VERSION="1.11.0"

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

# ==============================================================================
# DATA PLANE SPECIFIC VARIABLES
# ==============================================================================
echo "Setting Data Plane specific variables..."

# Data Plane specific variables (only needed if deploying Data Plane)
export DP_NAMESPACE="dp1" # Replace with your namespace

# ==============================================================================
# ADDITIONAL HELPER VARIABLES
# ==============================================================================
echo "Setting additional helper variables..."

# ARO Service Principal and Storage variables (used in Step 4)
export ARO_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"
export CLUSTER="${TP_CLUSTER_NAME}"
export AZURE_FILES_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"

# ==============================================================================
# VERIFICATION AND HELPER COMMANDS
# ==============================================================================
echo ""
echo "Environment variables set successfully!"
echo ""
echo "=== Key Configuration Summary ==="
echo "Subscription ID: ${TP_SUBSCRIPTION_ID}"
echo "Resource Group: ${TP_RESOURCE_GROUP}"
echo "Cluster Name: ${TP_CLUSTER_NAME}"
echo "Cluster Domain: ${TP_CLUSTER_DOMAIN}"
echo "Control Plane MY Domain: ${CP_MY_DNS_DOMAIN}"
echo "Control Plane Tunnel Domain: ${CP_TUNNEL_DNS_DOMAIN}"
echo "Control Plane Instance ID: ${CP_INSTANCE_ID}"
echo "Data Plane Namespace: ${DP_NAMESPACE}"
echo ""
echo "=== Next Steps ==="
echo "1. Verify cluster access: oc login"
echo "2. Get network CIDRs:"
echo "   Pod CIDR: az aro show -g \${TP_RESOURCE_GROUP} -n \${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv"
echo "   Service CIDR: az aro show -g \${TP_RESOURCE_GROUP} -n \${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv"
echo "3. Update TP_POD_CIDR and TP_SERVICE_CIDR if different from defaults"
echo ""
echo "=== Important Notes ==="
echo "- Update container registry credentials with your actual values"
echo "- Update DNS domain and resource group names"
echo "- Update email addresses for certificates and admin user"
echo "- Verify all domain names match your environment"
echo ""

# ==============================================================================
# OPTIONAL: DYNAMIC NETWORK CIDR DETECTION
# ==============================================================================
# Uncomment the following lines to automatically detect and set network CIDRs
# if you have az CLI configured and authenticated:

# echo "Detecting actual network CIDRs from ARO cluster..."
# DETECTED_POD_CIDR=$(az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.podCidr -o tsv 2>/dev/null)
# DETECTED_SERVICE_CIDR=$(az aro show -g ${TP_RESOURCE_GROUP} -n ${TP_CLUSTER_NAME} --query networkProfile.serviceCidr -o tsv 2>/dev/null)

# if [ ! -z "$DETECTED_POD_CIDR" ]; then
#     export TP_POD_CIDR="$DETECTED_POD_CIDR"
#     echo "Updated TP_POD_CIDR to: $TP_POD_CIDR"
# fi

# if [ ! -z "$DETECTED_SERVICE_CIDR" ]; then
#     export TP_SERVICE_CIDR="$DETECTED_SERVICE_CIDR"
#     echo "Updated TP_SERVICE_CIDR to: $TP_SERVICE_CIDR"
# fi

echo "Environment setup complete. You can now proceed with TIBCO Platform deployment."