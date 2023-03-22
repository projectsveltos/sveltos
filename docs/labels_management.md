---
title: Kubernetes Cluster Classification - Project Sveltos 
description: A Kubernetes cluster is a set of nodes that run containerized applications. Discover Kubernetes cluster classification based on cluster run-time state.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - kubernetes cluster classification
    - cluster runtime state
    - multi-tenancy
authors:
    - Gianluca Mardente
---
## Cluster label management

Sveltos can also be configured to automatically update cluster labels based on cluster runtime state. 

The core idea of Sveltos is to give users the ability to programmatically decide which add-ons should be deployed where by utilizing a ClusterSelector that selects all clusters with labels matching the selector.

Sometimes the versions of required add-ons and/or what add-ons are needed depend on the cluster runtime state. For instance, when a cluster is upgraded, some add-ons need to be upgraded as well. 

In such cases it is convenient to instruct Sveltos to manage cluster labels so that:

1. as cluster runtime state changes, cluster labels are automatically updated;
2. when cluster labels change, ClusterProfile instances matched by a cluster change;
3. as cluster starts matching new ClusterProfile instances, new set of add-ons are deployed.

Sveltos introduced Classifier for this goal. Once a Classifier instance has been deployed in the management cluster, it gets distributed to each cluster. A Sveltos operator running in each managed cluster continues to monitor the cluster runtime state. Information is transmitted back to the management cluster after determining a cluster runtime state match. The cluster labels will then be appropriately updated by Sveltos. As soon as cluster labels are changed, the cluster might begin to match a new ClusterProfle, which leads to an automatic upgrade of Kubernetes add-ons.
When combining Classifier with ClusterProfiles,

-	Sveltos monitors the runtime status for each cluster.
-	Sveltos updates cluster labels when the cluster runtime state changes.
-	Sveltos deploys and upgrades Kubernetes add-ons.

![Classifier in action](assets/classifier.gif)

## A simple use case: upgrade helm charts automatically when Kubernetes cluster is upgraded
Suppose you are managing several Kubernetes clusters with different versions.
And you want to deploy:

1. OPA Gatekeeper version 3.10.0 in any Kubernetes cluster whose version is >= v1.25.0
2. OPA Gatekeeper version 3.9.0 in any Kubernetes cluster whose version is >= v1.24.0 && < v1.25.0

You can create following ClusterProfiles and Classifiers in the management cluster:
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-gatekeeper-3-10
spec:
  clusterSelector: gatekeeper=v3-10
  syncMode: Continuous
  helmCharts:
  - repositoryURL: https://open-policy-agent.github.io/gatekeeper/charts
    repositoryName: gatekeeper
    chartName: gatekeeper/gatekeeper
    chartVersion:  3.10.0
    releaseName: gatekeeper
    releaseNamespace: gatekeeper
    helmChartAction: Install
```

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-gatekeeper-3-9
spec:
  clusterSelector: gatekeeper=v3-9
  syncMode: Continuous
  helmCharts:
  - repositoryURL: https://open-policy-agent.github.io/gatekeeper/charts
    repositoryName: gatekeeper
    chartName: gatekeeper/gatekeeper
    chartVersion:  3.9.0
    releaseName: gatekeeper
    releaseNamespace: gatekeeper
    helmChartAction: Install
```

Then create following Classifiers

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: deploy-gatekeeper-3-10
spec:
  classifierLabels:
  - key: gatekeeper
    value: v3-10
  kubernetesVersionConstraints:
  - comparison: GreaterThanOrEqualTo
    version: 1.25.0
```

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: deploy-gatekeeper-3-9
spec:
  classifierLabels:
  - key: gatekeeper
    value: v3-9
  kubernetesVersionConstraints:
  - comparison: GreaterThanOrEqualTo
    version: 1.24.0
  - comparison: LessThan
    version: 1.25.0
```

With the above cluster configuration:

1. Any cluster with a Kubernetes version v1.24.x will get label _gatekeeper:v3.9_ added and because of that Gatekeeper 3.9.0 helm chart will be deployed;
2. Any cluster with a Kubernetes version v1.25.x will get label _gatekeeper:v3.10_ added and because of that Gatekeeper 3.10.0 helm chart will be deployed;
3. As soon a cluster is upgraded from Kubernetes version v1.24.x to v1.25.x, Gatekeeper helm chart will be automatically upgraded from 3.9.0 to 3.10.0

To read more about classifier configuration, with more examles using resources and Lua script, please take a look at this [section](configuration.md#managing-labels).

### More examples

1. Classify clusters based on their Kubernetes version [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/kubernetes_version.yaml)
2. Classify clusters based on number of namespaces [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/resources.yaml)
3. Classify clusters based on their Kubernetes version and resources [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/multiple_constraints.yaml)
