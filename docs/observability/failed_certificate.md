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

Following HealthCheck will detect degraded Certificates.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: HealthCheck
metadata:
 name: failed-cert
spec:
 group: "cert-manager.io"
 version: "v1"
 kind: "Certificate"
 script: |
  function evaluate()
    hs = {}
    hs.ignore = true
    if obj.status ~= nil then
      if obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" and condition.status == "False" then
            hs.ignore = false
            hs.status = "Degraded"
            hs.message = condition.message
            return hs
          end
        end
      end
    end
    return hs
  end
```
