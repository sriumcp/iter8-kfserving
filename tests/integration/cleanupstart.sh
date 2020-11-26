#!/bin/bash

# Clean up afer testing start handler

kubectl delete crds --all
kubectl delete ns iter8-system
kubectl delete ns kfserving-test