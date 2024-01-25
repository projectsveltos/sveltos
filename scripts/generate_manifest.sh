#!/bin/bash

# DO NOT INVOKE DIRECTLY. Use Makefile target generate-manifest

branch=${1}

echo "Generate manifest for branch ${branch}"

rm -rf  manifest/manifest.yaml
touch  manifest/manifest.yaml
rm -rf  manifest/agents_in_mgmt_cluster_manifest.yaml
touch  manifest/agents_in_mgmt_cluster_manifest.yaml

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
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
done
cd ../../; rm -rf tmp

# addon-controller
echo "processing addon-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/addon-controller.git
cd addon-controller
git checkout ${branch}
for f in manifest/*.yaml
do 
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    if [[ "$f" == *"drift_detection_manager_rbac.yaml"* ]]; then
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "" >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    else
        cat $f >> ../../manifest/manifest.yaml
        echo "---"  >> ../../manifest/manifest.yaml
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    fi
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
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
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
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
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
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
done
cd ../../; rm -rf tmp

# event-manager
echo "processing event-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/event-manager.git
cd event-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
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
    # this file contains the template to start a deployment
    # for managing a shard
    if [[ "$f" == *"deployment-shard.yaml"* ]]; then
        continue
    fi

    echo "Processing $f file..."
    if [[ "$f" == *"sveltos_agent_rbac.yaml"* ]]; then
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "" >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    else
        cat $f >> ../../manifest/manifest.yaml
        echo "---"  >> ../../manifest/manifest.yaml 
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    fi
done
cd ../../; rm -rf tmp

# sveltos-agent
echo "processing sveltos-agent"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltos-agent.git
cd sveltos-agent
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    if [[ "$f" == *"mgmt_cluster_common_manifest.yaml"* ]]; then
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "" >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    else
       echo "Ignoring $f file"
    fi
done
cd ../../; rm -rf tmp

# drift-detection-manager
echo "processing drift-detection-manager"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/drift-detection-manager.git
cd drift-detection-manager
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    if [[ "$f" == *"mgmt_cluster_common_manifest.yaml"* ]]; then
        cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "" >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
        echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    else
       echo "Ignoring $f file"
    fi
done
cd ../../; rm -rf tmp

# shard-controller
echo "processing shard-controller"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/shard-controller.git
cd shard-controller
git checkout ${branch}
for f in manifest/*.yaml
do 
    echo "Processing $f file..."
    cat $f >> ../../manifest/manifest.yaml
    echo "---"  >> ../../manifest/manifest.yaml
    cat $f >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
    echo "---"  >> ../../manifest/agents_in_mgmt_cluster_manifest.yaml
done
cd ../../; rm -rf tmp

echo "Generate sveltosctl manifest for branch ${branch}"

rm -rf  manifest/sveltosctl_manifest.yaml
touch  manifest/sveltosctl_manifest.yaml

# sveltosctl
echo "processing sveltosctl"
rm -rf tmp; mkdir tmp; cd tmp
git clone git@github.com:projectsveltos/sveltosctl.git
cd sveltosctl
git checkout ${branch}
for f in manifest/*.yaml
do
    echo "Processing $f file..."
    cat $f >> ../../manifest/sveltosctl_manifest.yaml
    echo "---"  >> ../../manifest/sveltosctl_manifest.yaml
done
cd ../../; rm -rf tmp

function add_agent_in_mgmt_cluster_option() {
    echo "Add agent-in-mgmt-cluster option to classifier and addon-controller"

    old_value="report-mode=0"

    new_value="report-mode=0
        - --agent-in-mgmt-cluster"
    
    file="manifest/agents_in_mgmt_cluster_manifest.yaml"
    perl -i -pe "s#$old_value#$new_value#g" "$file"
}

add_agent_in_mgmt_cluster_option
