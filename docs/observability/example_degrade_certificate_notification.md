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

## Example: Degrade Certificates Notification

The below `HealthCheck` YAML definition will detect degrade Certificates.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1alpha1
    kind: HealthCheck
    metadata:
    name: failed-cert
    spec:
      resourceSelectors:
      - group: "cert-manager.io"
        version: "v1"
        kind: "Certificate"
      evaluateHealth: |
        function evaluate()
          local statuses = {}

          for _,resource in ipairs(resources) do
            if resource.status ~= nil then
              if resource.status.conditions ~= nil then
                for i, condition in ipairs(resource.status.conditions) do
                  if condition.type == "Ready" and condition.status == "False" then
                    status = "Degraded"
                    message = condition.message
                    table.insert(statuses, {resource=resource, status = status, message = message})
                  end
                end
              end
            end
          end

          local hs = {}
          if #statuses > 0 then
            hs.resources = statuses 
          end
          return hs
        end
    ```
