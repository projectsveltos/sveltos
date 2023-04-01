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
## Automatically Manage Cluster Labels and Add-Ons with Classifier

Sveltos provides users with the power to decide which add-ons should be deployed to clusters programmatically, using a ClusterSelector to select clusters with matching labels. However, sometimes the versions of required add-ons and which add-ons are needed depend on the cluster's runtime state. This is where Sveltos' Classifier comes in.

With Classifier, Sveltos can be configured to automatically update cluster labels based on the cluster runtime state, so as the runtime state changes, cluster labels are automatically updated. This ensures that the appropriate ClusterProfile instances are matched by each cluster, leading to an automatic upgrade of Kubernetes add-ons.

Once Classifier is deployed in the management cluster, it is distributed to each cluster, and a Sveltos service running in each managed cluster monitors the cluster runtime state. As soon as a match is found, information is transmitted back to the management cluster, and the cluster labels are appropriately updated by Sveltos.

By combining Classifier with ClusterProfiles, Sveltos can monitor the runtime status for each cluster, update cluster labels when the cluster runtime state changes, and deploy and upgrade Kubernetes add-ons accordingly. With Sveltos, managing cluster labels and add-ons has never been easier.

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

To read more about classifier configuration, with more examles using resources and Lua script, please take a look at this [section](labels_management.md#classifier-controller-configuration).

### More examples

1. Classify clusters based on their Kubernetes version [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/kubernetes_version.yaml)
2. Classify clusters based on number of namespaces [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/resources.yaml)
3. Classify clusters based on their Kubernetes version and resources [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/multiple_constraints.yaml)


### Deep dive: Classifier CRD

[Classifier CRD](https://raw.githubusercontent.com/projectsveltos/libsveltos/main/api/v1alpha1/classifier_types.go) is the CRD used to instructs Sveltos on how to classify a cluster.

#### Classifier Labels
The field *classifierLabels* contains all the labels (key/value pair) which will be added automatically to any cluster matching a Classifier instance.

#### Kubernetes version constraints
The field *kubernetesVersionConstraints* can be used to classify a cluster based on its current Kubernetes version.

#### Resource constraints
The field *deployedResourceConstraints* can be used to classify a cluster based on current deployed resources. Resources are identified by Group/Version/Kind and can be filtered based on their namespace and labels and some fields. It supports Lua script as well.

Following classifier, matches any cluster with at least 30 different namespaces.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: large-ns
spec:
  classifierLabels:
  - key: env
    value: large
  deployedResourceConstraints:
  - group: ""
    version: v1
    kind: Namespace
    minCount: 30
```

Following classifier, matches any cluster with a ClusterIssuer using _acme-staging-v02.api.letsencrypt.org_ 

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: acme-staging-v02
spec:
  classifierLabels:
  - key: issuer
    value: acme-staging-v02
  deployedResourceConstraints:
  - group: "cert-manager.io"
    version: v1
    kind: ClusterIssuer
    minCount: 1
    script: |
      function evaluate()
        hs = {}
        hs.matching = false
        hs.message = ""
        if obj.spec.acme ~= nil then
          if string.find(obj.spec.acme.server, "acme-staging-v02.api.letsencrypt.org", 1, true) then
            hs.matching = true
          end
        end
        return hs
      end
```

### Classifier controller configuration

1. *concurrent-reconciles*: by default Sveltos manager reconcilers runs with a parallelism set to 10. This arg can be used to change level of parallelism;
2. *worker-number*: number of workers performing long running task. By default this is set to 20. If number of Classifier instances is in the hundreds, please consider increasing this;
3. *report-mode*: by default Classifier controller running in the management cluster periodically collects ClassifierReport instances from each managed cluster. Setting report-mode to "1" will change this and have each Classifier Agent send back ClassifierReport to management cluster. When setting report-mode to 1, *control-plane-endpoint* must be set as well. When in this mode, Sveltos automatically creates a ServiceAccount in the management cluster for Classifier Agent. Only permissions granted for this ServiceAccount are update of ClassifierReports.
4. *control-plane-endpoint*: the management cluster controlplane endpoint. Format <ip\>:<port\>. This must be reachable frm each managed cluster.
