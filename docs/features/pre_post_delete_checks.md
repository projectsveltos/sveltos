---
title: Pre and Post Delete CHecks
description: Sveltos supports validate checks, pre-delete checks, and post-delete checks for Helm, Kustomize, and YAML/JSON resources.
tags:
    - Kubernetes
    - lifecycle-management
    - automation
authors:
    - Gianluca Mardente
---

Sveltos provides a robust framework to ensure your managed clusters are in the correct state throughout the entire lifecycle of a resource—from initial deployment to final deletion. This is achieved through three types of checks: `ValidateHealthChecks`, `PreDeleteChecks`, and `PostDeleteChecks`.

## Validate Health Checks

`ValidateHealthChecks` are executed after resources are deployed. They ensure that the application or infrastructure is not just present, but actually functional.

For more details on how to configure these during deployment, see [Depends On with Health Checks](../deployment_order/depends_on_with_health_checks.md).

## Pre-Delete Checks

`PreDeleteChecks` are executed before Sveltos begins the deletion process. If any of these checks fail, Sveltos will halt the deletion. This is essential for ensuring that prerequisites (like data backups or draining connections) are met before infrastructure is torn down.

```yaml
spec:
  preDeleteChecks:
  - name: "check-no-active-pods"
    featureID: Resources
    group: ""
    version: "v1"
    kind: "Pod"
    namespace: "production"
    script: |
      function evaluate()
        -- If any pods are found, we return health=false to stop deletion
        return { health = false, message = "Active pods still exist in production" }
      end
```

## Post-Delete Checks

`PostDeleteChecks` are executed after Sveltos has issued the delete commands for all resources. These checks ensure the environment has reached a "clean" state, verifying that no lingering resources (like orphaned LoadBalancers or PVCs) remain.

```yaml
spec:
  postDeleteChecks:
  - name: "verify-pvc-removal"
    featureID: Resources
    group: ""
    version: "v1"
    kind: "PersistentVolumeClaim"
    evaluateCEL:
      - name: "no-pvcs-left"
        expression: "size(self.items) == 0"
```