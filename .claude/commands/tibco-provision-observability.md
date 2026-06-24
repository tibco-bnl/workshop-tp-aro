You are helping deploy the TIBCO Platform observability stack on Azure Red Hat OpenShift (ARO). This deploys Elasticsearch/Kibana (via ECK operator) and Prometheus/Grafana (via kube-prometheus-stack) into the Data Plane namespace for logs, metrics, and traces.

## Before You Start

Verify Control Plane and Data Plane are deployed:
```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns
kubectl get pods -n ${DP_INSTANCE_ID}-ns
```

Confirm environment values:
```bash
echo "DP_INSTANCE_ID=${DP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
```

## Step 1 — Create Observability Namespaces

```bash
for ns in elastic-system prometheus-system; do
  oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
EOF
done
```

Grant `tp-scc` to observability namespaces (required for ECK and Prometheus on ARO):

```bash
for ns in elastic-system prometheus-system; do
  oc adm policy add-scc-to-user tp-scc system:serviceaccount:${ns}:default
  oc adm policy add-scc-to-user anyuid system:serviceaccount:${ns}:default
done
```

## Step 2 — ECK Operator

The Elastic Cloud on Kubernetes (ECK) operator manages Elasticsearch and Kibana.

Add the Elastic Helm repo:
```bash
helm repo add elastic https://helm.elastic.co
helm repo update
```

Install ECK operator:
```bash
helm upgrade --install --wait --timeout 10m \
  --create-namespace -n elastic-system eck-operator elastic/eck-operator \
  --set managedNamespaces="{${DP_INSTANCE_ID}-ns}" \
  --set installCRDs=true
```

Verify the operator is running:
```bash
kubectl get pods -n elastic-system
kubectl get crd | grep elastic
```

## Step 3 — Grant ECK Service Account SCC

After ECK operator installs, grant SCC to its service accounts:
```bash
oc adm policy add-scc-to-user tp-scc system:serviceaccount:elastic-system:elastic-operator
oc adm policy add-scc-to-user anyuid system:serviceaccount:elastic-system:elastic-operator
```

## Step 4 — dp-config-es (Elasticsearch + Kibana)

Install the TIBCO Data Plane Elasticsearch configuration chart:

```bash
helm upgrade --install --wait --timeout 30m \
  --create-namespace -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-config-es tibco-platform-public/dp-config-es \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials" \
  --set "dp-config-es.elasticsearch.enabled=true" \
  --set "dp-config-es.kibana.enabled=true" \
  --set "dp-config-es.elasticsearch.storageClass=azure-file" \
  --set "dp-config-es.elasticsearch.storage=20Gi" \
  --set "dp-config-es.ingress.className=openshift-default"
```

Monitor Elasticsearch cluster startup (takes 3-5 minutes):
```bash
kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns
kubectl get kibana -n ${DP_INSTANCE_ID}-ns
kubectl get pods -n ${DP_INSTANCE_ID}-ns -l common.k8s.elastic.co/type=elasticsearch -w
```

Elasticsearch is ready when `HEALTH=green` and `PHASE=Ready`:
```bash
kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns
```

## Step 5 — Grant SCC to Elasticsearch Pods

Elasticsearch pods run as a specific UID. Grant SCC after the Elasticsearch pods start:

```bash
# Get the elasticsearch service account name
ES_SA=$(kubectl get serviceaccount -n ${DP_INSTANCE_ID}-ns | grep elastic | awk '{print $1}' | head -1)
echo "Elasticsearch SA: ${ES_SA}"

oc adm policy add-scc-to-user tp-scc system:serviceaccount:${DP_INSTANCE_ID}-ns:${ES_SA}
oc adm policy add-scc-to-user anyuid system:serviceaccount:${DP_INSTANCE_ID}-ns:${ES_SA}
```

If pods are still pending after SCC grant, restart them:
```bash
kubectl delete pods -n ${DP_INSTANCE_ID}-ns -l common.k8s.elastic.co/type=elasticsearch
```

## Step 6 — kube-prometheus-stack (Prometheus + Grafana)

Add Prometheus community Helm repo:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Install the kube-prometheus-stack:
```bash
helm upgrade --install --wait --timeout 30m \
  --create-namespace -n prometheus-system kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --set "alertmanager.enabled=true" \
  --set "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=azure-file" \
  --set "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi" \
  --set "grafana.persistence.enabled=true" \
  --set "grafana.persistence.storageClassName=azure-file" \
  --set "grafana.persistence.size=5Gi" \
  --set "grafana.ingress.enabled=true" \
  --set "grafana.ingress.ingressClassName=openshift-default" \
  --set "grafana.ingress.hosts[0]=grafana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}" \
  --set "prometheus.ingress.enabled=true" \
  --set "prometheus.ingress.ingressClassName=openshift-default" \
  --set "prometheus.ingress.hosts[0]=prometheus.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}"
```

Grant SCC to Prometheus service accounts:
```bash
for sa in kube-prometheus-stack-prometheus kube-prometheus-stack-alertmanager kube-prometheus-stack-grafana; do
  oc adm policy add-scc-to-user tp-scc system:serviceaccount:prometheus-system:${sa} 2>/dev/null || true
  oc adm policy add-scc-to-user anyuid system:serviceaccount:prometheus-system:${sa} 2>/dev/null || true
done
```

## Step 7 — Configure Prometheus ServiceMonitor for DP

Create a ServiceMonitor to scrape TIBCO Data Plane metrics:

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tibco-dp-metrics
  namespace: ${DP_INSTANCE_ID}-ns
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - ${DP_INSTANCE_ID}-ns
  selector:
    matchLabels:
      platform.tibco.com/dataplane-id: ${DP_INSTANCE_ID}
  endpoints:
    - port: metrics
      interval: 30s
EOF
```

## Step 8 — Verify Observability Stack

Check all components are running:

```bash
echo "=== Elasticsearch ===" && kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns
echo "=== Kibana ===" && kubectl get kibana -n ${DP_INSTANCE_ID}-ns
echo "=== Prometheus pods ===" && kubectl get pods -n prometheus-system -l app=prometheus
echo "=== Grafana pods ===" && kubectl get pods -n prometheus-system -l app.kubernetes.io/name=grafana
echo "=== ECK operator ===" && kubectl get pods -n elastic-system
```

Get OpenShift routes:
```bash
oc get routes -n ${DP_INSTANCE_ID}-ns | grep -E "kibana|elastic"
oc get routes -n prometheus-system | grep -E "grafana|prometheus"
```

## Step 9 — Access Dashboards

| Service | URL |
|---------|-----|
| Kibana | `https://kibana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |
| Grafana | `https://grafana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |
| Prometheus | `https://prometheus.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |

Get Grafana admin password:
```bash
kubectl get secret -n prometheus-system kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

Get Elasticsearch password:
```bash
kubectl get secret -n ${DP_INSTANCE_ID}-ns \
  $(kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns -o name | head -1 | sed 's|.*/||')-es-elastic-user \
  -o jsonpath='{.data.elastic}' | base64 -d && echo
```

## Step 10 — Register Observability in Control Plane

In the TIBCO Platform Admin UI:

1. Navigate to **Data Planes** → select your Data Plane → **Observability**
2. Add Elasticsearch endpoint:
   - URL: `https://elasticsearch.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}:9200`
   - Username: `elastic`
   - Password: (from Step 9)
3. Add Prometheus endpoint:
   - URL: `http://kube-prometheus-stack-prometheus.prometheus-system:9090`

## Troubleshooting

If ECK pods fail with `runAsNonRoot` errors:
```bash
oc adm policy add-scc-to-user anyuid system:serviceaccount:${DP_INSTANCE_ID}-ns:${ES_SA}
kubectl delete pod -n ${DP_INSTANCE_ID}-ns -l common.k8s.elastic.co/type=elasticsearch
```

If Prometheus pods fail to start, check for SCC issues:
```bash
oc get events -n prometheus-system --field-selector reason=Failed | grep -i scc
```

See `howto/troubleshooting.md` for ARO-specific issues.
