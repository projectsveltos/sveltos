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

The below `HealthCheck` YAML definition considers all the cluster Deployments. It matches any `Deployment`:

1. With the number of available replicas matching the number of requested replicas, it is marked as `Healthy`;
1. With the number of available replicas different than the number of requested replicas, it is marked as `Progressing`;
1. With the number of unavailable replicas set and different than zero, it is marked as `Degraded`.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: deployment-replicas
    spec:
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
            if resource.status ~= nil then
              if resource.status.availableReplicas ~= nil then
                if resource.status.availableReplicas == resource.spec.replicas then
                  status = "Healthy"
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
