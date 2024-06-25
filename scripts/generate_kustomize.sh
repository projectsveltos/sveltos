#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target generate-kustomize

branch=${1}

echo "Generate kustomize for branch ${branch}"

rm -rf  kustomize/base/*.yaml
rm -rf  kustomize/components/crds/*.yaml
rm -rf  kustomize/overlays/agentless-mode/kustomization.yaml
rm -rf  kustomize/overlays/agentless-mode/drift_detection_manager_rbac.yaml
rm -rf  kustomize/overlays/agentless-mode/drift-detection-manager.yaml
rm -rf  kustomize/overlays/agentless-mode/sveltos-agent.yaml
rm -rf  kustomize/overlays/agentless-mode/sveltos_agent_rbac.yaml

# libsveltos
echo ""
echo "processing libsveltos"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/libsveltos.git
cd libsveltos
git checkout ${branch}
for f in manifests/*.yaml
do 
    echo "Processing $f file..."
    cp $f ../../kustomize/components/crds/.
done
cd ../../; rm -rf tmp

# addon-controller
echo ""
echo "processing addon-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/addon-controller.git
cd addon-controller
git checkout ${branch}
touch ../../kustomize/base/addon-controller.yaml
for f in manifest/*.yaml
do 
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    # this file is only used to run FV in agentless mode
    if [[ "$f" == *"deployment-agentless.yaml"* ]]; then
        continue
    fi

    # ignore service monitor
    if [[ "$f" == *"service_monitor.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    if [[ "$f" == *"drift_detection_manager_rbac.yaml"* ]]; then
        cp $f ../../kustomize/overlays/agentless-mode/.
    else
        cat $f >> ../../kustomize/base/addon-controller.yaml
    fi
done
cd ../../; rm -rf tmp

# access-manager
echo ""
echo "processing access-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/access-manager.git
cd access-manager
git checkout ${branch}
touch ../../kustomize/base/access-manager.yaml
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/access-manager.yaml
done
cd ../../; rm -rf tmp

# sveltoscluster-manager
echo ""
echo "processing sveltoscluster-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltoscluster-manager.git
cd sveltoscluster-manager
git checkout ${branch}
touch ../../kustomize/base/sveltoscluster-manager.yaml
for f in manifest/*.yaml
do
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/sveltoscluster-manager.yaml
done
cd ../../; rm -rf tmp

# healthcheck-manager
echo ""
echo "processing healthcheck-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/healthcheck-manager.git
cd healthcheck-manager
git checkout ${branch}
touch ../../kustomize/base/healthcheck-manager.yaml
for f in manifest/*.yaml
do
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/healthcheck-manager.yaml
done
cd ../../; rm -rf tmp

# event-manager
echo ""
echo "processing event-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/event-manager.git
cd event-manager
git checkout ${branch}
touch ../../kustomize/base/event-manager.yaml
for f in manifest/*.yaml
do 
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/event-manager.yaml
done
cd ../../; rm -rf tmp

# classifier
echo ""
echo "processing classifier"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/classifier.git
cd classifier
git checkout ${branch}
touch ../../kustomize/base/classifier.yaml
for f in manifest/*.yaml
do 
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

        # this file is only used to run FV in agentless mode
    if [[ "$f" == *"deployment-agentless.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    if [[ "$f" == *"sveltos_agent_rbac.yaml"* ]]; then
        cp $f ../../kustomize/overlays/agentless-mode/.
    else
        cat $f >> ../../kustomize/base/classifier.yaml
    fi
done
cd ../../; rm -rf tmp

# sveltos-agent
echo ""
echo "processing sveltos-agent"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-agent.git
cd sveltos-agent
git checkout ${branch}
for f in manifest/*.yaml
do
    echo "Processing $f file..."
    if [[ "$f" == *"mgmt_cluster_common_manifest.yaml"* ]]; then
        cp $f ../../kustomize/overlays/agentless-mode/sveltos-agent.yaml
    else
       echo "Ignoring $f file"
    fi
done
cd ../../; rm -rf tmp

# drift-detection-manager
echo ""
echo "processing drift-detection-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/drift-detection-manager.git
cd drift-detection-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    if [[ "$f" == *"mgmt_cluster_common_manifest.yaml"* ]]; then
        cp $f ../../kustomize/overlays/agentless-mode/drift-detection-manager.yaml
    else
       echo "Ignoring $f file"
    fi
done
cd ../../; rm -rf tmp

# shard-controller
echo ""
echo "processing shard-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/shard-controller.git
cd shard-controller
git checkout ${branch}
touch ../../kustomize/base/shard-controller.yaml
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/shard-controller.yaml
done
cd ../../; rm -rf tmp

echo ""

# register-mgmt-cluster
echo ""
echo "processing register-mgmt-cluster"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/register-mgmt-cluster.git
cd register-mgmt-cluster
git checkout ${branch}
touch ../../kustomize/base/register-mgmt-cluster.yaml
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/register-mgmt-cluster.yaml
done
cd ../../; rm -rf tmp

echo ""

# conversion-webhook
echo ""
echo "processing conversion-webhook"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/conversion-webhook.git
cd conversion-webhook
git checkout ${branch}
touch ../../kustomize/base/conversion-webhook.yaml
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../kustomize/base/conversion-webhook.yaml
done
cd ../../; rm -rf tmp