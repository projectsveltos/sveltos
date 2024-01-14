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

The ClusterProfile *Spec.PolicyRefs* is a list of Secrets/ConfigMaps. Both Secrets and ConfigMaps data fields can be a list of key-value pairs. Any key is acceptable, and the value can be multiple objects in YAML or JSON format[^1].

To create a Secret containing Calico YAMLs, use the below commands.

```bash
$ wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

$ kubectl create secret generic calico --from-file=calico.yaml --type=addons.projectsveltos.io/cluster-profile
```

**Please note:** A ClusterProfile can only reference Secrets of type ***addons.projectsveltos.io/cluster-profile***

The YAML file exemplifies a ConfigMap that holds multiple resources. When a ClusterProfile instance references this ConfigMap, a GatewayClass and a Gateway instance are automatically deployed in any managed cluster that adheres to the ClusterProfile's *clusterSelector*.

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

The below code represents a ClusterProfile resource that references the ConfigMap and Secret we created above.

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

When a ClusterProfile references a ConfigMap or Secret, the **kind** and **name** fields are required, while the namespace field is optional. Specifying a namespace uniquely identifies the resource using the tuple namespace,name,kind, and that resource will be used for all matching clusters.

If you leave the namespace field empty, Sveltos will search for the ConfigMap or Secret with the provided name within the namespace of each matching cluster.
  
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: contour-gateway
    kind: ConfigMap
```

Consider the provided ClusterProfile, when we have two workload clusters matching. One in the _foo_ namespace and another in the _bar_ namespace. Sveltos will search for the ConfigMap _contour-gateway_ in the _foo_ namespace for the Cluster in the _foo_ namespace and for a ConfigMap _contour-gateway_ in the _bar_ namespace for the Cluster in the _bar_ namespace.

More ClusterProfile examples can be found [here](https://github.com/projectsveltos/sveltos-manager/tree/main/examples "Manage Kubernetes add-ons: examples").

[^1]:A ConfigMap is not designed to hold large chunks of data. The data stored in a ConfigMap cannot exceed 1 MiB. If you need to store settings that are larger than this limit, you may want to consider mounting a volume or use a separate database or file service.