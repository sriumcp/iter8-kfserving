#!/bin/bash

# Clean up after testing finish handler
kubectl delete -f tests/integration/data/sklearn-iris-before-finish.yaml -n kfserving-test
kubectl delete -f tests/integration/data/example1-before-finish.yaml -n kfserving-test
kubectl delete jobs --all -n iter8-system
