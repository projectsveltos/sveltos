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
 group: "apps"
 version: v1
 kind: Deployment
 script: |
   function evaluate()
     hs = {}
     hs.status = "Progressing"
     hs.message = ""
     if obj.status ~= nil then
       if obj.status.availableReplicas ~= nil then
         if obj.status.availableReplicas == obj.spec.replicas then
           hs.status = "Healthy"
         else
           hs.status = "Progressing"
           hs.message = "expected replicas: " .. obj.spec.replicas .. " available: " .. obj.status.availableReplicas
         end
       end
       if obj.status.unavailableReplicas ~= nil then
          hs.status = "Degraded"
          hs.message = "deployments have unavailable replicas"
       end
     end
     return hs
   end
```