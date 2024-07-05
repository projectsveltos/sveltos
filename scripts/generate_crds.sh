#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target generate-kustomize

rm -rf manifest/crds/
mkdir manifest/crds/
touch manifest/crds/sveltos_crds.yaml

for f in kustomize/components/crds/*.yaml
do 
    # ignore kustomization.yaml file
    if [[ "$f" == *"kustomization.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> manifest/crds/sveltos_crds.yaml
    echo "---"  >> manifest/crds/sveltos_crds.yaml
done