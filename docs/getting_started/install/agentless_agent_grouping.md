---
title: Agent Grouping in Agentless Mode
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn how to have a single sveltos-agent and a single drift-detection-manager serve several clusters in agentless mode, instead of one instance per cluster.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - scalability
authors:
    - Gianluca Mardente
---

# Agent Grouping in Agentless Mode :material-crown:{ title="Enterprise" }

## Why This Matters

In agentless mode (`agent.managementCluster=true`, also called Centralized Agent mode), `sveltos-agent` and `drift-detection-manager` run in the **management** cluster and reach each managed cluster through its own registered credential. By default, Sveltos starts one `sveltos-agent` Deployment per cluster and, when a `ClusterProfile` or `Profile` with `syncMode: ContinuousWithDriftDetection` matches the cluster, one `drift-detection-manager` Deployment per cluster as well.

With a handful of clusters that is fine. With hundreds of clusters, the number of Deployments and pods in the management cluster grows with the fleet. **Agent Grouping** lets one `sveltos-agent` and one `drift-detection-manager` serve several clusters, so the number of instances is the number of clusters divided by the group size, rounded up.

!!! warning
    Agent Grouping requires a valid Sveltos Enterprise or Enterprise Plus license granting the `AgentGrouping` feature. The license is verified by `sveltos-agent` and `drift-detection-manager` themselves: without it, a grouped instance does not serve any cluster. A license created or fixed after the instance started is picked up without restarting it. Contact `support@projectsveltos.io` to explore license options.

## Enabling Agent Grouping

Agent Grouping is controlled by the `--agent-clusters-per-instance` flag. It is only meaningful in agentless mode (`--agent-in-mgmt-cluster=true`) and has the same meaning on the two components that start the agents:

- the `classifier` (`classifier-manager` Deployment) starts `sveltos-agent`;
- the `addon-controller` starts `drift-detection-manager`.

The value is the maximum number of clusters one instance serves. The default is `1`: one instance per cluster, which is the behavior without grouping. A value of `2` or more enables grouping. Set the flag on both components to group both agents, or on one of them to group only that agent.

### Helm

```sh
$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace \
    --set agent.managementCluster=true \
    --set classifierManager.manager.extraArgsAgentMgmtCluster.agent-clusters-per-instance=10 \
    --set addonController.controller.extraArgsAgentMgmtCluster.agent-clusters-per-instance=10
```

The same configuration in a values file:

```yaml
agent:
  managementCluster: true
classifierManager:
  manager:
    extraArgsAgentMgmtCluster:
      agent-clusters-per-instance: 10
addonController:
  controller:
    extraArgsAgentMgmtCluster:
      agent-clusters-per-instance: 10
```

The chart adds each entry of `extraArgsAgentMgmtCluster` to the arguments of the Deployment as `--<key>=<value>`. These values are used when `agent.managementCluster=true`, which is the agentless mode. On an existing installation, run `helm upgrade` with the same values: both Deployments restart.

If [sharding](../../scalability/horizontal_scaling_sharding.md) is used, also set the options of the `shard-controller`, see [Helm configuration of the shard controller flags](../../scalability/horizontal_scaling_sharding.md#helm-configuration).

### Manifest or Kustomize

Add the flag to the arguments of the two Deployments. With Kustomize, for instance:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- https://github.com/projectsveltos/sveltos.git//kustomize/overlays/agentless-mode?timeout=120&ref=v1.18.0
patches:
- target:
    kind: Deployment
    name: classifier-manager
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/args/-
      value: --agent-clusters-per-instance=10
- target:
    kind: Deployment
    name: addon-controller
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/args/-
      value: --agent-clusters-per-instance=10
```

On a running installation, the same JSON patch can be applied with `kubectl patch deployment <name> -n projectsveltos --type json -p '[...]'`. Both Deployments restart. Instances that are already running are not moved by the restart: see [Turning Grouping On and Off](#turning-grouping-on-and-off).

## How Clusters Are Grouped

- **Only clusters of the same namespace share an instance.** An instance serves one namespace only. Clusters in different namespaces always get different instances. For `drift-detection-manager`, clusters of different [shards](../../scalability/horizontal_scaling_sharding.md) are not mixed either.
- **Placement is first fit.** A new cluster is placed in the lowest-numbered group that still has room. When every group is full, a new group is created.
- **Clusters stay where they are.** A cluster is never moved from one group to another, so lowering `--agent-clusters-per-instance` does not rebalance existing groups. Only new clusters follow the new value.
- **A group disappears with its last cluster.** When the last cluster of a group is removed, the Deployment of the group is deleted.

Each group is made of two objects in the `projectsveltos` namespace: a Deployment, and a ConfigMap with the **same name** listing the clusters the Deployment serves. The name is the component name, a hash of the namespace the clusters are in, and the index of the group.

For example, with `--agent-clusters-per-instance=2`, two clusters `scoped-a` and `scoped-b` registered in the namespace `grouping` are served by one instance of each component:

```
$ kubectl get deployments -n projectsveltos | grep -E "sveltos-agent|drift-detection"
drift-detection-c4d17251-0   1/1     1            1           106s
sveltos-agent-c4d17251-0     1/1     1            1           3m34s
```

```
$ kubectl get configmap sveltos-agent-c4d17251-0 -n projectsveltos -o jsonpath='{.data.members}'
[{"name":"scoped-a","clusterType":"Sveltos","watchNamespaces":["team-a"]},{"name":"scoped-b","clusterType":"Sveltos","watchNamespaces":["team-b"]}]
```

!!! note
    The ConfigMaps are written and kept up to date by Sveltos. They are not meant to be edited.

### Turning Grouping On and Off

Changing `--agent-clusters-per-instance` does not move the instances that are already running, and restarting the controllers does not either. The new value is applied to a cluster **the next time Sveltos deploys the agent of that cluster**: when the cluster is registered, or when the `Classifier` (for `sveltos-agent`) or the resources deployed by a `ClusterProfile` or `Profile` with `syncMode: ContinuousWithDriftDetection` (for `drift-detection-manager`) are reconciled after a change. A cluster is therefore moved on its own, independently of the other clusters, and during the transition some clusters can be served by a group while others already have their own instance.

- **Turning grouping on** (a value of `2` or more): the instance of the cluster is replaced by one serving a group of its namespace. When all the clusters of a namespace have been moved, they are served by a single instance.
- **Turning grouping off** (a value of `1`, or removing the flag, since `1` is the default): the cluster is taken out of its group first, then it gets its own instance, so that it is not left served by two instances. A group is deleted, together with its ConfigMap, when its last cluster is gone.

The same applies to `sveltos-agent` and `drift-detection-manager`, and each of the two components follows the value of its own flag. Once a cluster has been moved, drift recovery and the `EventSource` and `HealthCheck` reports work exactly as before.

## Isolation Between Clusters

A grouped instance runs one **worker** per cluster. Each worker has its own connection to the cluster, its own caches and its own state, built with the credential registered for that cluster only. This has a few consequences:

- A cluster that is unreachable, or whose token expires, restarts **only its own worker**. The other clusters of the group keep being served.
- A cluster never uses the credential of another cluster of the group.
- Reports (`ClassifierReports`, `EventReports`, `HealthCheckReports`) and `ResourceSummaries` are produced per cluster, exactly as without grouping.

!!! note "Per-cluster patches"
    A Deployment serves several clusters, so a patch requested by one of them cannot be applied to it. When grouped, the per-cluster annotations `sveltosagent.projectsveltos.io/config-override-ref` and `driftdetection.projectsveltos.io/config-override-ref` are ignored, and only the global patches apply (see [Sizing the Instances](#sizing-the-instances)).

## Sizing the Instances

One grouped instance does the work that, without grouping, is done by several. Its CPU and memory needs grow with the number of clusters it serves. They also grow with how much each of those clusters has to be watched.

For `sveltos-agent`, this depends on the resource kinds selected by the `Classifiers`, `EventSources`, `HealthChecks` and `Reloaders`. For `drift-detection-manager`, it depends on the resources deployed by the `ClusterProfiles` and `Profiles` with `syncMode: ContinuousWithDriftDetection`.

Depending on the size of the clusters in a group, the CPU and memory requests and limits of `sveltos-agent` and `drift-detection-manager` may need to be **increased**. They should be raised when `--agent-clusters-per-instance` is raised, or when the clusters in the groups grow.

The actual usage of the instances (`kubectl top pods -n projectsveltos`) and the restarts of their pods should be monitored. A pod killed for lack of memory interrupts every cluster of its group, not just one.

Resources are changed with the **global patches** of each component, which are applied to every instance, grouped or not. Per-cluster overrides cannot be used, as explained above, so size the patch for the largest group. The patches live in a ConfigMap in the `projectsveltos` namespace:

| Component | ConfigMap argument | Argument of | Helm value |
|---|---|---|---|
| `sveltos-agent` | `--sveltos-agent-config` | `classifier-manager` | `classifierManager.agentPatchConfigMap` |
| `drift-detection-manager` | `--drift-detection-config` | `addon-controller` | `addonController.driftDetectionManagerPatchConfigMap` |

For example, the ConfigMap below sets the resources of every `sveltos-agent` instance. The values are only an illustration: the right ones depend on the clusters in the group.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sveltos-agent-config
  namespace: projectsveltos
data:
  resources: |-
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/resources
        value:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            memory: 2Gi
    target:
      kind: Deployment
      labelSelector: feature=sveltos-agent
      namespace: projectsveltos
```

The same patch, with `labelSelector: feature=drift-detection` and referenced by `--drift-detection-config` on the `addon-controller`, sets the resources of `drift-detection-manager`.

!!! note
    In agentless mode the name of each instance is generated, so target the patches with `labelSelector`, not with a name. The [Air-Gapped Installation](air_gapped_installation.md#sveltos-agent-configuration) page describes the global patches in detail, for both [`sveltos-agent`](air_gapped_installation.md#sveltos-agent-configuration) and [`drift-detection-manager`](air_gapped_installation.md#drift-detection-manager-configuration), including how to set them from the Helm values.

## Combining Agent Grouping with Limited RBAC

Agent Grouping and [limited RBAC](agentless_limited_rbac.md) are independent features and work together. Every cluster of a group keeps its own credential and its own [`agent.projectsveltos.io/watch-namespaces`](../../features/configuration_drift.md#namespace-scoped-watch-mode) annotation, and the worker of the cluster watches only those namespaces. The namespaces are listed next to each cluster in the ConfigMap of the group (`watchNamespaces` above).

As an example, register two clusters in the `grouping` namespace, each with a credential restricted to a different namespace:

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: scoped-a
  namespace: grouping
  annotations:
    agent.projectsveltos.io/watch-namespaces: "team-a"
spec: {}
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: scoped-b
  namespace: grouping
  annotations:
    agent.projectsveltos.io/watch-namespaces: "team-b"
spec: {}
```

Each cluster needs the Secret `<cluster name>-sveltos-kubeconfig` in the same namespace, with the kubeconfig of a ServiceAccount allowed to act in `team-a` (respectively `team-b`) only. The Role to grant is described in [Running Agents with Limited RBAC in Agentless Mode](agentless_limited_rbac.md#what-rbac-do-they-actually-need), including the permission to create Events.

The single `sveltos-agent` then evaluates the `Classifiers`, `EventSources` and `HealthChecks` of `scoped-a` only in `team-a`, and those of `scoped-b` only in `team-b`. The single `drift-detection-manager` does the same for the resources deployed by `ClusterProfiles` and `Profiles`. Resources in any other namespace never show up in any report.

!!! warning
    Using both features together requires a license granting both `AgentGrouping` and `NamespaceScopedAgents`.

## Verifying

Verify the instances of each component, and which clusters each one serves:

```
$ kubectl get deployments -n projectsveltos | grep -E "sveltos-agent|drift-detection"
drift-detection-c4d17251-0   1/1     1            1           106s
sveltos-agent-c4d17251-0     1/1     1            1           3m34s
```

```
$ kubectl get configmaps -n projectsveltos | grep -E "sveltos-agent|drift-detection"
drift-detection-c4d17251-0   1      106s
sveltos-agent-c4d17251-0     1      3m34s
```

```
$ kubectl get configmap sveltos-agent-c4d17251-0 -n projectsveltos -o jsonpath='{.data.members}'
[{"name":"scoped-a","clusterType":"Sveltos","watchNamespaces":["team-a"]},{"name":"scoped-b","clusterType":"Sveltos","watchNamespaces":["team-b"]}]
```

The log of a grouped instance tells it is running in grouped mode and starts one worker per cluster:

```
$ kubectl logs -n projectsveltos deployment/sveltos-agent-c4d17251-0 | grep -E "grouped mode|starting worker"
"running in grouped mode" logger="setup" configMap="sveltos-agent-c4d17251-0" clusterNamespace="grouping"
"starting worker" logger="worker" cluster="Sveltos:grouping/scoped-a"
"starting worker" logger="worker" cluster="Sveltos:grouping/scoped-b"
```

### Troubleshooting Licensing Issues

If a group serves no cluster, check the license first. A grouped instance without a valid license granting `AgentGrouping` is not ready (its readiness probe fails) and serves no cluster.

The pod of the instance is running but never becomes ready:

```
$ kubectl get pods -n projectsveltos | grep -E "sveltos-agent|drift-detection"
drift-detection-c4d17251-0-7c9d5b6f4-q8w2z   0/1     Running   0          2m
sveltos-agent-c4d17251-0-6d9f8b7c5-x2k4p     0/1     Running   0          2m
```

The events of the pod show the failed readiness probe:

```
$ kubectl describe pod -n projectsveltos sveltos-agent-c4d17251-0-6d9f8b7c5-x2k4p | grep Readiness
  Warning  Unhealthy  14s (x12 over 2m)  kubelet  Readiness probe failed: HTTP probe failed with statuscode: 500
```

The log of the instance states the reason. The `drift-detection-manager` logs the same message, naming itself:

```
$ kubectl logs -n projectsveltos deployment/sveltos-agent-c4d17251-0 | grep license-check
"one sveltos-agent serving several clusters (--group-config-map) requires a valid Sveltos Enterprise license granting AgentGrouping: no cluster is served until one is found" logger="license-check" feature="AgentGrouping"
```

This message is logged when no license is installed, and also when a license is installed but is expired or does not grant the `AgentGrouping` feature. The license is read from the `sveltos-license` Secret in the `projectsveltos` namespace:

```
$ kubectl get secret sveltos-license -n projectsveltos
Error from server (NotFound): secrets "sveltos-license" not found
```

Once a valid license is in place, the instance becomes ready and starts serving its clusters without being restarted.

## Next Steps

Continue with the **sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).
