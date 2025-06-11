---
title: Register Cluster Readines and Liveness Check
description: SveltosCluster Readiness and Liveness Checks
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

When a cluster is registered with Sveltos, Sveltos attempts to connect to its `API server`. A successful connection results in the cluster's status being set to a `Ready` state. This status is a prerequisite for Sveltos to deploy add-ons and applications to clusters.

!!! note
    [Lua](https://www.lua.org/) and [CEL](https://cel.dev/) languages can be used as a way to express logic.

## SveltosCluster Readiness Checks

While basic API server connectivity is a good initial indicator, it is not always a comprehensive measure of a cluster's readiness condition. In many cases, a cluster might be reachable via its API server, but be in a transitional state. For example, the control plane might be running, but the worker nodes, responsible for running workloads, might still be joining the cluster. As a result, deploying applications to such a cluster could lead to failures. Sveltos needs a more nuanced approach to determine when a cluster is in a `stable` and `operational` state. To address these limitations, Sveltos provides a mechanism for defining custom `readiness checks` for each registered cluster. The `readiness checks` allow administrators to specify the same conditions that must be met before Sveltos considers a cluster `Ready`.

The below YAML configuration defines a `SveltosCluster` resource that includes a **readiness** check. The check verifies the existence of at least one worker node in the cluster by iterating through all nodes and confirming that at least one node lacks the __node-role.kubernetes.io/control-plane__ label, which is assumed to be absent on worker nodes in this particular setup.

```yaml hl_lines="8-27"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: staging
  namespace: default
spec:
  kubeconfigName: clusterapi-workload-sveltos-kubeconfig
  readinessChecks:
  - name: worker-node-check
    condition: |-
      function evaluate()
        hs = {}
        hs.pass = false

        for _, resource in ipairs(resources) do
          if  not (resource.metadata.labels and resource.metadata.labels["node-role.kubernetes.io/control-plane"]) then
            hs.pass = true
          end
        end

        return hs
      end
    
    resourceSelectors:
    - group: ""
      kind: Node
      version: v1
```

## SveltosCluster Liveness Checks

In addition to `readiness checks`, Sveltos employs `liveness checks`.  While `readiness checks` determine if a cluster is initially **ready** for deployments, the `liveness checks` ensure the cluster remains **healthy** over time.  Once a cluster is marked as `Ready` (readiness checks), Sveltos periodically connects to its API server and evaluates the defined `liveness checks`. Only when **all** `liveness checks` pass, Sveltos consider the cluster as **Healthy**.

The syntax for the `liveness checks` is identical to that of the `readiness checks`.  They are defined within the `SveltosCluster` specification using the `livenessChecks` field.