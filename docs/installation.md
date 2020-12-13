## Installation
Follow this guide to install iter8-kfserving on Kubernetes using [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/).

### Prerequisites
1. Kubernetes 1.15+
2. [KFServing](https://github.com/kubeflow/kfserving) installed on your Kubernetes cluster

### Install KNative-Monitoring
This step enables metrics collection. However, due to deprecation of KNative-Monitoring, this step will be replaced in the near future.
```
kubectl create ns knative-monitoring
kubectl apply -f https://github.com/knative/serving/releases/download/v0.18.0/monitoring-metrics-prometheus.yaml
```

### Install iter8-kfserving using Kustomize
```
 kustomize build github.com/iter8-tools/iter8-kfserving/install?ref=main | kubectl apply -f -
 kubectl wait --for condition=established --timeout=120s crd/metrics.iter8.tools
 kustomize build github.com/iter8-tools/iter8-kfserving/install/metrics?ref=main | kubectl apply -f
```