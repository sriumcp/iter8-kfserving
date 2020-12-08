#!/bin/bash

# Check if installation file is correct

kustomize build install/ > tests/scratch/build.yaml

if cmp tests/scratch/build.yaml install/iter8-kfserving.yaml; then
    echo 'install/iter8-kfserving is the latest yaml install file.'
    rm tests/scratch/build.yaml
else
    echo 'install/iter8-kfserving does not appear to be the latest yaml install file.'
    diff tests/scratch/build.yaml install/iter8-kfserving.yaml
    rm tests/scratch/build.yaml
    exit 1
fi