---
title: Classify Clusters from Management Cluster Resources - Project Sveltos
description: ManagementClusterClassifier lets Sveltos label managed clusters based on resources that exist in the management cluster itself, without deploying an agent to each managed cluster.
tags:
    - Kubernetes
    - cluster classification
    - management cluster
    - multi-cluster
    - labels
authors:
    - Gianluca Mardente
---

## Limitation of the Classifier

The standard [Classifier](labels_management.md) works by deploying `sveltos-agent` to every managed cluster. The agent evaluates rules against the cluster's own resources (its workloads, its Kubernetes version, its installed CRDs) and reports back to the management cluster, which then updates the cluster labels.

This model is correct when the classification signal lives **inside** the managed cluster. It does not work when the signal lives in the management cluster itself. Consider these scenarios:

- A ConfigMap in the `projectsveltos` namespace records which clusters belong to a cost centre or a business unit.
- An operator running in the management cluster maintains a registry of cluster tiers (gold, silver, bronze).
- A compliance scanner writes a custom resource to the management cluster after auditing each cluster, recording whether it passed or failed.

In all these cases, the information the classifier needs is already available locally, yet the standard Classifier has no way to reach it. This is the gap the `ManagementClusterClassifier` fills.

## ManagementClusterClassifier

`ManagementClusterClassifier` is a cluster-scoped CRD that watches resources on the **management cluster** and applies labels to managed clusters based on what those resources say. When a watched resource changes, the classifier re-evaluates immediately and updates cluster labels within seconds.

### How it works

The spec has three fields:


- `matchResources`: One or more selectors describing which management-cluster resources to watch (Group/Version/Kind, namespace, label selector, optional per-resource Lua or CEL filter)
- `classificationLua`: A Lua function `evaluate(resources)` that receives all matched resources and returns a list of `{namespace, name, kind}` tables identifying which managed clusters to label
- `classifierLabels`: The key/value labels to apply to every cluster the Lua function names

The reconciler runs entirely in the management cluster:

1. Lists all management-cluster resources matching `matchResources`
2. Passes them to `classificationLua`, which returns the target cluster list
3. Applies `classifierLabels` to each named cluster
4. Watches every GVK in `matchResources` so any change immediately triggers a re-evaluation

Label conflict detection works the same way as for `Classifier`. The first `ManagementClusterClassifier` to claim a label key on a cluster becomes its manager. Others record the conflict in `ManagementClusterClassifierReport`. When the managing instance is deleted or stops matching, the next in line takes over automatically.

!!! note
    The classifier ServiceAccount does not have permission to `get`, `list`, or `watch` arbitrary resources by default. For each resource type referenced in `spec.matchResources`, an administrator must add the corresponding rule to the `classifier-controller-role-extra` ClusterRole, which is created empty during installation and bound to the classifier ServiceAccount. For example, to allow watching ConfigMaps and a custom `ScanResult` CRD:

    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: classifier-controller-role-extra
    rules:
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["compliance.example.io"]
      resources: ["scanresults"]
      verbs: ["get", "list", "watch"]
    ```

## Example 1: Label clusters from a registry ConfigMap

A platform team maintains one ConfigMap per cluster in the `projectsveltos` namespace. Each ConfigMap carries metadata that is not available inside the managed cluster (cost centre, environment tier, business unit).

```bash
$ kubectl create configmap cluster-meta-prod-eu1 \
    --namespace projectsveltos \
    --from-literal=clusterNamespace=capi-clusters \
    --from-literal=clusterName=prod-eu1

$ kubectl label configmap cluster-meta-prod-eu1 \
    --namespace projectsveltos \
    sveltos.io/env=production
```

Create a `ManagementClusterClassifier` that reads those ConfigMaps and labels the named clusters:

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ManagementClusterClassifier
    metadata:
      name: tag-production-clusters
    spec:
      matchResources:
      - group: ""
        version: v1
        kind: ConfigMap
        namespace: projectsveltos
        selector:
          matchLabels:
            sveltos.io/env: production
      classificationLua: |
        function evaluate(resources)
          local result = {}
          for _, cm in ipairs(resources) do
            local ns   = cm.data.clusterNamespace
            local name = cm.data.clusterName
            if ns ~= nil and name ~= nil then
              table.insert(result, {namespace=ns, name=name, kind="Cluster"})
            end
          end
          return result
        end
      classifierLabels:
      - key: env
        value: production
      - key: cost-centre
        value: platform
    ```

Every time a ConfigMap with label `sveltos.io/env: production` is created, updated, or deleted in the `projectsveltos` namespace, the reconciler re-runs and the CAPI Cluster objects named in those ConfigMaps gain or lose the `env=production` and `cost-centre=platform` labels automatically.

## Example 2: Label clusters that passed a compliance scan

A compliance operator writes a `ScanResult` custom resource to the management cluster after auditing each managed cluster. The `ManagementClusterClassifier` watches those resources and labels only the clusters with a passing result.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ManagementClusterClassifier
    metadata:
      name: compliance-passed
    spec:
      matchResources:
      - group: compliance.example.io
        version: v1
        kind: ScanResult
        namespace: compliance
        evaluateCEL:
        - expression: "object.spec.passed == true && object.spec.score >= 90"
      classificationLua: |
        function evaluate(resources)
          local result = {}
          for _, r in ipairs(resources) do
            table.insert(result, {
              namespace = r.spec.clusterNamespace,
              name      = r.spec.clusterName,
              kind      = "Cluster"
            })
          end
          return result
        end
      classifierLabels:
      - key: compliance-status
        value: passed
    ```

The CEL expression filters out failing or low-scoring scans before the resources reach the Lua function. When a new scan result lands or an existing one is updated, the watch fires and cluster labels reflect the current compliance state within seconds.

## Example 3: Require multiple resource types before labelling

Sometimes the classification decision depends on two independent resources both being present. `classificationLua` receives the combined set of all resources matched by every entry in `matchResources` and can implement cross-resource logic.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ManagementClusterClassifier
    metadata:
      name: fully-onboarded
    spec:
      matchResources:
      - group: ""
        version: v1
        kind: ConfigMap
        namespace: projectsveltos
        selector:
          matchLabels:
            sveltos.io/doc-type: licence
      - group: ""
        version: v1
        kind: ConfigMap
        namespace: projectsveltos
        selector:
          matchLabels:
            sveltos.io/doc-type: quota-approval
      classificationLua: |
        function evaluate(resources)
          local licences = {}
          local quotas   = {}
          for _, cm in ipairs(resources) do
            local t = cm.metadata.labels["sveltos.io/doc-type"]
            local c = cm.data.clusterName
            if t == "licence"        then licences[c] = true end
            if t == "quota-approval" then quotas[c]   = true end
          end
          local result = {}
          for cluster, _ in pairs(licences) do
            if quotas[cluster] then
              table.insert(result, {namespace="capi-clusters", name=cluster, kind="Cluster"})
            end
          end
          return result
        end
      classifierLabels:
      - key: onboarding-status
        value: complete
    ```

A cluster receives `onboarding-status=complete` only when both a licence ConfigMap and a quota-approval ConfigMap exist for it in the management cluster. Deleting either document removes the label automatically.

## Inspect classification state

Each `(ManagementClusterClassifier, cluster)` pair produces a `ManagementClusterClassifierReport` in the cluster's namespace. It records which labels this classifier is actively managing (`ManagedLabels`) and which it wanted to set but could not because another classifier already owns those keys (`UnManagedLabels`).

```bash
$ kubectl get managementclusterclassifierreports -A
```

```bash
$ kubectl describe managementclusterclassifierreport \
    --namespace capi-clusters \
    <report-name>
```

When a conflict is detected, the `ManagementClusterClassifier` status field `failureMessage` describes which keys are in conflict and which classifier is the current owner.

`sveltosctl` provides a convenient view across all classifiers and clusters. Use `show classifier-labels` to list every label currently managed by a `Classifier` or `ManagementClusterClassifier`, and `show classifier-labels --warnings` to list only conflicts. See the [sveltosctl visibility](../getting_started/sveltosctl/features/visibility.md#show-classifier-labels) section for details.

## Coexistence with Classifier

`ManagementClusterClassifier` and `Classifier` use the same underlying conflict-detection mechanism. A label key on a given cluster can only be **managed by one instance**, regardless of whether it comes from a `Classifier` or a `ManagementClusterClassifier`. The two types can be used together without risk of silent overwrites.
