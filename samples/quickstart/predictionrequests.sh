#!/bin/bash

set -e

# Sending prediction requests for model versions in quickstart and e2e tests

## Ensure fortio is available.
FORTIO_VERSION=$(fortio version)
if [[ -z ${FORTIO_VERSION} ]]; then
    echo "fortio is unavailable"
    exit 1
else
    echo "fortio is available"
fi

# WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
cd ${TEMP_DIR}

# Create the input file for prediction requests in ${TEMP_DIR}
curl https://raw.githubusercontent.com/iter8-tools/iter8-kfserving/main/samples/quickstart/input.json -o input.json


export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

export MODEL_NAME=my-model

export SERVICE_HOSTNAME=$(kubectl get isvc ${MODEL_NAME} -o jsonpath='{.status.url}' | cut -d "/" -f 3)

# Generate prediction requests (2.5 per sec over 10 minutes)
# `Ctrl-c` will stop this fortio command... DO NOT `Ctrl-c` before the experiment completes.
fortio load -qps 2.5 -t 10m -H Host:${SERVICE_HOSTNAME} -payload-file input.json http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/${MODEL_NAME}:predict
