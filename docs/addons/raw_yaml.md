---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease
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

## ClusterProfile policyRefs Reference

The ClusterProfile *spec.policyRefs* is a list of Secrets/ConfigMaps. Both Secrets and ConfigMaps data fields can be a list of key-value pairs. Any key is acceptable, and the value can be multiple objects in YAML or JSON format[^1].

### Example: Create a Secret

To create a Kubernetes Secret that contains the Calico YAMLs and make it usable with Sveltos, utilise the below commands.

```bash
$ wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

$ kubectl create secret generic calico --from-file=calico.yaml --type=addons.projectsveltos.io/cluster-profile
```

The commands will download the calico.yaml manifest file and afterwards create a Kubernetes secret of type `generic` by defining the file downloaded in the previous command plus defining the needed `type=addons.projectsveltos.io/cluster-profile`.

**Please note:** A ClusterProfile can only reference Secrets of type ***addons.projectsveltos.io/cluster-profile***

### Example: Create a ConfigMap

The YAML definition below exemplifies a ConfigMap that holds multiple resources[^2]. When a ClusterProfile instance references the ConfigMap, a `Namespace` and a `Deployment` instance are automatically deployed in any managed cluster that adheres to the ClusterProfile *clusterSelector*.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx
  namespace: default
data:
  namespace.yaml: |
    kind: Namespace
    apiVersion: v1
    metadata:
      name: nginx
  deployment.yaml: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
      namespace: nginx  
    spec:
      replicas: 2 # number of pods to run
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:latest # public image from Docker Hub
            ports:
            - containerPort: 80
```

Once the required Kubernetes resources are created/deployed, the below example represents a ClusterProfile resource that references the ConfigMap and the Secret created above.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: nginx
    namespace: default
    kind: ConfigMap
  - name: calico
    namespace: default
    kind: Secret
```

**Note:** The `namespace` definition refers to the namespace where the ConfigMap, and the Secret were created in the management cluster. In our example, both resources created in the `default` namespace.

When a ClusterProfile references a ConfigMap or a Secret, the **kind** and **name** fields are required, while the namespace field is optional. Specifying a namespace uniquely identifies the resource using the tuple namespace, name, and kind, and that resource will be used for all matching clusters.

If you leave the namespace field empty, Sveltos will search for the ConfigMap or the Secret with the provided name within the namespace of each matching cluster.

### Example: Understand Namespace Definition
  
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: nginx
    kind: ConfigMap
```

Consider the provided ClusterProfile, when we have two workload clusters matching. One in the _foo_ namespace and another in the _bar_ namespace. Sveltos will search for the ConfigMap _nginx_ in the _foo_ namespace for the Cluster in the _foo_ namespace and for a ConfigMap _ngix_ in the _bar_ namespace for the Cluster in the _bar_ namespace.

More ClusterProfile examples can be found [here](https://github.com/projectsveltos/sveltos-manager/tree/main/examples "Manage Kubernetes add-ons: examples").

Remember to adapt the provided resources to your specific repository structure, cluster configuration, and desired templating logic.

[^1]:A ConfigMap is not designed to hold large chunks of data. The data stored in a ConfigMap cannot exceed 1 MiB. If you need to store settings that are larger than this limit, you may want to consider mounting a volume or use a separate database or file service.
[^2]: Another way to create a Kubernetes ConfigMap resource is with the imperative approach. The below command will create the same ConfigMap resource in the management cluster.
```bash
$ kubectl create configmap nginx --from-file=namespace.yaml --from-file=deployment.yaml
```
