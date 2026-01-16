#!/bin/bash
# TIBCO Control Plane Base Installation Script
# Merged from platform-bootstrap and platform-base deployments
# This script installs tibco-cp-base (unified chart version 1.14.0+)

set -e  # Exit on error

# ========================================
# ENVIRONMENT VARIABLES VALIDATION
# ========================================
echo "Validating required environment variables..."

REQUIRED_VARS=(
  "CP_INSTANCE_ID"
  "TP_NODE_CIDR"
  "TP_POD_CIDR"
  "TP_SERVICE_CIDR"
  "CP_MY_DNS_DOMAIN"
  "CP_TUNNEL_DNS_DOMAIN"
  "CP_STORAGE_SIZE"
  "TP_FILE_STORAGE_CLASS"
  "CP_DB_HOST"
  "CP_DB_NAME"
  "CP_DB_PASSWORD"
  "CP_DB_PORT"
  "CP_DB_USERNAME"
  "CP_DB_SECRET_NAME"
  "CP_DB_SSL_MODE"
  "CP_EMAIL_SERVER_TYPE"
  "CP_EMAIL_SMTP_SERVER"
  "CP_EMAIL_SMTP_PORT"
  "CP_ADMIN_EMAIL"
  "CP_ADMIN_FIRSTNAME"
  "CP_ADMIN_LASTNAME"
  "CP_ADMIN_CUSTOMER_ID"
  "TP_CONTAINER_REGISTRY_URL"
  "TP_CONTAINER_REGISTRY_USER"
  "TP_CONTAINER_REGISTRY_PASSWORD"
  "TP_CONTAINER_REGISTRY_REPOSITORY"
  "TP_INGRESS_CLASS"
  "CP_TUNNEL_TLS_SECRET_NAME"
  "CP_MY_TLS_SECRET_NAME"
  "HELM_URL"
  "CP_TIBCO_CP_BASE_VERSION"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

echo "All required environment variables are set."

# ========================================
# PREREQUISITES CHECK
# ========================================
echo "Checking prerequisites..."

# Check if namespace exists
if ! kubectl get namespace ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "ERROR: Namespace ${CP_INSTANCE_ID}-ns does not exist. Please create it first."
  echo "Run: kubectl create namespace ${CP_INSTANCE_ID}-ns"
  exit 1
fi

# Check if service account exists
if ! kubectl get serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "ERROR: Service account ${CP_INSTANCE_ID}-sa does not exist."
  echo "Run: kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns"
  exit 1
fi

# Check if session keys secret exists
if ! kubectl get secret session-keys -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "ERROR: Secret 'session-keys' does not exist."
  echo "Creating session keys secret..."
  
  export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
  export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
  
  kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
    --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
    --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
  
  echo "Session keys secret created successfully."
fi

# Check if database credentials secret exists
if ! kubectl get secret ${CP_DB_SECRET_NAME} -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "Creating database credentials secret..."
  
  kubectl create secret generic ${CP_DB_SECRET_NAME} \
    --from-literal=db_username=${CP_DB_USERNAME} \
    --from-literal=db_password=${CP_DB_PASSWORD} \
    -n ${CP_INSTANCE_ID}-ns
  
  echo "Database credentials secret created successfully."
fi

# Check if encryption secret exists
if ! kubectl get secret cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "Creating encryption secret..."
  
  kubectl create secret generic cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns \
    --from-literal=CP_ENCRYPTION_SECRET=$(openssl rand -base64 32)
  
  echo "Encryption secret created successfully."
fi

# Check if TLS secrets exist
if ! kubectl get secret ${CP_MY_TLS_SECRET_NAME} -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "WARNING: TLS secret ${CP_MY_TLS_SECRET_NAME} does not exist."
  echo "Please create it before proceeding with the installation."
  echo "Continuing in 10 seconds... Press Ctrl+C to cancel."
  sleep 10
fi

if ! kubectl get secret ${CP_TUNNEL_TLS_SECRET_NAME} -n ${CP_INSTANCE_ID}-ns &> /dev/null; then
  echo "WARNING: TLS secret ${CP_TUNNEL_TLS_SECRET_NAME} does not exist."
  echo "Please create it before proceeding with the installation."
  echo "Continuing in 10 seconds... Press Ctrl+C to cancel."
  sleep 10
fi

echo "Prerequisites check completed."

# ========================================
# HELM INSTALLATION
# ========================================
echo "Installing TIBCO Control Plane Base (tibco-cp-base)..."
echo "Chart version: ${CP_TIBCO_CP_BASE_VERSION}"
echo "Namespace: ${CP_INSTANCE_ID}-ns"

# Uncomment the following line if using helm repo with username and password
# --username ${TP_CHART_REPO_USER_NAME} --password ${TP_CHART_REPO_TOKEN} \

helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-base ${HELM_URL}/tibco-cp-base \
  --version "${CP_TIBCO_CP_BASE_VERSION}" -f - <<EOF
# ========================================
# GLOBAL CONFIGURATION
# ========================================
global:
  external:
    # Encryption configuration
    cpEncryptionSecretName: cporch-encryption-secret
    cpEncryptionSecretKey: CP_ENCRYPTION_SECRET
    
    # Cluster network information
    clusterInfo:
      nodeCIDR: ${TP_NODE_CIDR}
      podCIDR: ${TP_POD_CIDR}
      serviceCIDR: ${TP_SERVICE_CIDR}
    
    # DNS domains
    dnsDomain: ${CP_MY_DNS_DOMAIN}
    dnsTunnelDomain: ${CP_TUNNEL_DNS_DOMAIN}
    
    # Storage configuration
    storage:
      resources:
        requests:
          storage: ${CP_STORAGE_SIZE}
      storageClassName: ${TP_FILE_STORAGE_CLASS}
    
    # Database configuration
    db_host: ${CP_DB_HOST}
    db_name: ${CP_DB_NAME}
    db_password: ${CP_DB_PASSWORD}
    db_port: ${CP_DB_PORT}
    db_secret_name: ${CP_DB_SECRET_NAME}
    db_ssl_mode: ${CP_DB_SSL_MODE}
    db_username: ${CP_DB_USERNAME}
    
    # Email server configuration
    emailServerType: ${CP_EMAIL_SERVER_TYPE}
    emailServer:
      smtp:
        server: ${CP_EMAIL_SMTP_SERVER}
        port: ${CP_EMAIL_SMTP_PORT}
        username: ${CP_EMAIL_SMTP_USERNAME}
        password: ${CP_EMAIL_SMTP_PASSWORD}
    
    # Admin user configuration
    admin:
      email: ${CP_ADMIN_EMAIL}
      firstname: ${CP_ADMIN_FIRSTNAME}
      lastname: ${CP_ADMIN_LASTNAME}
      customerID: ${CP_ADMIN_CUSTOMER_ID}
  
  tibco:
    # Container registry configuration
    containerRegistry:
      url: ${TP_CONTAINER_REGISTRY_URL}
      username: ${TP_CONTAINER_REGISTRY_USER}
      password: ${TP_CONTAINER_REGISTRY_PASSWORD}
      repository: ${TP_CONTAINER_REGISTRY_REPOSITORY}
    
    # Control plane instance identifier
    controlPlaneInstanceId: ${CP_INSTANCE_ID}
    
    # Service account
    serviceAccount: ${CP_INSTANCE_ID}-sa
    
    # Logging configuration
    logging:
      fluentbit:
        enabled: false

# ========================================
# BOOTSTRAP COMPONENTS
# ========================================
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
  tscSessionKey:
    secretName: session-keys
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys
    key: DOMAIN_SESSION_KEY
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

# ========================================
# BASE COMPONENTS
# ========================================
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

# ========================================
# POST-INSTALLATION VERIFICATION
# ========================================
echo ""
echo "========================================="
echo "Installation completed!"
echo "========================================="
echo ""

echo "Verifying deployment..."
echo ""

# Check Helm release status
echo "Helm release status:"
helm list -n ${CP_INSTANCE_ID}-ns

echo ""
echo "Pod status:"
kubectl get pods -n ${CP_INSTANCE_ID}-ns

echo ""
echo "========================================="
echo "Next Steps:"
echo "========================================="
echo "1. Monitor pod status: kubectl get pods -n ${CP_INSTANCE_ID}-ns -w"
echo "2. Check logs: kubectl logs -n ${CP_INSTANCE_ID}-ns <pod-name>"
echo "3. Retrieve admin password (within 1 hour):"
echo "   kubectl logs -n ${CP_INSTANCE_ID}-ns \$(kubectl get jobs -n ${CP_INSTANCE_ID}-ns | grep tp-control-plane-ops-create-admin-user | awk '{print \$1}')"
echo "4. Access Control Plane UI: https://admin.${CP_MY_DNS_DOMAIN}"
echo ""
echo "========================================="
