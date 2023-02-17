#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target generate-manifest

branch=${1}

echo "Generate manifest for branch ${branch}"

rm -rf  manifest/manifest.yaml
touch  manifest/manifest.yaml

# libsveltos
echo "processing libsveltos"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/libsveltos.git
cd libsveltos
git checkout ${branch}
for f in config/crd/bases/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp

# sveltos-manager
echo "processing sveltos-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-manager.git
cd sveltos-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp

# classifier
echo "processing classifier"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/classifier.git
cd classifier
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp

# access-manager
echo "processing access-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/access-manager.git
cd access-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp

# sveltoscluster-manager
echo "processing sveltoscluster-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltoscluster-manager.git
cd sveltoscluster-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp

# healthcheck-manager
echo "processing healthcheck-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/healthcheck-manager.git
cd healthcheck-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml 
done
cd ../../; rm -rf tmp