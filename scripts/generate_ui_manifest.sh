#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target generate-ui-manifest

branch=${1}

echo "Generate manifest for branch ${branch}"

rm -rf  manifest/dashboard-manifest.yaml
touch  manifest/dashboard-manifest.yaml

# ui-backend
echo "processing ui-backend"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/ui-backend.git
cd ui-backend
git checkout ${branch}
for f in manifest/*.yaml
do
    # ignore kustomization.yaml file
    if [[ "$f" == *"kustomization.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../manifest/dashboard-manifest.yaml
    echo "---"  >> ../../manifest/dashboard-manifest.yaml
done
cd ../../; rm -rf tmp

# dashboard
echo "processing dashboard"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/dashboard.git
cd dashboard
git checkout ${branch}
for f in manifest/*.yaml
do
    # ignore kustomization.yaml file
    if [[ "$f" == *"kustomization.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../manifest/dashboard-manifest.yaml
    echo "---"  >> ../../manifest/dashboard-manifest.yaml
done
cd ../../; rm -rf tmp