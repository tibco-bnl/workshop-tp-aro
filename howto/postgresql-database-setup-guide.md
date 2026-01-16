# PostgreSQL Database Setup and Management for TIBCO Platform

This guide provides instructions for setting up and managing PostgreSQL databases for TIBCO Platform Control Plane deployments on Azure Red Hat OpenShift (ARO) and other Kubernetes environments.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Database Setup Options](#database-setup-options)
- [Option 1: On-Premises PostgreSQL Deployment](#option-1-on-premises-postgresql-deployment)
- [Option 2: Azure Database for PostgreSQL (SaaS)](#option-2-azure-database-for-postgresql-saas)
- [Using TIBCO's PostgreSQL Management Script](#using-tibcos-postgresql-management-script)
- [Database Credentials and Secrets](#database-credentials-and-secrets)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Overview

TIBCO Platform Control Plane requires PostgreSQL databases for various services including:
- Identity Management (IDM)
- Identity Provider (defaultidp)
- Monitoring Database
- Policy Engine (pengine)
- TAS Data Server (tasdataserver)
- TAS Domain Server (tasdomainserver)
- TSC Orchestration (tscorch)
- TSC Scheduler (tscscheduler)
- TSC UTD

You have two primary options for PostgreSQL deployment:
1. **On-premises**: Deploy PostgreSQL directly on your Kubernetes cluster
2. **Azure SaaS**: Use Azure Database for PostgreSQL Flexible Server

## Prerequisites

### Software Requirements

- **PostgreSQL Version**: 14 or higher
- **PostgreSQL client tools** (`psql`)
- **kubectl** configured with access to your Kubernetes cluster
- **openssl** for password generation
- **Bash shell** environment

### PostgreSQL Server Requirements

The PostgreSQL master user must have privileges to:
- Create databases and users
- Grant privileges on databases
- Create schemas and extensions
- Install the `uuid-ossp` extension

### Kubernetes Requirements

- **Namespace**: The target Kubernetes namespace must already exist
- **RBAC Permissions**: If using `kubectl` to manage secrets directly, you need:
  - `secrets`: `get`, `create`, `update`, `delete`

**Example RBAC role:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: database-secret-manager
  namespace: <your-namespace>
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "create", "update", "delete"]
```

> [!NOTE]
> If you don't have `kubectl` access or RBAC permissions, use `NO_KUBECTL_ACCESS=true` mode to generate kubectl commands for your cluster administrator to execute.

## Database Setup Options

### Option 1: On-Premises PostgreSQL Deployment

Deploy PostgreSQL directly on your Kubernetes cluster using Bitnami Helm chart.

#### Step 1: Add Bitnami Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

#### Step 2: Create PostgreSQL Namespace

```bash
# Create namespace for external services
kubectl create namespace tibco-ext
```

#### Step 3: Install PostgreSQL

```bash
# Install PostgreSQL with basic configuration
helm install postgresql bitnami/postgresql \
  --namespace tibco-ext \
  --set auth.username=postgres \
  --set auth.password=postgres \
  --set auth.database=postgres \
  --set primary.persistence.enabled=true \
  --set primary.persistence.size=10Gi
```

#### Step 4: Verify PostgreSQL Installation

```bash
# Check PostgreSQL pod status
kubectl get pods -n tibco-ext

# Expected output should show postgresql-0 in Running state
# NAME           READY   STATUS    RESTARTS   AGE
# postgresql-0   1/1     Running   0          2m
```

#### Step 5: Set Environment Variables

```bash
export CP_DB_HOST="postgresql.tibco-ext.svc.cluster.local"
export CP_DB_PORT="5432"
export MASTER_PGUSER="postgres"
export MASTER_PGPASSWORD="postgres"
export CP_DB_SSL_MODE="disable"  # SSL disabled for on-cluster deployment
```

### Option 2: Azure Database for PostgreSQL (SaaS)

Use Azure's managed PostgreSQL service for better scalability, automated backups, and enterprise-grade security.

#### Prerequisites for Azure PostgreSQL

1. Azure Database for PostgreSQL Flexible Server instance created
2. Firewall rules configured to allow ARO cluster access
3. SSL/TLS certificate downloaded for secure connections

#### Step 1: Download Baltimore CyberTrust Root Certificate

Azure PostgreSQL requires SSL connections using the Baltimore CyberTrust Root certificate:

```bash
# Download the Baltimore CyberTrust Root certificate
curl -o BaltimoreCyberTrustRoot.crt.pem https://cacerts.digicert.com/BaltimoreCyberTrustRoot.crt.pem

# Verify the certificate was downloaded
ls -lh BaltimoreCyberTrustRoot.crt.pem
```

#### Step 2: Create Kubernetes Secret for SSL Certificate

Create a secret containing the SSL certificate that will be used by the Control Plane to connect to Azure PostgreSQL.

> [!IMPORTANT]
> The secret must use the **exact key name** `db_ssl_root.cert` (with a dot, not underscore). This is required by the TIBCO Platform.

```bash
# Create the SSL certificate secret with the exact key name required
kubectl create secret generic db-ssl-root-cert \
  --from-file=db_ssl_root.cert=BaltimoreCyberTrustRoot.crt.pem \
  -n ${CP_INSTANCE_ID}-ns

# Verify the secret was created
kubectl get secret db-ssl-root-cert -n ${CP_INSTANCE_ID}-ns

# Optional: Verify the secret structure (should show "db_ssl_root.cert" as the key)
kubectl get secret db-ssl-root-cert -n ${CP_INSTANCE_ID}-ns -o yaml
```

**Example Secret Structure:**
```yaml
apiVersion: v1
data:
  db_ssl_root.cert: <BASE64_ENCODED_CERTIFICATE>
kind: Secret
metadata:
  name: db-ssl-root-cert
  namespace: <CP_INSTANCE_ID>-ns
type: Opaque
```

#### Step 3: Update Environment Variables for Azure PostgreSQL

```bash
# Azure PostgreSQL connection details
export CP_DB_HOST="<your-postgres-server>.postgres.database.azure.com"
export CP_DB_NAME="postgres"
export CP_DB_USERNAME="<admin-user>@<server-name>"
export CP_DB_PASSWORD="<your-password>"
export CP_DB_PORT="5432"
export CP_DB_SECRET_NAME="provider-cp-database-credentials"

# SSL Configuration for Azure PostgreSQL
export CP_DB_SSL_MODE="require"  # Options: disable, require, verify-ca, verify-full
export CP_DB_SSL_ROOT_CERT_SECRET_NAME="db-ssl-root-cert"
export CP_DB_SSL_ROOT_CERT_FILENAME="db_ssl_root.cert"
```

**SSL Mode Options:**
- `disable`: No SSL (not recommended for production)
- `require`: SSL connection required but does not verify the certificate
- `verify-ca`: SSL connection with certificate verification (recommended)
- `verify-full`: SSL connection with full certificate and hostname verification (most secure)

#### Step 4: Test PostgreSQL Connection

Verify connectivity to Azure PostgreSQL before deploying the Control Plane:

```bash
# Install PostgreSQL client tools (if not already installed)
apk add postgresql-client  # For Alpine
# OR
apt-get install postgresql-client  # For Debian/Ubuntu

# Test connection to Azure PostgreSQL
PGSSLMODE=${CP_DB_SSL_MODE} psql "host=${CP_DB_HOST} port=${CP_DB_PORT} dbname=${CP_DB_NAME} user=${CP_DB_USERNAME} sslrootcert=BaltimoreCyberTrustRoot.crt.pem"

# If connection is successful, you'll see the PostgreSQL prompt
# Type \q to exit
```

## Using TIBCO's PostgreSQL Management Script

TIBCO provides a comprehensive PostgreSQL management script (`postgres-helper.bash`) for handling database operations including installation, upgrades, and deletion.

> [!IMPORTANT]
> This script is required when deploying `tibco-cp-base` chart with `global.tibco.manageDbSchema=false`.

### Official Documentation

For complete details, refer to the official TIBCO documentation:
- **Repository**: [TIBCOSoftware/tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- **Database Scripts**: [scripts/database/README.md](https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/scripts/database/README.md)

### Key Features

- **Database Installation**: Creates database schemas, users, and initial setup
- **Schema Upgrades**: Handles incremental database schema upgrades
- **Database Deletion**: Removes database schemas, users, and associated secrets
- **Credential Management**: Securely manages database credentials and Kubernetes secrets

### Environment Variables for postgres-helper.bash

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PGHOST` | PostgreSQL server hostname | `postgres.example.com` |
| `PGPORT` | PostgreSQL server port | `5432` |
| `MASTER_PGUSER` | PostgreSQL master user | `postgres` |
| `MASTER_PGPASSWORD` | PostgreSQL master user password | `your-master-password` |
| `POD_NAMESPACE` | Kubernetes namespace for secrets | `cp1-ns` |
| `DB_PREFIX` | Database prefix (controlPlaneInstanceId + underscore) | `cp1_` |

#### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NO_KUBECTL_ACCESS` | `false` | Generate kubectl commands instead of applying secrets |
| `ENVIRONMENT_TYPE` | unset | Set to `prod` for production environments |
| `SKIP_SERVICES` | unset | Space-separated list of services to skip |
| `DELETE_DB_ON_UNINSTALL` | unset | Set to `true` to enable database deletion |
| `PSQL_SCRIPTS_LOCATION` | `$(pwd)/postgres/tibco-cp-base` | Path to SQL scripts directory |

### Usage Examples

#### Example 1: Initial Database Setup

```bash
# Set required environment variables
export PGHOST="${CP_DB_HOST}"
export PGPORT="${CP_DB_PORT}"
export MASTER_PGUSER="${MASTER_PGUSER}"
export MASTER_PGPASSWORD="${MASTER_PGPASSWORD}"
export POD_NAMESPACE="${CP_INSTANCE_ID}-ns"
export DB_PREFIX="${CP_INSTANCE_ID}_"

# Download the postgres-helper script
curl -LO https://raw.githubusercontent.com/TIBCOSoftware/tp-helm-charts/main/scripts/database/postgres-helper.bash
chmod +x postgres-helper.bash

# Clone the repository to get SQL scripts
git clone https://github.com/TIBCOSoftware/tp-helm-charts.git
cd tp-helm-charts/scripts/database

# Run upgrade to create databases and users
./postgres-helper.bash upgrade
```

#### Example 2: Without Kubernetes Access

If you don't have `kubectl` access, generate commands for your cluster administrator:

```bash
export NO_KUBECTL_ACCESS="true"
export PGHOST="${CP_DB_HOST}"
export PGPORT="${CP_DB_PORT}"
export MASTER_PGUSER="${MASTER_PGUSER}"
export MASTER_PGPASSWORD="${MASTER_PGPASSWORD}"
export POD_NAMESPACE="${CP_INSTANCE_ID}-ns"
export DB_PREFIX="${CP_INSTANCE_ID}_"

./postgres-helper.bash upgrade

# The script generates kubectl-create-secret-commands.sh
# Share this file with your cluster administrator to execute
```

#### Example 3: Database Cleanup After Uninstall

```bash
# 1) First, uninstall the Helm chart
helm uninstall tibco-cp-base -n ${CP_INSTANCE_ID}-ns

# 2) Wait for all pods to terminate completely

# 3) Run delete command
export DELETE_DB_ON_UNINSTALL="true"
export PGHOST="${CP_DB_HOST}"
export PGPORT="${CP_DB_PORT}"
export MASTER_PGUSER="${MASTER_PGUSER}"
export MASTER_PGPASSWORD="${MASTER_PGPASSWORD}"
export POD_NAMESPACE="${CP_INSTANCE_ID}-ns"
export DB_PREFIX="${CP_INSTANCE_ID}_"

./postgres-helper.bash delete
```

### Important Workflow Requirements

> [!IMPORTANT]
> Critical workflow requirements:
> 
> - **Before Chart Install/Upgrade**: Always run `upgrade` command first to ensure database schemas are ready
> - **After Chart Uninstall**: Only run `delete` command after the chart is completely uninstalled
> - **Do Not Interrupt**: Allow the script to complete fully to avoid inconsistent database states
> - **Password Management**: Random passwords are generated only when creating new users

### Available Database Services

The script manages the following services for `tibco-cp-base`:
- `defaultidp` - Default Identity Provider
- `idm` - Identity Management
- `monitoringdb` - Monitoring Database
- `pengine` - Policy Engine
- `tasdataserver` - TAS Data Server
- `tasdomainserver` - TAS Domain Server
- `tscorch` - TSC Orchestration
- `tscscheduler` - TSC Scheduler
- `tscutd` - TSC UTD

To skip specific services:
```bash
export SKIP_SERVICES="idm tscorch"
./postgres-helper.bash upgrade
```

## Database Credentials and Secrets

### Creating Database Credentials Secret

After setting up the database (either on-premises or Azure SaaS), create the Kubernetes secret for database credentials:

```bash
# Create database credentials secret
kubectl create secret generic ${CP_DB_SECRET_NAME} \
    --from-literal=db_username=${CP_DB_USERNAME} \
    --from-literal=db_password=${CP_DB_PASSWORD} \
    -n ${CP_INSTANCE_ID}-ns

# Verify the secret was created
kubectl get secret ${CP_DB_SECRET_NAME} -n ${CP_INSTANCE_ID}-ns
```

### Configure Control Plane Values for Database

When deploying the Control Plane, ensure your values file includes the database configuration:

**For On-Premises PostgreSQL:**
```yaml
global:
  external:
    db_host: "postgresql.tibco-ext.svc.cluster.local"
    db_port: "5432"
    db_name: "postgres"
    db_secret_name: "provider-cp-database-credentials"
    db_ssl_mode: "disable"
```

**For Azure PostgreSQL with SSL:**
```yaml
global:
  external:
    db_host: "<your-server>.postgres.database.azure.com"
    db_port: "5432"
    db_name: "postgres"
    db_secret_name: "provider-cp-database-credentials"
    db_ssl_mode: "require"  # or "verify-ca" or "verify-full"

tp-cp-core:
  identityProvider:
    enabled: true
    tibco:
      db_ssl_root_cert_secretname: "db-ssl-root-cert"
      db_ssl_root_cert_filename: "db_ssl_root.cert"
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failures

**Symptoms**: Cannot connect to PostgreSQL server

**Solutions**:
- Verify `PGHOST` and `PGPORT` settings
- Check network connectivity to PostgreSQL
- Ensure `MASTER_PGUSER` and `MASTER_PGPASSWORD` are correct
- For Azure PostgreSQL, verify firewall rules allow your cluster's egress IP

#### 2. Permission Errors

**Symptoms**: Permission denied errors when creating databases or users

**Solutions**:
- Verify Kubernetes RBAC permissions for secret management
- Check PostgreSQL user permissions (master user must have CREATE DATABASE privileges)
- For no kubectl access, use `NO_KUBECTL_ACCESS=true`

#### 3. SSL Certificate Issues (Azure PostgreSQL)

**Symptoms**: SSL connection errors or certificate validation failures

**Solutions**:
- Verify the certificate was downloaded correctly
- Ensure the secret key name is exactly `db_ssl_root.cert` (with dot)
- Check SSL mode setting matches your security requirements
- Test connection manually with `psql` using SSL parameters

#### 4. Delete Fails with "database is being accessed by other users"

**Symptoms**: `ERROR: database <db_name> is being accessed by other users`

**Solutions**:
- Ensure the `tibco-cp-base` chart is fully uninstalled
- Verify no pods are still running and accessing the databases
- Wait for all pods to terminate completely after helm uninstall
- Check for hanging connections: `SELECT * FROM pg_stat_activity WHERE datname = '<database_name>';`

#### 5. Script Location Errors

**Symptoms**: Cannot find SQL scripts or metadata files

**Solutions**:
- Verify `PSQL_SCRIPTS_LOCATION` points to correct directory
- Default: `$(pwd)/postgres/tibco-cp-base`
- Ensure you have cloned the tp-helm-charts repository
- Check file permissions and accessibility

### Verification Commands

```bash
# Check PostgreSQL connectivity
psql -h ${PGHOST} -p ${PGPORT} -U ${MASTER_PGUSER} -d postgres -c "SELECT version();"

# List all databases
psql -h ${PGHOST} -p ${PGPORT} -U ${MASTER_PGUSER} -d postgres -c "\l"

# Check database users
psql -h ${PGHOST} -p ${PGPORT} -U ${MASTER_PGUSER} -d postgres -c "\du"

# Verify Kubernetes secrets
kubectl get secrets -n ${CP_INSTANCE_ID}-ns | grep -E "database|ssl"

# Check secret content (base64 encoded)
kubectl get secret ${CP_DB_SECRET_NAME} -n ${CP_INSTANCE_ID}-ns -o yaml
```

## References

### Official TIBCO Documentation
- **TIBCO tp-helm-charts Repository**: [https://github.com/TIBCOSoftware/tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- **PostgreSQL Management Script Documentation**: [https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/scripts/database/README.md](https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/scripts/database/README.md)

### Azure Documentation
- **Azure Database for PostgreSQL**: [https://learn.microsoft.com/en-us/azure/postgresql/](https://learn.microsoft.com/en-us/azure/postgresql/)
- **Configure SSL on PostgreSQL Client**: [https://learn.microsoft.com/en-us/azure/postgresql/security/security-tls#configure-ssl-on-the-client](https://learn.microsoft.com/en-us/azure/postgresql/security/security-tls#configure-ssl-on-the-client)
- **Azure PostgreSQL SSL Connectivity**: [https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl)

### PostgreSQL Documentation
- **PostgreSQL Official Documentation**: [https://www.postgresql.org/docs/](https://www.postgresql.org/docs/)
- **psql Command Reference**: [https://www.postgresql.org/docs/current/app-psql.html](https://www.postgresql.org/docs/current/app-psql.html)

### Helm Charts
- **Bitnami PostgreSQL Chart**: [https://github.com/bitnami/charts/tree/main/bitnami/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
