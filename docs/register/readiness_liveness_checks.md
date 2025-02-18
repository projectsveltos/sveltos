---
title: Register Cluster
description: SveltosCluster Readiness and Liveness checks.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

When a cluster is registered with Sveltos, Sveltos attempts to connect to its API server.  
A successful connection results in the cluster's status being set to `Ready`.  This `Ready` status is a prerequisite for any further actions; Sveltos will only deploy add-ons and applications to clusters that have achieved this status.

## SveltosCluster Readiness Checks

While basic API server connectivity is a good initial indicator, it's not always a comprehensive measure of a cluster's readiness. 
In many cases, a cluster might be reachable via its API server but still be in a transitional state.  For example, the control plane might be up and running, 
but the worker nodes, responsible for running workloads, might still be joining the cluster. 
Deploying applications to such a cluster prematurely could lead to failures.  Therefore, simply verifying API server connectivity might be insufficient to guarantee 
that the cluster is truly ready to accept workloads.  Sveltos needs a more nuanced approach to determine when a cluster is in a stable and operational state.

To address this limitation, Sveltos provides a mechanism for defining custom readiness checks for each registered cluster. These readiness checks allow administrators to specify 
the precise conditions that must be met before Sveltos considers a cluster truly Ready.  These conditions can go beyond simple API server connectivity and include checks on any type
of Kubernetes resources.

This YAML configuration defines a SveltosCluster resource that includes a readiness check.  This check verifies the existence of at least one worker node in the cluster by iterating through 
all nodes and confirming that at least one node lacks the __node-role.kubernetes.io/control-plane__ label, which is assumed to be absent on worker nodes in this specific setup.

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

In addition to `readiness` checks, Sveltos also employs `liveness` checks.  While readiness checks determine if a cluster is initially ready for deployments, 
liveness checks ensure the cluster remains healthy over time.  Once a cluster is marked as Ready (based on the readiness checks), Sveltos periodically connects to its API server and evaluates 
the defined liveness checks.  Only when all liveness checks pass does Sveltos consider the cluster Healthy.

The syntax for liveness checks is identical to that of readiness checks.  They are defined within the SveltosCluster specification using the `livenessChecks` field.