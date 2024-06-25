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

## Example: Slack Notification for Pods in Crashloopbackoff

![Send Slack Notification for Pods in Crashloopbackoff state](../assets/notification.gif)

The below `HealthCheck` and `ClusterhealthCheck` YAML definitions can be used to instruct Sveltos to:

1. Detect pods in a crashloopbackoff state for every cluster that matched the labels __env=fv```
2. Send a Slack notification when an event is detected

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: HealthCheck
metadata:
  name: crashing-pod
spec:
  resourceSelectors:
  - group: ""
    version: v1
    kind: Pod
  evaluateHealth: |
    function evaluate()
      local statuses = {}

      for _,resource in ipairs(resources) do
        ignore = true
        if resource.status.containerStatuses then
          local containerStatuses = resource.status.containerStatuses
          for _, containerStatus in ipairs(containerStatuses) do
            if containerStatus.state.waiting and containerStatus.state.waiting.reason == "CrashLoopBackOff" then
              ignore = false
              status = "Degraded"
              message = resource.metadata.namespace .. "/" .. resource.metadata.name .. ":" .. containerStatus.state.waiting.message
              if containerStatus.lastState.terminated and containerStatus.lastState.terminated.reason then
                message = message .. "\nreason:" .. containerStatus.lastState.terminated.reason
              end
            end
          end
          if not ignore then
            table.insert(statuses, {resource=resource, status = status, message = message})
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

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: ClusterHealthCheck
metadata:
 name: crashing-pod
spec:
 clusterSelector: env=fv
 livenessChecks:
 - name: crashing-pod
   type: HealthCheck
   livenessSourceRef:
     kind: HealthCheck
     apiVersion: lib.projectsveltos.io/v1alpha1
     name: crashing-pod
 notifications:
 - name: slack
   type: Slack
   notificationRef:
     apiVersion: v1
     kind: Secret
     name: slack
     namespace: default
```

The YAML defintions can be found [here](https://github.com/projectsveltos/demos/tree/main/observability).