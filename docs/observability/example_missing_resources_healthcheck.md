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

## Example: Alert When Expected Resources Are Missing

In some scenarios the **absence** of a resource is itself a problem. For example, if deployments in the `metrics` namespace are mandatory, their absence indicates a broken rollout or misconfiguration and should trigger an alert.

When a `HealthCheck`'s `resourceSelectors` match no resources in a cluster, Sveltos passes an empty `resources` table to the Lua `evaluate()` function. The script can check for this condition and return a top-level `status` and `message`. Sveltos then creates a synthetic entry in the `HealthCheckReport` (one per `ResourceSelector`) so the degraded state is visible and can trigger notifications.

### HealthCheck Definition

The `HealthCheck` below targets Deployments in the `metrics` namespace. It first checks whether any resources were found at all, and then — if they were — verifies their replica counts.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: metrics-deployments
    spec:
      resourceSelectors:
      - group: "apps"
        version: v1
        kind: Deployment
        namespace: metrics
      evaluateHealth: |
        function evaluate()
          local hs = {}

          -- Surface a degraded status when no deployments exist in the namespace.
          if resources == nil or #resources == 0 then
            hs.status = "Degraded"
            hs.message = "No deployments found in namespace metrics"
            return hs
          end

          local unhealthy = {}

          for _, resource in ipairs(resources) do
            local status = resource.status or {}
            local spec = resource.spec or {}
            local metadata = resource.metadata or {}

            local desired = spec.replicas or 0
            local available = status.availableReplicas or 0
            local ready = status.readyReplicas or 0
            local unavailable = status.unavailableReplicas or 0

            local issue = nil

            if unavailable > 0 then
              issue = string.format("Deployment %s/%s has %d unavailable replicas",
                      metadata.namespace, metadata.name, unavailable)
            elseif available < desired then
              issue = string.format("Deployment %s/%s has %d available replicas (Expected %d)",
                      metadata.namespace, metadata.name, available, desired)
            elseif ready < desired then
              issue = string.format("Deployment %s/%s has %d ready replicas (Expected %d)",
                      metadata.namespace, metadata.name, ready, desired)
            end

            if issue then
              table.insert(unhealthy, {resource = resource, message = issue, status = "Degraded"})
            end
          end

          if #unhealthy > 0 then
            hs.resources = unhealthy
          end

          return hs
        end
    ```

### ClusterHealthCheck Definition

The `ClusterHealthCheck` below references the `HealthCheck` above and sends a Slack notification whenever the liveness state changes (e.g. deployments disappear or recover).

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterHealthCheck
    metadata:
      name: metrics-deployments
    spec:
      clusterSelector:
        matchLabels:
          env: production
      livenessChecks:
      - name: metrics-deployments
        type: HealthCheck
        livenessSourceRef:
          kind: HealthCheck
          apiVersion: lib.projectsveltos.io/v1beta1
          name: metrics-deployments
      notifications:
      - name: slack
        type: Slack
        notificationRef:
          apiVersion: v1
          kind: Secret
          name: slack
          namespace: default
    ```

### Observed Output

When the `metrics` namespace contains no Deployments, `sveltosctl show health` displays a synthetic degraded entry. The `NAME` column is empty because no individual resource was found — Sveltos creates one entry per `ResourceSelector` to identify which GVK and namespace had no matches.

```
+-----------------------------+------------------------------+-----------+------+-------------------------------------------+
|           CLUSTER           |             GVK              | NAMESPACE | NAME |                  MESSAGE                  |
+-----------------------------+------------------------------+-----------+------+-------------------------------------------+
| default/clusterapi-workload | apps/v1, Kind=Deployment     | metrics   |      | No deployments found in namespace metrics |
+-----------------------------+------------------------------+-----------+------+-------------------------------------------+
```

Once deployments are present and healthy, the entry disappears and a recovery notification is sent.
