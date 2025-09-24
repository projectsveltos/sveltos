---
title: EventTrigger Aggregated Selection - Advanced Templating in Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - Sveltos
    - EventTrigger
    - AggregatedSelection
    - Lua
    - add-ons
    - templating
authors:
    - Eleni Grosdouli
    - Gianluca Mardente
---

# Aggregated Selection

The `AggregatedSelection` is an advanced feature designed to handle complex filtering logic that goes beyond simple `ResourceSelector` matches. Instead of just selecting individual resources, it allows you to analyze and make decisions based on a group of related resources.

Use the `AggregatedSelection` when your selection criteria depend on the state or relationship between multiple resources of different kinds. A great use case is when we need to enforce a policy or automate a task based on the interaction of various components within your application.

### Example: Enforcing HPA-Deployment Match

The provided example is a perfect illustration of this. It's not just checking for the presence of a `Deployment` or an `HorizontalPodAutoscaler` (HPA). Instead, it looks at both types of resources together to find an inconsistency: an HPA that exists without a matching Deployment.

The `AggregatedSelection` Lua function allows you to:

1. **Gather all relevant resources**: The function receives an array of both `Deployment` and `HorizontalPodAutoscaler` resources that were selected by the `resourceSelectors`.
2. **Perform complex logic**: The script can iterate through all the HPAs and check if each one corresponds to an existing `Deployment` in the list. This isn't possible with a simple `ResourceSelector` that only evaluates one resource at a time.
3. **Return the filtered result**: The function returns only the HPAs that do not have a corresponding Deployment. This allows the EventTrigger to act specifically on those mismatched resources, perhaps to trigger a notification or a cleanup action.

This level of inter-resource analysis is the key differentiator of `AggregatedSelection`. It moves Sveltos from simple, per-resource matching to a powerful, group-based automation engine.


The Lua function must return a struct with:

- `resources` field: slice of matching resorces;
- `message` field: (optional) message.

```yaml
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: sveltos-service
spec:
  collectResources: true
  resourceSelectors:
  - group: "apps"
    version: "v1"
    kind: "Deployment"
  - kind: HorizontalPodAutoscaler
    group: "autoscaling"
    version: v2
  aggregatedSelection: |
      function getKey(namespace, name)
        return namespace .. ":" .. name
      end

      function evaluate()
        local hs = {}
        hs.message = ""

        local deployments = {}
        local autoscalers = {}
        local deploymentsWithNoAutoscaler = {}

        for _, resource in ipairs(resources) do
          local kind = resource.kind
          if kind == "Deployment" then
            key = getKey(resource.metadata.namespace, resource.metadata.name)
            deployments[key] = true
          elseif kind == "HorizontalPodAutoscaler" then
            table.insert(autoscalers, resource)
          end
        end

        -- Check for each horizontalPodAutoscaler if there is a matching Deployment
        for _,hpa in ipairs(autoscalers) do
            key = getKey(hpa.metadata.namespace, hpa.spec.scaleTargetRef.name)
            if hpa.spec.scaleTargetRef.kind == "Deployment" then
              if not deployments[key] then
                table.insert(unusedAutoscalers, hpa)
              end
            end
        end

        if #unusedAutoscalers > 0 then
          hs.resources = unusedAutoscalers
        end
        return hs
      end
```