#!/bin/bash

# Test start handler in k8s environment with kustomize

## Dependencies
## 1. docker
## 2. kubectl with cluster access
## 3. kustomize
## 4. yq (if yq is unavailable, snap needs to be available to install yq)

# Exit on error
set -e

# Check namespace exists before creating
## Inspiration: https://www.krenger.ch/blog/kubernetes-bash-function-to-change-namespace/
function create_namespace() {
  ns=$1
  set +e
  # verify namespace ${ns} does not exist -- ignore errors
  getns=$(kubectl get namespace ${ns} 2>/dev/null)
  set -e
  if [[ -z ${getns} ]]; then
    echo "Namespace ${ns} does not exist ... creating"
    kubectl create ns ${ns}
  else
    echo "Namespace ${ns} already exists ... skipping creation"
  fi
}

# Ensure minikube can access local docker image
echo "Ensuring minikube can access local docker image"
eval $(minikube docker-env)

echo "Building image"
# Setting image name
if [[ -z ${IMAGE_NAME} ]]; then 
    IMAGE_NAME="handlers"
fi
docker image rm -f ${IMAGE_NAME}
DOCKER_BUILDKIT=1 docker build --no-cache . --tag ${IMAGE_NAME} 

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

echo "Fixing and launching start handler"    
cp install/iter8-controller/configmaps/handlers/start.yaml tests/scratch/start.yaml
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].image ${IMAGE_NAME}
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].imagePullPolicy Never
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].env[0].value kfserving-test
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].env[1].value sklearn-iris-experiment-1
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].env[2].name IGNORE_INFERENCESERVICE_READINESS
yq w -i tests/scratch/start.yaml spec.template.spec.containers[0].env[2].value ignore

echo "Fixed start handler"
cat tests/scratch/start.yaml

echo "Creating start handler job ... "
kubectl apply -f tests/scratch/start.yaml -n iter8-system
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
