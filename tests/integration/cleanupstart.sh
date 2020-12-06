#!/bin/bash

# Clean up after testing start handler
kubectl delete -f tests/integration/data/sklearn-iris.yaml -n kfserving-test
kubectl delete -f tests/integration/data/example1.yaml -n kfserving-test
kubectl delete jobs --all -n iter8-system
