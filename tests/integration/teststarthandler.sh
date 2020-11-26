#!/bin/bash

# Test start handler in minikube environment

# Exit on error
set -e

# Ensure minikube can access local docker image
echo "Ensuring minikube can access local docker image"
eval $(minikube docker-env)

echo "Building image"
# Setting image name
if [[ -z ${IMAGE_NAME} ]]; then 
    IMAGE_NAME="handlers"
fi
DOCKER_BUILDKIT=1 docker build . --tag ${IMAGE_NAME}

echo "Applying CRDs"
kubectl apply -k https://github.com/iter8-tools/etc3/config/crd/?ref=main
# super ugly and needs to be replaced
kubectl apply -f tests/integration/inferenceservicecrd.yaml
kubectl wait --for=condition=Established crds --all --timeout=5m

echo "Creating Experiment and InferenceService objects"
kubectl create ns kfserving-test
kubectl apply -f samples/common/sklearn-iris.yaml -n kfserving-test
kubectl apply -f samples/experiments/example1.yaml -n kfserving-test
kubectl create ns iter8-system
kustomize build tests/rbacs | kubectl apply -f -

# If yq is not installed, install it -- works on ubuntu / linux distros with snapd
echo "Ensuring yq is installed"
if ! command -v yq &> /dev/null
then
    echo "yq could not be found"
    sudo snap install yq
fi

echo "Fixing and launching start handler"       
cp resources/configmaps/handlers/start.yaml tests/integration/handlers/start.yaml
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].image ${IMAGE_NAME}
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].imagePullPolicy Never
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].env[0].value kfserving-test
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].env[1].value sklearn-iris-experiment-1
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].env[2].name IGNORE_INFERENCESERVICE_READINESS
yq w -i tests/integration/handlers/start.yaml spec.template.spec.containers[0].env[2].value ignore

echo "Fixed start handler"
cat tests/integration/handlers/start.yaml

echo "Creating start handler job ... "
kubectl apply -f tests/integration/handlers/start.yaml -n iter8-system
kubectl wait --for=condition=complete job/start -n iter8-system --timeout=30s

echo "Checking InferenceService and Experiment objects"
echo "InferenceService object"
kubectl get inferenceservice/sklearn-iris -n kfserving-test
echo "Experiment object"
VERSION_INFO=$(kubectl get experiment/sklearn-iris-experiment-1 -n kfserving-test -o yaml | yq r - spec.versionInfo)

if [[ -z ${VERSION_INFO} ]]; then
    echo "No version information found after start handler finished"
    exit 1
fi

echo "Experiment object patched with version information"
