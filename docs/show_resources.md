---
title: Notifications - Projectsveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Slack
authors:
    - Gianluca Mardente
---

Projectsveltos CLI can be used to display information about resorces in managed clusters.

For instance, to display information about all deployments in each managed cluster, just create a __ClusterHealthCheck__ and a __HealthCheck__.
Notice that:

- HealthCheck instance contains a Lua script which examine all deployments in managed cluster;
- __ClusterHealthCheck__ clusterSelector field allows to filter on which managed clusters deployments need to be examined.
 
```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: ClusterHealthCheck
metadata:
  name: production
spec:
  clusterSelector: env=fv
  livenessChecks:
  - name: deployment
    type: HealthCheck
    livenessSourceRef:
      kind: HealthCheck
      apiVersion: lib.projectsveltos.io/v1alpha1
      name: deployment-replicas
  notifications:
  - name: event
    type: KubernetesEvent
---
apiVersion: lib.projectsveltos.io/v1alpha1
kind: HealthCheck
metadata:
 name: deployment-replicas
spec:
 collectResources: true
 group: "apps"
 version: v1
 kind: Deployment
 script: |
   function evaluate()
     hs = {}
     hs.status = "Progressing"
     hs.message = ""
     if obj.spec.replicas == 0 then
       hs.ignore=true
       return hs
     end
     if obj.status ~= nil then
       if obj.status.availableReplicas ~= nil then
         if obj.status.availableReplicas == obj.spec.replicas then
           hs.status = "Healthy"
           hs.message = "All replicas " .. obj.spec.replicas .. " are healthy"
         else
           hs.status = "Progressing"
           hs.message = "expected replicas: " .. obj.spec.replicas .. " available: " .. obj.status.availableReplicas
         end
       end
       if obj.status.unavailableReplicas ~= nil then
          hs.status = "Degraded"
          hs.message = "deployments have unavailable replicas"
       end
     end
     return hs
   end
```

   then we can use __sveltosctl show resources__ command to see in a single place information from resources from each managed clusters matching the __ClusterHealthCheck__ clusterSelector field.

```bash
kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl show resources --kind=deployment 
+-----------------------------+--------------------------+----------------+-----------------------------------------+----------------------------+
|           CLUSTER           |           GVK            |   NAMESPACE    |                  NAME                   |          MESSAGE           |
+-----------------------------+--------------------------+----------------+-----------------------------------------+----------------------------+
| default/clusterapi-workload | apps/v1, Kind=Deployment | kube-system    | calico-kube-controllers                 | All replicas 1 are healthy |
|                             |                          | kube-system    | coredns                                 | All replicas 2 are healthy |
|                             |                          | kyverno        | kyverno-admission-controller            | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-background-controller           | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-cleanup-controller              | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-reports-controller              | All replicas 1 are healthy |
|                             |                          | projectsveltos | sveltos-agent-manager                   | All replicas 1 are healthy |
| gke/pre-production          |                          | gke-gmp-system | gmp-operator                            | All replicas 1 are healthy |
|                             |                          | gke-gmp-system | rule-evaluator                          | All replicas 1 are healthy |
|                             |                          | kube-system    | antrea-controller-horizontal-autoscaler | All replicas 1 are healthy |
|                             |                          | kube-system    | egress-nat-controller                   | All replicas 1 are healthy |
|                             |                          | kube-system    | event-exporter-gke                      | All replicas 1 are healthy |
|                             |                          | kube-system    | konnectivity-agent                      | All replicas 4 are healthy |
|                             |                          | kube-system    | konnectivity-agent-autoscaler           | All replicas 1 are healthy |
|                             |                          | kube-system    | kube-dns                                | All replicas 2 are healthy |
|                             |                          | kube-system    | kube-dns-autoscaler                     | All replicas 1 are healthy |
|                             |                          | kube-system    | l7-default-backend                      | All replicas 1 are healthy |
|                             |                          | kube-system    | metrics-server-v0.5.2                   | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-admission-controller            | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-background-controller           | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-cleanup-controller              | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-reports-controller              | All replicas 1 are healthy |
|                             |                          | nginx          | nginx-deployment                        | All replicas 2 are healthy |
|                             |                          | projectsveltos | sveltos-agent-manager                   | All replicas 1 are healthy |
| gke/production              |                          | gke-gmp-system | gmp-operator                            | All replicas 1 are healthy |
|                             |                          | gke-gmp-system | rule-evaluator                          | All replicas 1 are healthy |
|                             |                          | kube-system    | antrea-controller-horizontal-autoscaler | All replicas 1 are healthy |
|                             |                          | kube-system    | egress-nat-controller                   | All replicas 1 are healthy |
|                             |                          | kube-system    | event-exporter-gke                      | All replicas 1 are healthy |
|                             |                          | kube-system    | konnectivity-agent                      | All replicas 3 are healthy |
|                             |                          | kube-system    | konnectivity-agent-autoscaler           | All replicas 1 are healthy |
|                             |                          | kube-system    | kube-dns                                | All replicas 2 are healthy |
|                             |                          | kube-system    | kube-dns-autoscaler                     | All replicas 1 are healthy |
|                             |                          | kube-system    | l7-default-backend                      | All replicas 1 are healthy |
|                             |                          | kube-system    | metrics-server-v0.5.2                   | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-admission-controller            | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-background-controller           | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-cleanup-controller              | All replicas 1 are healthy |
|                             |                          | kyverno        | kyverno-reports-controller              | All replicas 1 are healthy |
|                             |                          | projectsveltos | sveltos-agent-manager                   | All replicas 1 are healthy |
+-----------------------------+--------------------------+----------------+-----------------------------------------+----------------------------+
```

It is possible to filter by cluster and/or resource

```bash
kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl show resources --help                                                                  
Usage:
  sveltosctl show resources [options] [--group=<group>] [--kind=<kind>] [--namespace=<namespace>] 
  [--cluster-namespace=<name>] [--cluster=<name>] [--full] [--verbose]

     --group=<group>              Show Kubernetes resources deployed in clusters matching this group.
                                  If not specified all groups are considered.
     --kind=<kind>                Show Kubernetes resources deployed in clusters matching this Kind.
                                  If not specified all kinds are considered.
     --namespace=<namespace>      Show Kubernetes resources in this namespace. 
                                  If not specified all namespaces are considered.
     --cluster-namespace=<name>   Show Kubernetes resources in clusters in this namespace.
                                  If not specified all namespaces are considered.
     --cluster=<name>             Show Kubernetes resources in cluster with name.
                                  If not specified all cluster names are considered.
     --full                       If specified, full resources are printed
```

Using the option __--full__ it is possible to display the full resources

```bash
kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl show resources --full
Cluster:  default/clusterapi-workload
Object:  object:
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    annotations:
      deployment.kubernetes.io/revision: "1"
    creationTimestamp: "2023-07-11T14:03:15Z"
    ...
``` 
