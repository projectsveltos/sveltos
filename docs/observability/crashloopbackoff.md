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

![Send Slack Notification for Pods in Crashloopbackoff state](../assets/notification.gif)

Using following HealthCheck and ClusterhealthCheck instances, we are instructing Sveltos to:

1. detect pods in crashloopbackoff state in any cluster with labels __env=fv```
2. send a Slack notification when such an event is detected

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: HealthCheck
metadata:
 name: crashing-pod
spec:
 group: ""
 version: v1
 kind: Pod
 script: |
   function evaluate()
     hs = {}
     hs.status = "Healthy"
     hs.ignore = true
     if obj.status.containerStatuses then
        local containerStatuses = obj.status.containerStatuses
        for _, containerStatus in ipairs(containerStatuses) do
          if containerStatus.state.waiting and containerStatus.state.waiting.reason == "CrashLoopBackOff" then
            hs.status = "Degraded"
            hs.ignore = false
            hs.message = obj.metadata.namespace .. "/" .. obj.metadata.name .. ":" .. containerStatus.state.waiting.message
            if containerStatus.lastState.terminated and containerStatus.lastState.terminated.reason then
              hs.message = hs.message .. "\nreason:" .. containerStatus.lastState.terminated.reason
            end
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

All YAMLs can be found [here](https://github.com/projectsveltos/demos/tree/main/observability)