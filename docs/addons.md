---
title: Addon Distribution - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Gianluca Mardente
---
[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a lightweight application designed to manage hundreds of clusters. It does so by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.

Sveltos focuses not only on the ability to scale the number of clusters it can manage, but also to give visibility to exactly which add-ons are installed on each cluster.

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters. But it is not limited to that. Any other cluster (GKE for instance) can easily be [registered](register-cluster.md#register-cluster) with Sveltos. Then, Sveltos can manage Kubernetes add-ons on all the clusters seamless.

![Sveltos managing clusters](assets/multi-clusters.png)

## How does Sveltos work?

Sveltos provides declarative APIs for provisioning Kubernetes add-ons such as Helm charts or raw Kubernetes YAML in a set of Kubernetes clusters.

Sveltos provides few custom resource definitions (CRDs) to be configured.

The idea is simple:

1. from the management cluster, selects one or more clusters with a Kubernetes [label selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors "Kubernetes label selector");
1. lists which Kubernetes add-ons need to be deployed on such clusters.

### Quick example

By simply creating an instance of [ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons"), Sveltos can be instructed on what add-ons to deploy and where.

Following [ClusterProfile](assets/clusterprofile.md) instance is instructing Sveltos to deploy Kyverno helm chart in any cluster with label *env:prod*

![Sveltos in action](assets/addons.png)

![Sveltos in action](assets/addons_deployment.gif)

For a quick video of Sveltos, watch the video [Sveltos introduction](https://www.youtube.com/watch?v=Ai5Mr9haWKM "Sveltos introduction: Kubernetes add-ons management") on YouTube.

### More examples

1. Deploy calico in each CAPI powered cluster [clusterprofile.yaml](https://raw.githubusercontent.com/projectsveltos/sveltos-manager/main/examples/calico.yaml)
2. Deploy Kyverno in each cluster [clusterprofile.yaml](https://raw.githubusercontent.com/projectsveltos/sveltos-manager/main/examples/kyverno.yaml)
3. Deploy multiple helm charts [clusterprofile.yaml](https://raw.githubusercontent.com/projectsveltos/sveltos-manager/main/examples/multiple_helm_charts.yaml)

### Deep dive: ClusterProfile CRD

[ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons") is the CRD used to instructs Sveltos about:

1. which Kubernetes add-ons to deploy;
2. where (on which Kubernetes clusters) to deploy the Kubernetes add-ons. 

![ClusterProfile](assets/sveltos_different_policies.png)

#### Cluster Selection
The *clusterSelector* field is a Kubernetes label selector. Sveltos uses it to detect all the clusters where add-ons need to be deployed.

Example: clusterSelector: env=prod

#### Helm charts

The *helmCharts* field allows to list a set of helm charts to deploy. Sveltos will deploy helm chart in the same exact order those are defined in this field.

#### Kubernetes resources

The *policyRefs* field points to list of ConfigMaps/Secrets. Each referenced ConfigMap/Secret contains yaml/json content as value. 

Both Secrets and ConfigMaps data fields can be a list of key-value pairs. Any key is acceptable, and as value, there can be multiple objects in yaml or json format.

Secrets are preferred if the data includes sensitive information.

To create a secret that has calico YAMLs in its data field to be used by ClusterProfile:

```bash
wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

kubectl create secret generic calico --from-file=calico.yaml --type=addons.projectsveltos.io/cluster-profile
```

The following YAML file is an example of ConfigMap, containing multiple resources. 
When Sveltos deploys this ConfigMap as part of our ClusterProfile, a GatewayClass and Gateway instance are automatically deployed in any matching cluster.

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: contour-gateway
  namespace: default
data:
  gatewayclass.yaml: |
    kind: GatewayClass
    apiVersion: gateway.networking.k8s.io/v1beta1
    metadata:
      name: contour
    spec:
      controllerName: projectcontour.io/projectcontour/contour
  gateway.yaml: |
    kind: Namespace
    apiVersion: v1
    metadata:
      name: projectcontour
    ---
    kind: Gateway
    apiVersion: gateway.networking.k8s.io/v1beta1
    metadata:
     name: contour
     namespace: projectcontour
    spec:
      gatewayClassName: contour
      listeners:
        - name: http
          protocol: HTTP
          port: 80
          allowedRoutes:
            namespaces:
              from: All

```

ClusterProfile can only reference Secret of type ***addons.projectsveltos.io/cluster-profile***

Here is a ClusterProfile referencing above ConfigMap and Secret.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: contour-gateway
    namespace: default
    kind: ConfigMap
  - name: calico
    namespace: default
    kind: Secret
```

When referencing ConfigMap/Secret, kind and name are required.
Namespace is optional:

- if namespace is set, it uniquely indenties a resource and that resource will be used for all matching clusters;
- if namespace is left empty, for each matching cluster, Sveltos will use the namespace of the cluster. 
  
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: contour-gateway
    kind: ConfigMap
```

With above ClusterProfile, if we have two workload clusters matching, one in namespace _foo_ and one in namespace _bar_, Sveltos will look for ConfigMap _contour-gateway_ in namespace _foo_ for Cluster in namespace _foo_ and for a ConfigMap _contour-gateway_ in namespace _bar_ for Cluster in namespace _bar_.

More ClusterProfile examples can be found [here](https://github.com/projectsveltos/sveltos-manager/tree/main/examples "Manage Kubernetes add-ons: examples").

#### Sync mode

The syncMode field has three possible options. Continuous and OneTime are explained below. DryRun is explained in a separate section.

Example: syncMode: Continuous

*OneTime*

Upon deployment of a ClusterProfile with a syncMode configuration of OneTime, all clusters are checked for a clusterSelector match, and all matching clusters will have the current ClusterProfile-specified features installed at that time.

Any subsequent changes to the ClusterProfile instance will not be deployed into the already matching clusters.

*Continuous*

When the syncMode configuration is Continuous, any new changes made to the ClusterProfile instanceare immediately reconciled into the matching clusters.

Reconciliation consists of one of these actions on matching clusters:

1. deploy a feature — whenever a feature is added to the ClusterProfile or when a cluster newly matches the ClusterProfile;
1. update a feature — whenever the ClusterProfile configuration changes or any referenced ConfigMap/Secret changes;
1. remove a feature — whenever a Helm release or a ConfigMap/Secret is deleted from the ClusterProfile.

*Continuous with configuration drift detection*

See [Configuration Drift](#configuration-drift).

*DryRun*

See [Dry Run Mode](#dryrun-mode).

#### DryRun mode

Before adding, modifying, or deleting a ClusterProfile, it is often useful to see what changes will result from the action. When you deploy a ClusterProfile with a syncMode configuration of DryRun, a workflow is launched that will simulate all of the operations that would be executed in an actual run. No actual change is applied to matching clusters in the dry run workflow, so there are no side effects. 

The dry run workflow generates a list of potential changes for each matching cluster, allowing you to inspect and validate these changes before deploying the new ClusterProfile configuration.

You can see the change list by viewing a generated Custom Resource Definition (CRD) named ClusterReport, but it is much easier to view the list using a sveltosctl CLI command, as shown in the following example:

```
./bin/sveltosctl show dryrun

+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+
|               CLUSTER               |      RESOURCE TYPE       | NAMESPACE |      NAME      |  ACTION   |            MESSAGE             | CLUSTER PROFILE  |
+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+
| default/sveltos-management-workload | helm release             | kyverno   | kyverno-latest | Install   |                                | dryrun           |
| default/sveltos-management-workload | helm release             | nginx     | nginx-latest   | Install   |                                | dryrun           |
| default/sveltos-management-workload | :Pod                     | default   | nginx          | No Action | Object already deployed.       | dryrun           |
|                                     |                          |           |                |           | And policy referenced by       |                  |
|                                     |                          |           |                |           | ClusterProfile has not changed |                  |
|                                     |                          |           |                |           | since last deployment.         |                  |
| default/sveltos-management-workload | kyverno.io:ClusterPolicy |           | no-gateway     | Create    |                                | dryrun           |
+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+

```

For a demonstration of dry run mode, watch the video [Sveltos, introduction to DryRun mode](https://www.youtube.com/watch?v=gfWN_QJAL6k&t=4s) on YouTube.

### Sveltos manager controller configuration

Following arguments can be used to customize Sveltos manager controller:

1. *concurrent-reconciles*: by default Sveltos manager reconcilers runs with a parallelism set to 10. This arg can be used to change level of parallelism;
2. *worker-number*: number of workers performing long running task. By default this is set to 20. Increase it number of managed clusters is above 100. Read this [Medium post](https://medium.com/@gianluca.mardente/how-to-handle-long-running-tasks-in-kubernetes-reconciliation-loop-3cc04bfa2681) to know more about how Sveltos handles long running task. 
