#!/bin/bash

# Test start handler in k8s environment with kustomize

## Dependencies
## 1. docker
## 2. kubectl with cluster access
## 3. kustomize
## 4. yq (if yq is unavailable, snap needs to be available to install yq)

# Exit on error
set -e

# tests is relative to iter8-kfserving root dir
export PATH=tests/install:tests/integration:$PATH
source createnamespace.sh

echo "Checking image name"
if [[ -z ${IMAGE_NAME} ]]; then 
    echo "IMAGE_NAME is not set"
    exit 1
fi

echo "Applying CRDs"
kubectl apply -k https://github.com/iter8-tools/etc3/config/crd/?ref=main
kubectl apply -k github.com/kubeflow/kfserving//config/crd/?ref=v0.4.1
kubectl wait --for=condition=Established crds --all --timeout=5m

echo "Creating Experiment and InferenceService objects"
create_namespace kfserving-test
kubectl apply -f tests/integration/data/sklearn-iris.yaml -n kfserving-test
kubectl apply -f tests/integration/data/example1.yaml -n kfserving-test
create_namespace iter8-system

echo "Installing RBACs"
kustomize build tests/rbacs | kubectl apply -f -

# If yq is not installed, install it -- works on ubuntu / linux distros with snapd
echo "Ensuring yq is installed"
if ! command -v yq &> /dev/null
then
    echo "yq could not be found"
    sudo snap install yq
fi

echo "Setting up SCRATCH_DIR"
SCRATCH_DIR=$(mktemp -d)

echo "Fixing and launching start handler"    
cp install/iter8-controller/configmaps/handlers/start.yaml ${SCRATCH_DIR}/
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].image ${IMAGE_NAME}
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].imagePullPolicy Never
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].env[0].value kfserving-test
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].env[1].value sklearn-iris-experiment-1
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].env[2].name IGNORE_INFERENCESERVICE_READINESS
yq w -i ${SCRATCH_DIR}/start.yaml spec.template.spec.containers[0].env[2].value ignore

echo "Fixed start handler"
cat ${SCRATCH_DIR}/start.yaml

echo "Creating start handler job ... "
kubectl apply -f ${SCRATCH_DIR}/start.yaml -n iter8-system
kubectl wait --for=condition=complete job/start -n iter8-system --timeout=30s

echo "Start handler job completed ... "

echo "Checking InferenceService and Experiment objects"
echo "InferenceService object"
kubectl get inferenceservice/sklearn-iris -n kfserving-test
echo "Experiment object :: version info"
VERSION_INFO=$(kubectl get experiment/sklearn-iris-experiment-1 -n kfserving-test -o yaml | yq r - spec.versionInfo)

if [[ -z ${VERSION_INFO} ]]; then
    echo "No version info found after start handler finished"
    exit 1
fi

echo "Experiment object patched with version info"
