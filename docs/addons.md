---
title: Sveltos - Kubernetes Add-on Controller | Manage and Deploy Add-ons
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
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

With [ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons"), you can easily deploy Helm charts, resources assembled with Kustomize or raw Kubernetes YAML across a set of Kubernetes clusters. All you need to do is define which Kubernetes add-ons to deploy and where to deploy them:

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
4. Deploy resources assembled with Kustomize [clusterprofile.yaml](https://github.com/projectsveltos/addon-controller/blob/main/examples/kustomize.yaml)
5. Deploy resources assembled with Kustomize contained in a ConfigMap [clusterprofile.yaml](https://github.com/projectsveltos/addon-controller/blob/main/examples/kustomize_with_configmap.yaml)

### Deep dive: ClusterProfile CRD

![ClusterProfile](assets/sveltos_different_policies.png)

#### Cluster Selection
To select the clusters where you want to deploy add-ons, simply use the *clusterSelector* field and specify a Kubernetes label selector. For example, you can use `env=prod` to select all clusters labeled with `env` set to `prod`.

#### Helm charts

With the *helmCharts* field, you can list the Helm charts you want to deploy. Sveltos will deploy the Helm charts in the exact order you define them.

#### Resources assembled with Kustomize

With the *kustomizationRefs* field, you can list directories containing resources assembled with Kustomize. Directories can be:
1. GitRepository (requires flux to be synced);
2. OCIRepository (requires flux to be synced);
3. Bucket (requires flux to be synced);
4. ConfigMap whose BinaryData section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;
5. Secret (type addons.projectsveltos.io/cluster-profile) whose Data section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;

##### Kustomize with Flux GitRepository

The following YAML is an example of Sveltos is referencing a Flux GitRepository. The git repository `https://github.com/gianlucam76/kustomize` contains several kustomize directories. In this example, Sveltos will run Kustomize on `helloWorld` directory and deploy the output of kustomize in the namespace `eng` in each managed cluster matching the clusterSelector.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: flux-system
    name: flux-system
    kind: GitRepository
    path: ./helloWorld/
    targetNamespace: eng
```

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: flux-system
  timeout: 60s
  url: ssh://git@github.com/gianlucam76/kustomize
```

```bash
kubectl exec -it -n projectsveltos                      sveltosctl-0   -- ./sveltosctl show addons
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | apps:Deployment | eng       | the-deployment | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
| default/sveltos-management-workload | :Service        | eng       | the-service    | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
| default/sveltos-management-workload | :ConfigMap      | eng       | the-map        | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
```

##### Kustomize with ConfigMap

If you have a directories containing Kustomize resources, you can put that content in a ConfigMap (or Secret) and have ClusterProfile reference it.

In this example we are cloning the git repository `https://github.com/gianlucam76/kustomize` locally, then we create a `kustomize.tar.gz` with the content of the helloWorldWithOverlays directory.

```bash
git clone git@github.com:gianlucam76/kustomize.git 
tar -czf kustomize.tar.gz -C kustomize/helloWorldWithOverlays .
kubectl create configmap kustomize --from-file=kustomize.tar.gz
```

Following ClusterProfile, will use Kustomize SDK to get all resources that need to be deployed and deploy those in the `production` namespace in each managed cluster matching the clusterSelector.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kustomize-with-configmap 
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: default
    name: kustomize
    kind: ConfigMap
    path: ./overlays/production/
    targetNamespace: production
```

```bash
kubectl exec -it -n projectsveltos                      sveltosctl-0   -- ./sveltosctl show addons
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE  |           NAME            | VERSION |             TIME              |     CLUSTER PROFILES     |
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
| default/sveltos-management-workload | apps:Deployment | production | production-the-deployment | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :Service        | production | production-the-service    | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :ConfigMap      | production | production-the-map        | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
```

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

But what about DryRun, you ask? Stay tuned for more information on that feature in a separate [section](dryrun.md). In the meantime, try out Sveltos and its powerful ClusterProfile syncMode options for hassle-free Kubernetes add-on management.

The last available option is [Configuration Drift](#configuration-drift).

### Sveltos manager controller configuration

Following arguments can be used to customize Sveltos manager controller:

1. *concurrent-reconciles*: by default Sveltos manager reconcilers runs with a parallelism set to 10. This arg can be used to change level of parallelism;
2. *worker-number*: number of workers performing long running task. By default this is set to 20. Increase it number of managed clusters is above 100. Read this [Medium post](https://medium.com/@gianluca.mardente/how-to-handle-long-running-tasks-in-kubernetes-reconciliation-loop-3cc04bfa2681) to know more about how Sveltos handles long running task. 
