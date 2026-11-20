---
title: Projectsveltos horizontal scaling
description: Sveltos can manage add-ons and applications in hundreds of clusters, and it can be scaled horizontally by easily adding an annotation to managed clusters.
tags:
    - Kubernetes
    - add-ons
    - vertical scaling
authors:
    - Gianluca Mardente
---

The below arguments can be used to customize Sveltos add-on controller.

1. *concurrent-reconciles*: By default the Sveltos manager reconcilers runs with a **parallelism** set to **10**. This arg can be used to change level of parallelism for ClusterProfiles and ClusterSummary;
2. *worker-number*: The number of workers performing long running task. By default it is set to **20**. Increase it number if the managed clusters is above 100.
3. *kube-api-qps* and *kube-api-burst*: the rate limit of the add-on controller client towards the management cluster Kubernetes API server. By default **40** queries per second, with bursts of up to **120**. Increase them when many ClusterSummary instances are created or updated at once (see below);
4. *managed-cluster-kube-api-qps* and *managed-cluster-kube-api-burst*: the same limit, applied separately to the API server of each managed cluster. By default **20** queries per second, with bursts of up to **60**.

More infromation can be found in the folllowing [Medium post](https://medium.com/@gianluca.mardente/how-to-handle-long-running-tasks-in-kubernetes-reconciliation-loop-3cc04bfa2681) on how Sveltos handles long running task.

## Management cluster API rate limit

Every ClusterSummary the add-on controller creates, reads or updates goes through the client rate limit set by *kube-api-qps* and *kube-api-burst*. When many ClusterSummary instances change at once, for instance when a ClusterProfile matching many clusters is created, the controller can spend its time waiting on this limit instead of working. In that case adding workers does not help, while raising the limit does.

The following test shows the effect. It deploys 20 ClusterProfiles, with raw YAML resources only, to 25 clusters: 306 ClusterSummary instances. The management cluster is a kind cluster and the managed clusters are bare Kubernetes API servers, so absolute times on a real fleet will differ.

| Configuration | All ClusterSummaries created | Last ClusterSummary provisioned |
|---|---|---|
| Defaults (*kube-api-qps*=40, *kube-api-burst*=120) | 45 seconds | 81 seconds |
| *kube-api-qps*=200, *kube-api-burst*=400 | 10 seconds | 45 seconds |

In the same test, raising *worker-number* to 60 and *concurrent-reconciles* to 30, with the default rate limit, left the time to deploy everything unchanged.

A higher limit moves the load to the management cluster API server and etcd. Raise *kube-api-qps* and *kube-api-burst* together, in steps, and watch the API server CPU and request latency.

### Helm

```sh
helm upgrade projectsveltos projectsveltos/projectsveltos -n projectsveltos --reuse-values \
    --set addonController.controller.extraArgs.kube-api-qps=200 \
    --set addonController.controller.extraArgs.kube-api-burst=400
```

When Sveltos runs in agentless mode (`agent.managementCluster=true`), use `addonController.controller.extraArgsAgentMgmtCluster` instead of `addonController.controller.extraArgs`.

### Manifest

Add the arguments to the `addon-controller` Deployment:

```sh
kubectl -n projectsveltos patch deployment addon-controller --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kube-api-qps=200"},{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kube-api-burst=400"}]'
```
