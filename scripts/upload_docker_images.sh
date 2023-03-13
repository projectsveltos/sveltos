#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target upload-docker-images

branch=${1}
config=${2}

echo "Generate and upload docker images for branch ${branch} -- ${config}"

# sveltos-manager
echo "processing sveltos-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-manager.git
cd sveltos-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/sveltos-manager-amd64:${branch}  
cd ../../; rm -rf tmp

# classifier
echo "processing classifier"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/classifier.git
cd classifier
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/classifier-amd64:${branch}
cd ../../; rm -rf tmp

# sveltos-agent
echo "processing sveltos-agent"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-agent.git
cd sveltos-agent
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/sveltos-agent-amd64:${branch}
cd ../../; rm -rf tmp

# drift-detection-manager
echo "processing drift-detection-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/drift-detection-manager.git
cd drift-detection-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/drift-detection-manager-amd64:${branch}
cd ../../; rm -rf tmp

# access-manager
echo "processing access-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/access-manager.git
cd access-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/access-manager-amd64:${branch}  
cd ../../; rm -rf tmp

# sveltoscluster-manager
echo "processing sveltoscluster-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltoscluster-manager.git
cd sveltoscluster-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/sveltoscluster-manager-amd64:${branch}  
cd ../../; rm -rf tmp

# sveltosctl
echo "processing sveltosctl"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltosctl.git
cd sveltosctl
git checkout ${branch}
make docker-build
docker push gianlucam76/sveltosctl-amd64:${branch}
cd ../../; rm -rf tmp

# healthcheck-manager
echo "processing healthcheck-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/healthcheck-manager.git
cd healthcheck-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/healthcheck-manager-amd64:${branch}  
cd ../../; rm -rf tmp

# event-manager
echo "processing event-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/event-manager.git
cd event-manager
git checkout ${branch}
make docker-build
docker --config ${config} push projectsveltos/event-manager-amd64:${branch}  
cd ../../; rm -rf tmp