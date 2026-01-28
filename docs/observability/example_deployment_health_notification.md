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

The below `HealthCheck` YAML definition considers all the cluster Deployments. It matches any `Deployment` in the `metrics` namespace:

1. **Healthy**: All requested replicas are available and ready, and there are no unavailable replicas reported.
1. **Degraded**: Marked if there are unavailable replicas, or if the available/ready counts are less than the desired spec.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: metrics-deployment-replicas
    spec:
      resourceSelectors:
      - group: "apps"
        version: v1
        kind: Deployment
        namespace: metrics
      evaluateHealth: |
        function evaluate()
          local hs = {}
          hs.status = "Healthy"
          hs.message = ""
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

            -- 1. Check for explicit unavailable replicas
            if unavailable > 0 then
              issue = string.format("Deployment %s/%s has %d unavailable replicas",
                      metadata.namespace, metadata.name, unavailable)

            -- 2. Check if available matches desired
            elseif available < desired then
              issue = string.format("Deployment %s/%s has %d available replicas (Expected %d)",
                      metadata.namespace, metadata.name, available, desired)

            -- 3. Check if ready matches desired
            elseif ready < desired then
              issue = string.format("Deployment %s/%s has %d ready replicas (Expected %d)",
                      metadata.namespace, metadata.name, ready, desired)
            end

            if issue then
              table.insert(unhealthy, {resource = resource, message = issue, status = "Degraded"})
            end
          end

          -- Update final health status if any issues were found
          if #unhealthy > 0 then
            hs.resources = unhealthy
          end

          return hs
        end
    ```