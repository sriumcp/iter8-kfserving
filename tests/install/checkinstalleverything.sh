#!/bin/bash

# Test if iter8-kfserving can be installed properly

## Dependencies
## 1. docker
## 2. kustomize
## 3. minikube environment setup and running

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
docker image rm -f ${IMAGE_NAME}
DOCKER_BUILDKIT=1 docker build . --tag ${IMAGE_NAME} 

export ITER8_KFSERVING_ROOT=$PWD
./quickstart/install-everything.sh