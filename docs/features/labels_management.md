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
## Classifier - Automatically Manage Cluster Labels and Add-Ons 

Sveltos provides users with the power to decide which add-ons should get deployed to which clusters programmatically by the use of a ClusterSelector. Sometimes the versions of the required and needed add-ons depend on the cluster's runtime state. This is where the Sveltos Classifier comes into play.

With the Classifier, Sveltos can be configured to automatically update the cluster labels based on the cluster runtime state. As the runtime state changes, the cluster labels are automatically updated. This ensures that the appropriate ClusterProfile instances match the specified clusters, leading to an automatic upgrade of the Kubernetes add-ons.

Once the Classifier is deployed in the management cluster, it is distributed to each cluster, and a Sveltos service running in each managed cluster monitors the cluster runtime state. As soon as a match is found, information is transmitted back to the management cluster, and the cluster labels are appropriately updated by Sveltos.

By combining the Classifier with the ClusterProfiles, Sveltos can monitor the runtime status of each cluster, update the cluster labels when the cluster runtime state changes, and deploy, upgrade the Kubernetes add-ons accordingly.

![Classifier in action](../assets/classifier.gif)

## Use Case: Upgrade Helm Charts when Kubernetes Cluster is Upgraded

Suppose you are managing several Kubernetes clusters with different versions and you want to deploy the below points:

1. OPA Gatekeeper version 3.10.0 in any Kubernetes cluster whose version is >= v1.25.0
2. OPA Gatekeeper version 3.9.0 in any Kubernetes cluster whose version is >= v1.24.0 && < v1.25.0

### Management Cluster

#### ClusterProfiles

!!! example ""
    ```yaml
    ---
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

!!! example ""
    ```yaml
    ---
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

#### Classifiers

!!! example ""
    ```yaml
    ---
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

!!! example ""
    ```yaml
    ---
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

Based on the above configuration, we achieved the below.

1. Any cluster with a Kubernetes version v1.24.x will get the label _gatekeeper:v3.9_ added and then the Gatekeeper v3.9.0 helm chart will be deployed;
1. Any cluster with a Kubernetes version v1.25.x will get the label _gatekeeper:v3.10_ added and then the Gatekeeper v3.10.0 helm chart will be deployed;
1. As soon as a cluster is upgraded from Kubernetes v1.24.x to v1.25.x, Gatekeeper helm chart will be automatically upgraded from 3.9.0 to 3.10.0

### More Resources

To read more about the classifier configuration, with examles using the resources and the Lua script, have a look at the [section](labels_management.md#classifier-controller-configuration).

### More Examples

1. Classify clusters based on their Kubernetes version [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/kubernetes_version.yaml)
1. Classify clusters based on the number of namespaces [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/resources.yaml)
1. Classify clusters based on their Kubernetes version and resources [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/multiple_constraints.yaml)


### Classifier CRD - Deep dive

[Classifier CRD](https://raw.githubusercontent.com/projectsveltos/libsveltos/main/api/v1alpha1/classifier_types.go) is the CRD used to instructs Sveltos on how to classify a cluster.

#### Classifier Labels
The field *classifierLabels* contains all the labels (key/value pair) which will be added automatically to any cluster matching a Classifier instance.

#### Kubernetes version constraints
The field *kubernetesVersionConstraints* can be used to classify a cluster based on its current Kubernetes version.

#### Resource constraints
The field *deployedResourceConstraints* can be used to classify a cluster based on current deployed resources. Resources are identified by Group/Version/Kind and can be filtered based on their namespace and labels and some fields. It supports Lua script as well.

Following classifier, matches any cluster with a Service with label __sveltos:fv__.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1alpha1
    kind: Classifier
    metadata:
      name: sveltos-service
    spec:
      classifierLabels:
      - key: sveltos-service
        value: present
      deployedResourceConstraint:
        resourceSelectors:
        - group: ""
          version: v1
          kind: Service
          labelFilters:
          - key: sveltos
            operation: Equal
            value: fv
    ```

Following classifier, matches any cluster with a ClusterIssuer using _acme-staging-v02.api.letsencrypt.org_ 

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1alpha1
    kind: Classifier
    metadata:
      name: acme-staging-v02
    spec:
      classifierLabels:
      - key: issuer
        value: acme-staging-v02
      deployedResourceConstraints:
        resourceSelectors:
        - group: "cert-manager.io"
          version: v1
          kind: ClusterIssuer
          evaluate: |
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

A Classifier can also look at the resources of different kinds all together.

__AggregatedClassification__ is optional and can be used to specify a Lua function that will be used to further detect whether the subset of the resources selected using the ResourceSelectors field are a match for this Classifier.
The function will receive the array of resources selected by ResourceSelectors. If this field is not specified, a cluster is a match for Classifier instance, if all ResourceSelectors returns at least one match.
This field allows to perform more complex evaluation on the resources, looking at all resources together. This can be useful for more sophisticated tasks, such as identifying resources that are related to each other or that have similar properties.
The Lua function must return a struct with:

- "matching" field: boolean indicating whether cluster is a match;
- "message" field: (optional) message.

### Classifier controller configuration

1. *concurrent-reconciles*: By default Sveltos manager reconcilers runs with a parallelism set to 10. This arg can be used to change level of parallelism;
1. *worker-number*: Number of workers performing long running task. By default this is set to 20. If number of Classifier instances is in the hundreds, please consider increasing this;
1. *report-mode*: By default Classifier controller running in the management cluster periodically collects ClassifierReport instances from each managed cluster. Setting report-mode to "1" will change this and have each Classifier Agent send back ClassifierReport to management cluster. When setting report-mode to 1, *control-plane-endpoint* must be set as well. When in this mode, Sveltos automatically creates a ServiceAccount in the management cluster for Classifier Agent. Only permissions granted for this ServiceAccount are update of ClassifierReports.
1. *control-plane-endpoint*: The management cluster controlplane endpoint. Format <ip\>:<port\>. This must be reachable frm each managed cluster.
