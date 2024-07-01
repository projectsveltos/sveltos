#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target upload-docker-images

branch=${1}

echo "Generate and upload docker images for branch ${branch}"

# addon-controller
echo "processing addon-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/addon-controller.git
cd addon-controller
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# classifier
echo "processing classifier"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/classifier.git
cd classifier
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# sveltos-agent
echo "processing sveltos-agent"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-agent.git
cd sveltos-agent
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# drift-detection-manager
echo "processing drift-detection-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/drift-detection-manager.git
cd drift-detection-manager
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# access-manager
echo "processing access-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/access-manager.git
cd access-manager
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# sveltoscluster-manager
echo "processing sveltoscluster-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltoscluster-manager.git
cd sveltoscluster-manager
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# sveltosctl
echo "processing sveltosctl"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltosctl.git
cd sveltosctl
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# healthcheck-manager
echo "processing healthcheck-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/healthcheck-manager.git
cd healthcheck-manager
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# event-manager
echo "processing event-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/event-manager.git
cd event-manager
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# shard-controller
echo "processing shard-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/shard-controller.git
cd shard-controller
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# register-mgmt-cluster
echo "processing register-mgmt-cluster"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/register-mgmt-cluster.git
cd register-mgmt-cluster
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp

# conversion-webhook
echo "processing conversion-webhook"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/conversion-webhook.git
cd conversion-webhook
git checkout ${branch}
make docker-buildx
cd ../../; rm -rf tmp
