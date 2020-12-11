#!/bin/bash

# Test finish handler in k8s environment

## This script is intended to be invoked immediately after teststarthandler.sh and cleanupstart.sh have finished running successfully.

## Dependencies
## 1. kubectl with cluster access
## 2. kustomize
## 3. yq (if yq is unavailable, snap needs to be available to install yq)

# Exit on error
set -e

echo "Creating Experiment and InferenceService objects"
kubectl apply -f tests/integration/data/sklearn-iris-before-finish.yaml -n kfserving-test
kubectl apply -f tests/integration/data/example1-before-finish.yaml -n kfserving-test

echo "Updating Experiment object status"
kubectl proxy --port=8080 &
PID=$!
sleep 2
curl --header "Content-Type: application/json-patch+json" --request PATCH http://127.0.0.1:8080/apis/iter8.tools/v2alpha1/namespaces/kfserving-test/experiments/sklearn-iris-experiment-1/status --data '[ { "op": "add", "path": "/status", "value": {"recommendedBaseline": "canary"} }]'
kill -9 $PID

echo "Checking image name"
if [[ -z ${IMAGE_NAME} ]]; then 
    echo "IMAGE_NAME is not set"
    exit 1
fi

echo "Setting up SCRATCH_DIR"
SCRATCH_DIR="./resources"
mkdir -p ${SCRATCH_DIR}

echo "Fixing finish handler"    
cp install/iter8-controller/configmaps/handlers/finish.yaml ${SCRATCH_DIR}/finish.yaml
yq w -i ${SCRATCH_DIR}/finish.yaml spec.template.spec.containers[0].image ${IMAGE_NAME}
yq w -i ${SCRATCH_DIR}/finish.yaml spec.template.spec.containers[0].imagePullPolicy Never
yq w -i ${SCRATCH_DIR}/finish.yaml spec.template.spec.containers[0].env[0].value kfserving-test
yq w -i ${SCRATCH_DIR}/finish.yaml spec.template.spec.containers[0].env[1].value sklearn-iris-experiment-1

echo "Fixed finish handler"
cat ${SCRATCH_DIR}/finish.yaml

echo "Launching finish handler job ... "
kubectl apply -f ${SCRATCH_DIR}/finish.yaml -n iter8-system
kubectl wait --for=condition=complete job/finish -n iter8-system --timeout=30s

echo "Finish handler job completed ... "

echo "Checking - InferenceService object :: default model"
DEFAULT_MODEL=$(kubectl get inferenceservice/sklearn-iris -n kfserving-test -o yaml | yq r - spec.default.predictor.tensorflow.storageUri)

if [[ ${DEFAULT_MODEL} =~ "flowers-2" ]]; then
    echo "Old canary version is now the new default. All ok."
else
    echo "New default version does not equal old canary."
    exit 1
fi