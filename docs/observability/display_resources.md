---
title: Display Resources - Projectsveltos
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

## Introduction to Resources

Managing multiple clusters effectively requires a centralized location for viewing a summary of all the deployed resources. Below are some of the key reasons why it is important.

1. **Centralized Visibility:** A central location provides a unified view of resource summaries. It allows monitoring and visualisation of the health of every cluster in one place. It simplifies issue detection, trend identification, and problem troubleshooting across multiple clusters.
1. **Efficient Troubleshooting and Issue Resolution:** With a centralized resource view, we can swiftly identify the affected clusters when an issue arises, compare it with others, and narrow down potential causes. This comprehensive overview of resource states and dependencies enables efficient troubleshooting and quicker problem resolution.
1. **Enhanced Security and Compliance:** Centralized resource visibility strengthens **security** and **compliance** monitoring. It enables monitoring of the cluster configurations, identify security vulnerabilities, and ensures consistent adherence to compliance standards across all clusters. We can easily track and manage access controls, network policies, and other security-related aspects from a single location.

Using Projectsveltos can facilitate the display of information about all the resources resources in the managed clusters.

![Sveltosctl show resources](../assets/show_resources.png)

## Example: Display Deployment Replicas Managed Clusters

To showcase information about the deployments in every managed cluster, we can utilize a combination of a __ClusterHealthCheck__ and a __HealthCheck__.

Follow the steps below to set up Projectsveltos to display deployment replicas from the managed clusters.

1. Create a `HealthCheck` instance that contains a Lua script responsible for examining all the deployments in the managed clusters. In the example below, deployments with a difference between the number of available replicas and requested replicas are identified as `degraded`.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: deployment-replicas
    spec:
      collectResources: true
      resourceSelectors:
      - group: "apps"
        version: v1
        kind: Deployment
      evaluateHealth: |
        function evaluate()
          local statuses = {}

          status = "Progressing"
          message = ""

          for _,resource in ipairs(resources) do
            if resource.spec.replicas == 0 then
              continue
            end

            if resource.status ~= nil then
              if resource.status.availableReplicas ~= nil then
                if resource.status.availableReplicas == resource.spec.replicas then
                  status = "Healthy"
                  message = "All replicas " .. resource.spec.replicas .. " are healthy"
                else
                  status = "Progressing"
                  message = "expected replicas: " .. resource.spec.replicas .. " available: " .. resource.status.availableReplicas
                end
              end
              if resource.status.unavailableReplicas ~= nil then
                status = "Degraded"
                message = "deployments have unavailable replicas"
              end
            end
            table.insert(statuses, {resource=resource, status = status, message = message})
          end

          local hs = {}
          if #statuses > 0 then
            hs.resources = statuses
          end
          return hs
        end
    ```

 1. Use the `ClusterHealthCheck` and set the `clusterSelector` field to filter the managed cluster deployments that should be examined. In the below example, all managed clusters that match the cluster label selector `env=fv` are considered.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterHealthCheck
    metadata:
      name: production
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      livenessChecks:
      - name: deployment
        type: HealthCheck
        livenessSourceRef:
          kind: HealthCheck
          apiVersion: lib.projectsveltos.io/v1beta1
          name: deployment-replicas
      notifications:
      - name: event
        type: KubernetesEvent

    ```

The approach describe above enables us to display information about all the deployments across specific managed clusters effectively.

To obtain a consolidated view of resource information, the __sveltosctl show resources__ command can be used.

```bash
$ sveltosctl show resources --kind=deployment
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

Below are all the available options to filter what the `show resources` output displays.

```
--group=<group>: Show Kubernetes resources deployed in clusters matching this group. If not specified, all groups are considered.
--kind=<kind>: Show Kubernetes resources deployed in clusters matching this Kind. If not specified, all kinds are considered.
--namespace=<namespace>: Show Kubernetes resources in this namespace. If not specified, all namespaces are considered.
--cluster-namespace=<name>: Show Kubernetes resources in clusters in this namespace. If not specified, all namespaces are considered.
--cluster=<name>: Show Kubernetes resources in the cluster with the specified name. If not specified, all cluster names are considered.
```

Additionally, with the use of the __--full option__, we can display the complete details of the resources.

```bash
$ sveltosctl show resources --full
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
## Example: Display Deployment Images Managed Clusters

The below __HealthCheck__ instance will instruct Sveltos to collect and display the deployment images from every managed cluster.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: deployment-replicas
    spec:
      collectResources: true
      resourceSelectors:
      - group: "apps"
        version: v1
        kind: Deployment
        namespace: nginx
      evaluateHealth: |
        function evaluate()
          hs = {}
          hs.status = "Progressing"
          hs.message = ""
          if obj.status ~= nil then
            if obj.status.availableReplicas ~= nil then
              if obj.status.availableReplicas == obj.spec.replicas then
                hs.status = "Healthy"
              else
                hs.status = "Progressing"
              end
            end
            if obj.status.unavailableReplicas ~= nil then
              hs.status = "Degraded"
            end
          end

          for i, container in ipairs(obj.spec.template.spec.containers) do
            hs.message = "Image: " .. container.image
          end
          return hs
        end
    ```

```bash
$ sveltosctl show resources
+-----------------------------+--------------------------+-----------+------------------+---------------------+
|           CLUSTER           |           GVK            | NAMESPACE |       NAME       |       MESSAGE       |
+-----------------------------+--------------------------+-----------+------------------+---------------------+
| default/clusterapi-workload | apps/v1, Kind=Deployment | nginx     | nginx-deployment | Image: nginx:1.14.2 |
| gke/pre-production          |                          | nginx     | nginx-deployment | Image: nginx:latest |
| gke/production              |                          | nginx     | nginx-deployment | Image: nginx:1.14.2 |
+-----------------------------+--------------------------+-----------+------------------+---------------------+
```

## Example: Display Pod Names Based on Deployment

The below __HealthCheck__ instance will instruct Sveltos to collect and display the pod names based on a specified Deployment name.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: pod-in-deployment
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: v1
        kind: Pod
      evaluateHealth: |
        function setContains(set, key)
          return set[key] ~= nil
        end

        function evaluate()
          hs = {}
          hs.status = "Healthy"
          hs.message = ""
          hs.ignore = true
          if obj.metadata.labels ~= nil then
            if setContains(obj.metadata.labels, "app") then
              if obj.status.phase == "Running" then
                hs.ignore = false
                hs.message = "Deployment: " .. obj.metadata.labels["app"]
              end
            end
          end
          return hs
        end
    ```

```bash
$ sveltosctl show resources --kind=pod --namespace=nginx
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
|           CLUSTER           |      GVK      | NAMESPACE |               NAME                |      MESSAGE      |
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
| default/clusterapi-workload | /v1, Kind=Pod | nginx     | nginx-deployment-85996f8dbd-7tctq | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-85996f8dbd-tz4gd | Deployment: nginx |
| gke/pre-production          |               | nginx     | nginx-deployment-c4f7848dc-6jtwg  | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-c4f7848dc-trllk  | Deployment: nginx |
| gke/production              |               | nginx     | nginx-deployment-676cf9b46d-k84pb | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-676cf9b46d-mmbl4 | Deployment: nginx |
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
```


## Example: Display Kyverno PolicyReports

In this example we will define an `HealthCheck` instance with a Lua script that will:

1. Examine all the Kyverno PolicyReports;
1. Will report all the resources in violation of the policy and the rules defined

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: deployment-replicas
    spec:
      collectResources: true
      resourceSelectors:
      - group: wgpolicyk8s.io
        version: v1alpha2
        kind: PolicyReport
      evaluateHealth: |
        function evaluate()
          local statuses  = {}
          status = "Healthy"
          message = ""

          for _,resource in ipairs(resources) do
            for i, result in ipairs(resource.results) do
              if result.result == "fail" then
                status = "Degraded"
                for j, r in ipairs(result.resources) do
                  message = message .. " " .. r.namespace .. "/" .. r.name
                end
              end
            end

            if status ~= "Healthy" then
              table.insert(statuses, {resource=resource, status = status, message = message})
            end
          end

          local hs = {}
          if #statuses > 0 then
            hs.resources = statuses
          end

          return hs
        end
    ```

As before, we need to have a `ClusterHealthCheck` instance to instruct Sveltos which clusters to watch for.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterHealthCheck
    metadata:
      name: production
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      livenessChecks:
      - name: kyverno-policy-reports
        type: HealthCheck
        livenessSourceRef:
          kind: HealthCheck
          apiVersion: lib.projectsveltos.io/v1beta1
          name: kyverno-policy-reports
      notifications:
      - name: event
        type: KubernetesEvent
    ```

We assume we have deployed an nginx deployment using the __latest__ image in the managed cluster[^1]

```bash
$ sveltosctl show resources
+-------------------------------------+--------------------------------+-----------+--------------------------+-----------------------------------------+
|               CLUSTER               |              GVK               | NAMESPACE |           NAME           |                 MESSAGE                 |
+-------------------------------------+--------------------------------+-----------+--------------------------+-----------------------------------------+
| default/sveltos-management-workload | wgpolicyk8s.io/v1alpha2,       | nginx     | cpol-disallow-latest-tag |  nginx/nginx-deployment                 |
|                                     | Kind=PolicyReport              |           |                          | nginx/nginx-deployment-6b7f675859       |
|                                     |                                |           |                          | nginx/nginx-deployment-6b7f675859-fp6tm |
|                                     |                                |           |                          | nginx/nginx-deployment-6b7f675859-kkft8 |
+-------------------------------------+--------------------------------+-----------+--------------------------+-----------------------------------------+
```

[^1]:
To deploy Kyverno and a ClusterPolicy in each managed cluster matching the label selector __env=fv__ we can use the below `ClusterProfile` definition.

```yaml
  ---
  apiVersion: config.projectsveltos.io/v1beta1
  kind: ClusterProfile
  metadata:
    name: kyverno
  spec:
    clusterSelector:
      matchLabels:
        env: fv
    helmCharts:
    - chartName: kyverno/kyverno
      chartVersion: v3.3.3
      helmChartAction: Install
      releaseName: kyverno-latest
      releaseNamespace: kyverno
      repositoryName: kyverno
      repositoryURL: https://kyverno.github.io/kyverno/
    policyRefs:
    - deploymentType: Remote
      kind: ConfigMap
      name: kyverno-latest
      namespace: default
```
- The ConfigMap contains [this](https://kyverno.io/policies/best-practices/disallow-latest-tag/disallow-latest-tag/) Kyverno ClusterPolicy.

  ```bash
  $ wget https://github.com/kyverno/policies/raw/main//best-practices/disallow-latest-tag/disallow-latest-tag.yaml

  $ kubectl create configmap kyverno-latest --from-file disallow-latest-tag.yaml
  ```
