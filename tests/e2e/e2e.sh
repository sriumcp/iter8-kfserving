#!/bin/bash

set -e

## For this test to succeed, do the following before launching the test.
# minikube start --cpus 6 --memory 12288 --kubernetes-version=v1.17.11 --driver=docker
# curl -L https://raw.githubusercontent.com/iter8-tools/iter8-kfserving/main/samples/quickstart/platformsetup.sh | /bin/bash
# minikube tunnel --cleanup # and provide password when prompted

## Ensure Kubernetes cluster is available.
KUBERNETES_STATUS=$(kubectl version | awk '/^Server Version:/' -)
if [[ -z ${KUBERNETES_STATUS} ]]; then
    echo "Kubernetes cluster is unavailable"
    exit 1
else
    echo "Kubernetes cluster is available"
fi

## Ensure Kustomize v3 is available
KUSTOMIZE_VERSION=$(kustomize version | cut -f 1 | cut -d/ -f 2 | cut -d. -f 1)
if [[ $KUSTOMIZE_VERSION == "v3" ]]; then
    echo "Kustomize v3 is available"
else
    echo "Kustomize v3 is not available"
    echo "Get Kustomize v3 from https://kubectl.docs.kubernetes.io/installation/kustomize/"
    exit 1
fi

## Ensure fortio is available.
FORTIO_VERSION=$(fortio version)
if [[ -z ${FORTIO_VERSION} ]]; then
    echo "fortio is unavailable"
    exit 1
else
    echo "fortio is available"
fi

# Verify your installation
# kfserving, iter8-kfserving and kfserving-monitoring need to be available
echo "verifying installation of kfserving, iter8-kfserving, and kfserving-monitoring..."
kubectl wait --for condition=ready --timeout=300s pods --all -n kfserving-system
kubectl wait --for condition=ready --timeout=300s pods --all -n iter8-system
kubectl wait --for condition=ready --timeout=300s pods --all -n kfserving-monitoring
echo "installation is verified and ready"

# Remove all isvc in default namespace
kubectl delete isvc --all
echo "deleted all isvc from default namespace"

# Create a KFServing inferenceservice with a default model. Update it with a canary model. This step may take a couple of minutes.
echo "creating isvc with default and canary models... may take a couple of minutes"
curl -L https://raw.githubusercontent.com/iter8-tools/iter8-kfserving/main/samples/quickstart/inferenceservicesetup.sh | /bin/bash
echo "created isvc with default and canary models"

# WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
cd ${TEMP_DIR}
echo "pwd: " $(pwd)

# Create the input file for prediction requests in ${TEMP_DIR}
curl https://raw.githubusercontent.com/iter8-tools/iter8-kfserving/main/samples/quickstart/input.json -o input.json

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export MODEL_NAME=my-model
export SERVICE_HOSTNAME=$(kubectl get isvc ${MODEL_NAME} -o jsonpath='{.status.url}' | cut -d "/" -f 3)

# Generate prediction requests (2.5 per sec over 4 minutes)
# `Ctrl-c` will stop this fortio command... DO NOT `Ctrl-c` before the experiment completes.
fortio load -qps 2.5 -t 4m -H Host:${SERVICE_HOSTNAME} -payload-file input.json -json fortiooutput.json http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/${MODEL_NAME}:predict &
echo "launched fortio in the background"

# Create iter8-kfserving canary experiment
kubectl apply -f https://raw.githubusercontent.com/iter8-tools/iter8-kfserving/main/samples/quickstart/experiment.yaml
echo "created experiment"

# Giving the experiment four minutes to complete
echo "sleeping 300 seconds"
sleep 300
echo "awake"

kubectl get experiment experiment-1 -o json > experiment.json
echo "output experiment.json"

kubectl get isvc my-model -o json > isvc.json
echo "output isvc.json"

REQUESTSTOTAL=$(jq .DurationHistogram.Count fortiooutput.json)
REQUESTS200=$(jq '.RetCodes."200"' fortiooutput.json)
echo "Total requests: " ${REQUESTSTOTAL}
echo "Successful requests: " ${REQUESTS200}

RECOMMENDEDBASELINE=$(jq .status.recommendedBaseline experiment.json)
echo "Recommended baseline: " ${RECOMMENDEDBASELINE}

CANARYTRAFFICPERCENT=$(jq .spec.predictor.canaryTrafficPercent isvc.json)
echo "Canary traffic percent: " ${CANARYTRAFFICPERCENT}
