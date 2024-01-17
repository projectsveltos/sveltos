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

Following HealthCheck, considers all Deployments. Any Deployment:

1. with number of available replicas matching number of requested replicas is marked as Healthy;
2. with number of available replicas different than number of requested replicas is marked as Progressing;
3. with number of unavailable replicas set and different than zero, is marked as Degraded.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
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