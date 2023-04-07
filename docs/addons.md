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

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a lightweight application designed to manage Kubernetes add-ons in hundreds of clusters with ease. It does so by providing declarative APIs, making it a breeze to manage your clusters and stay on top of your game.

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters, but it doesn't stop there. You can easily register any other cluster (like GKE, for instance) with Sveltos and manage Kubernetes add-ons on all clusters seamlessly.

![Sveltos managing clusters](assets/multi-clusters.png)

## How does Sveltos work?

With [ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons"), you can easily deploy Helm charts or raw Kubernetes YAML across a set of Kubernetes clusters. All you need to do is define which Kubernetes add-ons to deploy and where to deploy them:

1. Select one or more clusters using a Kubernetes [label selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors "Kubernetes label selector");
2. List the Kubernetes add-ons that need to be deployed on the selected clusters.

It's as simple as that!

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

![ClusterProfile](assets/sveltos_different_policies.png)

#### Cluster Selection
To select the clusters where you want to deploy add-ons, simply use the *clusterSelector* field and specify a Kubernetes label selector. For example, you can use `env=prod` to select all clusters labeled with `env` set to `prod`.

#### Helm charts

With the *helmCharts* field, you can list the Helm charts you want to deploy. Sveltos will deploy the Helm charts in the exact order you define them.

#### Kubernetes resources

The *policyRefs* field allows you to point to a list of ConfigMaps or Secrets that contain YAML or JSON content. Each ConfigMap or Secret can contain a list of key-value pairs, and you can use any key you want. If the data contains sensitive information, use Secrets instead of ConfigMaps.

To create a Secret that contains Calico YAMLs, use the following command:

```bash
wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

kubectl create secret generic calico --from-file=calico.yaml --type=addons.projectsveltos.io/cluster-profile
```

The following YAML file is an example of a ConfigMap that contains multiple resources. When Sveltos deploys this ConfigMap as part of our ClusterProfile, a GatewayClass and Gateway instance are automatically deployed in any matching cluster.

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

Remember that ClusterProfile can only reference Secrets of type ***addons.projectsveltos.io/cluster-profile***

Here is an example of a ClusterProfile that references the ConfigMap and Secret we created above:

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

When referencing a ConfigMap or Secret, the kind and name fields are required, while the namespace field is optional. If you specify a namespace, the resource will be used for all matching clusters. If you leave it empty, Sveltos will use the namespace of each matching
  
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

With Sveltos, you can configure the syncMode field to either Continuous or OneTime, depending on your deployment needs.

Let's take a closer look at the OneTime syncMode option. Once you deploy a ClusterProfile with a OneTime configuration, Sveltos will check all of your clusters for a match with the clusterSelector. Any matching clusters will have the features specified in the ClusterProfile deployed. However, if you make changes to the ClusterProfile later on, those changes will not be automatically deployed to already-matching clusters.

Now, if you're looking for real-time deployment and updates, the Continuous syncMode is the way to go. With Continuous, any changes made to the ClusterProfile will be immediately reconciled into matching clusters. This means that you can add new features, update existing ones, and remove them as necessary, all without lifting a finger. Sveltos will deploy, update, or remove features in matching clusters as needed, making your life as a Kubernetes admin a breeze.

But what about DryRun, you ask? Stay tuned for more information on that feature in a separate [section](#dryrun-mode). In the meantime, try out Sveltos and its powerful ClusterProfile syncMode options for hassle-free Kubernetes add-on management.

The last available option is [Configuration Drift](#configuration-drift).

#### DryRun mode

Imagine you're about to make some important changes to your ClusterProfile, but you're not entirely sure what the results will be. You don't want to risk causing any unwanted side effects, right? Well, that's where the DryRun syncMode configuration comes in!

By deploying your ClusterProfile with this configuration, you can launch a simulation of all the operations that would normally be executed in a live run. The best part? No actual changes will be made to the matching clusters during this dry run workflow, so you can rest easy knowing that there won't be any surprises.

Once the dry run workflow is complete, you'll receive a detailed list of all the potential changes that would have been made to each matching cluster. This allows you to carefully inspect and validate these changes before deploying the new ClusterProfile configuration.

If you're interested in viewing this change list, you can check out the generated Custom Resource Definition (CRD) called ClusterReport. But let's be real, it's much simpler to just use the sveltosctl CLI command, like this:

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
