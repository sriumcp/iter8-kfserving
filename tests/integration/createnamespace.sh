#!/bin/bash

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