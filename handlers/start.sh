#!/bin/bash
set -e

# Note: This is an idempotent handler. Executing it 'n' times successfully will produce the same result as executing it once successfully. This is a useful guarantee.

# Environment variables.
## RESOURCE_DIR: Directory used for storing intermediate objects. Used as scratch space.
## PATCH_DIR: Directory containing versionInfo patches for Experiment object.
## EXPERIMENT_NAME: Name of the Experiment object.
## EXPERIMENT_NAMESPACE: Namespace of the Experiment object.
## IGNORE_INFERENCESERVICE_READINESS: Boolean flag indicating if this script needs to wait for InferenceService object to be ready or not. Step 4 is skipped if this flag is set.

# Plan of action.
## Step 0: Set and mkdir RESOURCE_DIR. Set PATCH_DIR.
## Step 1: Get the Experiment object.
## Step 2: Get namespace and name for InferenceService object.
## Step 3: Ensure InferenceService object exists.
## Step 4: Ensure InferenceService object is ready.
## Step 5: Get the InferenceService object.
## Step 6: Patch the InferenceService object if needed. Create file used to patch the Experiment object.
## Step 7: Patch the experiment object.

# Step 0: Set and mkdir RESOURCE_DIR. Set PATCH_DIR.
if [[ -z ${RESOURCE_DIR+x} ]]; then
    RESOURCE_DIR="./resources"
fi
mkdir -p ${RESOURCE_DIR}
if [[ -z ${PATCH_DIR+x} ]]; then
    PATCH_DIR="./patches"
fi
echo "RESOURCE_DIR=${RESOURCE_DIR}"
echo "PATCH_DIR=${PATCH_DIR}"

# Step 1: Get the Experiment object.
echo "EXPERIMENT_NAME=${EXPERIMENT_NAME}"
echo "EXPERIMENT_NAMESPACE=${EXPERIMENT_NAMESPACE}"

if [[ -z ${EXPERIMENT_NAME+x} ]] || [[ -z ${EXPERIMENT_NAMESPACE+x} ]]; then 
    echo ""
    echo "EXPERIMENT_NAMESPACE and EXPERIMENT_NAME need to be set ..."
    exit 1
fi

kubectl get experiment ${EXPERIMENT_NAME} -n ${EXPERIMENT_NAMESPACE} -o yaml > ${RESOURCE_DIR}/experiment.yaml

# Step 2: Get namespace and name for InferenceService object.
INFERENCE_SERVICE_NN=$(yq r ${RESOURCE_DIR}/experiment.yaml spec.target)
INFERENCE_SERVICE_NAMESPACE=$(echo $INFERENCE_SERVICE_NN | cut -f1 -d/)
INFERENCE_SERVICE_NAME=$(echo $INFERENCE_SERVICE_NN | cut -f2 -d/)

if [[ -z ${INFERENCE_SERVICE_NAMESPACE+x} ]]; then
    echo "No namespace provided for InferenceService object. Defaulting it to the experiment namespace"
    INFERENCE_SERVICE_NAMESPACE=EXPERIMENT_NAMESPACE
fi

echo "INFERENCE_SERVICE_NAME=${INFERENCE_SERVICE_NAME}"
echo "INFERENCE_SERVICE_NAMESPACE=${INFERENCE_SERVICE_NAMESPACE}"

if [[ -z ${INFERENCE_SERVICE_NAME+x} ]] || [[ -z ${INFERENCE_SERVICE_NAMESPACE+x} ]]; then 
    echo "Experiment target needs to be in the form INFERENCE_SERVICE_NAMESPACE/INFERENCE_SERVICE_NAME ..."
    exit 1
fi

# Step 3: Ensure InferenceService object exists.
echo -n "Ensuring inference service exists. Will give up after 120 seconds ..."
n=0
until [ $n -ge 120 ]; do
    INFERENCE_SERVICE_EXISTS=$(kubectl get inferenceservice ${INFERENCE_SERVICE_NAME} -n ${INFERENCE_SERVICE_NAMESPACE} --ignore-not-found)
    if [[ ! -z ${INFERENCE_SERVICE_EXISTS} ]]; then
        echo ""
        echo "Found InferenceService object ..."
        break
    fi
    echo -n "."
    sleep 1
done

if [[ -z ${INFERENCE_SERVICE_EXISTS} ]]; then
    echo "InferenceService object does not exist"
    exit 1
fi

# Step 4: Ensure InferenceService object is ready.
if [[ -z ${IGNORE_INFERENCESERVICE_READINESS} ]]; then
    echo "Ensuring InferenceService object is ready. Will give up after 120 seconds ..."
    kubectl wait --for=condition=ready inferenceservice ${INFERENCE_SERVICE_NAME} -n ${INFERENCE_SERVICE_NAMESPACE} --timeout=120s
fi

# Step 5: Get the InferenceService object.
kubectl get inferenceservice ${INFERENCE_SERVICE_NAME} -n ${INFERENCE_SERVICE_NAMESPACE} -o yaml > ${RESOURCE_DIR}/inferenceservice.yaml
echo "kubectl got the InferenceService object ..."

# Step 6: Patch inference service if needed. Create file used to patch the experiment.
STRATEGY=$(yq r ${RESOURCE_DIR}/inferenceservice.yaml spec.strategy.type)
if [[ ${STRATEGY} == "performance" ]]; then
    # Step 6.a: this is a performance experiment.
    PATCH_FILE=${PATCH_DIR}/performancepatch.yaml
else
    # Step 6.b.i: Patch the InferenceService object with 0 traffic to canary.
    echo "Patching InferenceService object using command: kubectl patch inferenceservice sklearn-iris -n kfserving-test -p '{\"spec\": {\"canaryTrafficPercent\": 0}}' --type=merge ..."

    kubectl patch inferenceservice sklearn-iris -n kfserving-test -p '{"spec": {"canaryTrafficPercent": 0}}' --type=merge

    # Step 6.b.ii: Duplicate patch file. Insert InferenceService name and namespace into it.
    cp ${PATCH_DIR}/patchwithtwoversions.yaml ${RESOURCE_DIR}/patchwithtwoversions.yaml
    PATCH_FILE=${RESOURCE_DIR}/patchwithtwoversions.yaml
    yq w -i $PATCH_FILE spec.versionInfo.candidates[0].weightObjRef.name ${INFERENCE_SERVICE_NAME}
    yq w -i $PATCH_FILE spec.versionInfo.candidates[0].weightObjRef.namespace ${INFERENCE_SERVICE_NAMESPACE}
fi

# Step 7: Patch the experiment CR object using the appropriate patch file created in Step 4.
kubectl patch experiment $EXPERIMENT_NAME -n $EXPERIMENT_NAMESPACE --patch "$(cat $PATCH_FILE)" --type=merge